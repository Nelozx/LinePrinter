import XCTest
@testable import LinePrinter

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - 指令测试
    func testEscPosCommands() {
        // 初始化指令: ESC @ -> [27, 64]
        XCTAssertEqual(Commands.initialize.rawValue, [27, 64])
        
        // 居中对齐: ESC a 1 -> [27, 97, 49]
        XCTAssertEqual(Commands.alignment(.center).rawValue, [27, 97, 49])
        
        // 加粗: ESC E 1 -> [27, 69, 1]
        XCTAssertEqual(Commands.emphasize(1).rawValue, [27, 69, 1])
        
        // 切纸 (GS V m -> 29, 86, m)
        XCTAssertEqual(Commands.cutPaper(m: 49).rawValue, [29, 86, 49])
        
        // 复合 Data
        let cutData = Data.cut
        XCTAssertFalse(cutData.isEmpty)
    }
    
    // MARK: - 中文 GBK 编码测试
    func testChineseEncoding() {
        let text = "小票打印机"
        let data = text.data(using: .gbk)
        XCTAssertNotNil(data)
        // 5个汉字，在 GBK 编码下每个汉字占 2 字节，总共 10 字节
        XCTAssertEqual(data?.count, 10)
    }
    
    // MARK: - 字符宽度与对齐测试
    func testCharacterDisplayWidth() {
        XCTAssertEqual("A".printDisplayWidth, 1)
        XCTAssertEqual("123".printDisplayWidth, 3)
        XCTAssertEqual("中文".printDisplayWidth, 4)
        XCTAssertEqual("中A文1".printDisplayWidth, 6)
        
        // 左对齐填充
        let leftPadded = "餐品".padToPrintWidth(8, alignment: .left)
        XCTAssertEqual(leftPadded.printDisplayWidth, 8)
        XCTAssertEqual(leftPadded, "餐品    ")
        
        // 右对齐填充
        let rightPadded = "25.00".padToPrintWidth(10, alignment: .right)
        XCTAssertEqual(rightPadded.printDisplayWidth, 10)
        XCTAssertEqual(rightPadded, "     25.00")
    }
    
    // MARK: - 多列排版测试
    func testMultiColumnLine() {
        // 测试双列对齐 (总宽 32: 左对齐品名，右对齐金额)
        let twoCol = Line(
            totalWidth: 32,
            LineColumn("红烧牛肉面", weight: 1, alignment: .left),
            LineColumn("￥38.00", weight: 1, alignment: .right)
        )
        let data = twoCol.data(using: .utf8)
        let lineString = String(data: data, encoding: .utf8)!
        
        XCTAssertEqual(lineString.printDisplayWidth, 32)
        XCTAssertTrue(lineString.hasPrefix("红烧牛肉面"))
        XCTAssertTrue(lineString.hasSuffix("￥38.00"))
        
        // 测试三列对齐 (总宽 32: 左边品名，中间数量，右边小计)
        let threeCol = Line(
            totalWidth: 32,
            LineColumn("可口可乐", weight: 2, alignment: .left),
            LineColumn("x2", weight: 1, alignment: .center),
            LineColumn("10.00", weight: 1, alignment: .right)
        )
        let threeData = threeCol.data(using: .utf8)
        let threeString = String(data: threeData, encoding: .utf8)!
        XCTAssertEqual(threeString.printDisplayWidth, 32)
    }
    
    // MARK: - 文本属性注入与复位测试
    func testTextAttributes() {
        let boldText = Text("加粗标题", attributes: [TextAttribute.bold, TextAttribute.alignment(.center)])
        let data = boldText.data(using: .gbk)
        
        // 应该包含加粗指令 ESC E 1、居中指令 ESC a 1、文本数据、以及复位指令
        XCTAssertFalse(data.isEmpty)
        let bytes = [UInt8](data)
        
        // 检查前缀包含加粗指令 [27, 69, 1]
        XCTAssertTrue(bytes.contains(27))
        XCTAssertTrue(bytes.contains(69))
    }
    
    // MARK: - Ticket 组装与 autoCut 测试
    func testTicketAssembly() {
        let ticket = Ticket(
            chunks: [
                .text("餐饮结账单", bold: true, alignment: .center),
                .splitter,
                .twoColumn("牛肉面", "￥35.00"),
                .twoColumn("冰红茶", "￥5.00"),
                .splitter,
                .twoColumn("合计", "￥40.00"),
                .feed(lines: 3)
            ],
            autoInitialize: true,
            autoCut: true
        )
        
        let payloads = ticket.data(using: .gbk)
        XCTAssertGreaterThan(payloads.count, 0)
        
        // 验证头部有初始化指令
        let firstChunkBytes = [UInt8](payloads.first!)
        XCTAssertEqual(firstChunkBytes[0], 27)
        XCTAssertEqual(firstChunkBytes[1], 64)
        
        // 验证尾部包含切纸指令 (GS V -> 29, 86)
        let lastChunkBytes = [UInt8](payloads.last!)
        XCTAssertTrue(lastChunkBytes.contains(29)) // GS
        XCTAssertTrue(lastChunkBytes.contains(86)) // V (切纸)
    }
    
    // MARK: - 图片转换与二值化测试 (防越界崩溃验证)
    func testImageConversion() {
        // 创建一张 45x37（非 8 的倍数，用于测试边缘越界处理）的测试图像
        let size = CGSize(width: 45, height: 37)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        UIColor.black.setFill()
        UIRectFill(CGRect(x: 10, y: 10, width: 20, height: 15))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // 1. 阈值模式
        let thresholdData = LinePrinter.imageRasterData(from: testImage, dither: .threshold(128))
        XCTAssertNotNil(thresholdData)
        XCTAssertGreaterThan(thresholdData?.count ?? 0, 0)
        
        // 2. Floyd-Steinberg 抖动模式
        let ditherData = LinePrinter.imageRasterData(from: testImage, dither: .floydSteinberg)
        XCTAssertNotNil(ditherData)
        XCTAssertGreaterThan(ditherData?.count ?? 0, 0)
    }
    
    // MARK: - 硬件状态解析测试
    func testHardwareStatusParsing() {
        // 0 为正常就绪
        let normal = PrinterHardwareStatus.parse(byte: 0)
        XCTAssertTrue(normal.isNormal)
        
        // 0x04 对应 bit 2 = 1 (机盖打开)
        let coverOpen = PrinterHardwareStatus.parse(byte: 0x04)
        XCTAssertTrue(coverOpen.contains(.coverOpen))
        
        // 0x60 对应 bit 5,6 = 1 (缺纸)
        let paperEmpty = PrinterHardwareStatus.parse(byte: 0x60)
        XCTAssertTrue(paperEmpty.contains(.paperEmpty))
        
        // 0x64 对应缺纸 + 机盖打开
        let combined = PrinterHardwareStatus.parse(byte: 0x64)
        XCTAssertTrue(combined.contains(.coverOpen))
        XCTAssertTrue(combined.contains(.paperEmpty))
    }
    
    // MARK: - 多列长文本智能折行测试
    func testMultiLineWrap() {
        // 模拟一个品名特别长、需要折行的三列小票
        let longName = "老坛酸菜无骨鱼饭超大份双拼" // 26 显示宽度
        let line = Line(
            totalWidth: 32,
            LineColumn(longName, weight: 2, alignment: .left, wrap: true),
            LineColumn("x1", weight: 1, alignment: .center),
            LineColumn("38.00", weight: 1, alignment: .right)
        )
        let data = line.data(using: .utf8)
        let output = String(data: data, encoding: .utf8)!
        
        // 应该包含换行符 "\n"，拆分为至少两行
        let rows = output.components(separatedBy: "\n")
        XCTAssertGreaterThan(rows.count, 1)
        
        // 验证第一行包含品名前半部分以及数量 "x1" 和金额 "38.00"
        XCTAssertTrue(rows[0].contains("x1"))
        XCTAssertTrue(rows[0].contains("38.00"))
        
        // 验证第二行包含品名剩余部分，但不再重复出现 "x1"
        XCTAssertFalse(rows[1].contains("x1"))
    }
    
    // MARK: - 极简解耦测试: 直接获取字节流
    func testTicketBytesDirectOutput() {
        let ticket = Ticket(
            chunks: [
                .text("外卖结算单", bold: true, alignment: .center),
                .twoColumn("商品小计", "￥58.00")
            ],
            autoInitialize: true,
            autoCut: true
        )
        let fullBytes = ticket.bytes(using: .gbk)
        XCTAssertFalse(fullBytes.isEmpty)
        // 验证包含头部初始化 [27, 64]
        XCTAssertEqual(fullBytes[0], 27)
        XCTAssertEqual(fullBytes[1], 64)
    }
    
    // MARK: - 极简解耦测试: 链式通道直出（构建即发送）
    func testCustomTransportDecoupling() {
        class MockCustomTransport: PrinterTransport {
            var receivedData = Data()
            func write(_ data: Data) {
                receivedData.append(data)
            }
        }
        
        let mock = MockCustomTransport()
        
        // 1. 链式调用返回自身
        let ticket = Ticket(chunks: [.text("自定义通道测试")]).print(to: mock, encoding: .gbk)
        XCTAssertFalse(mock.receivedData.isEmpty)
        XCTAssertEqual(ticket.chunks.count, 1)
        
        // 2. 门面变长参数直出 (构建即发送)
        mock.receivedData = Data()
        LinePrinter.print(to: mock, autoCut: true,
            .text("快速收银"),
            .twoColumn("实付", "￥20.00")
        )
        XCTAssertFalse(mock.receivedData.isEmpty)
        
        // 3. 门面 ResultBuilder 闭包直出 (构建即发送)
        mock.receivedData = Data()
        LinePrinter.print(to: mock, autoCut: true) {
            Chunk.text("美味餐厅")
            Chunk.twoColumn("合计", "￥50.00")
        }
        XCTAssertFalse(mock.receivedData.isEmpty)
    }
    
    // MARK: - 现代干净架构核心排版与输出功能验证
    func testModernCleanArchitecture() {
        // 1. Ticket autoInitialize & 现代 DSL
        var ticket = Ticket(
            chunks: [
                .qrcode("https://test.org"),
                .barcode("12345678", type: .code128),
                .group(.text("分组标题"), .text("分组内容"))
            ],
            autoInitialize: true,
            autoCut: true
        )
        XCTAssertTrue(ticket.autoInitialize)
        ticket.autoInitialize = false
        XCTAssertFalse(ticket.autoInitialize)
        
        // 2. 字节流生成验证
        let bytes = ticket.bytes(using: .gbk)
        XCTAssertFalse(bytes.isEmpty)
        
        // 3. 硬件状态解析验证
        let status = PrinterHardwareStatus.parse(byte: 0x64)
        XCTAssertTrue(status.contains(.coverOpen))
        XCTAssertTrue(status.contains(.paperEmpty))
        
        // 4. LinePrinter 统一门面与命名空间验证
        XCTAssertEqual(LinePrinter.version, "0.2.0")
        let facadeTicket = LinePrinter.ticket(
            .text("门面小票标题", bold: true, alignment: .center),
            .qrcode("https://lineprinter.dev")
        )
        XCTAssertFalse(facadeTicket.chunks.isEmpty)
        
        // 5. LinePrinter 一站式直出字节流
        let directBytes = LinePrinter.bytes(chunks: [.text("直出字节流测试")])
        XCTAssertFalse(directBytes.isEmpty)
        
        // 6. LinePrinter.parseStatus 快捷解析
        let parsed = LinePrinter.parseStatus(byte: 0x60)
        XCTAssertTrue(parsed.contains(.paperEmpty))
        
        // 7. Receipt 别名验证
        let receipt: Receipt = facadeTicket
        XCTAssertEqual(receipt.chunks.count, 2)
    }
    
    // MARK: - 中文二维码数据长度计算验证
    func testChineseQRCodeDataLength() {
        let chineseText = "微信买单"
        let qr = QRCode(chineseText)
        let qrData = qr.data(using: .gbk)
        
        // 4 个汉字在 GBK 下为 8 字节，指令长度参数应为 8 + 3 = 11 (pL = 11, pH = 0)
        let bytes = [UInt8](qrData)
        // 寻找 GS ( k ... 1 80 48 指令段: [29, 40, 107, pL, pH, 49, 80, 48]
        if let idx = bytes.indices.first(where: {
            $0 + 7 < bytes.count &&
            bytes[$0] == 29 && bytes[$0 + 1] == 40 && bytes[$0 + 2] == 107 &&
            bytes[$0 + 5] == 49 && bytes[$0 + 6] == 80 && bytes[$0 + 7] == 48
        }) {
            let pL = bytes[idx + 3]
            let pH = bytes[idx + 4]
            let totalLength = Int(pL) + Int(pH) * 256
            XCTAssertEqual(totalLength, 8 + 3, "二维码存储数据长度应该为真实二进制字节数(8) + 3")
        } else {
            XCTFail("未找到二维码存储指令头")
        }
    }
    
    // MARK: - 补充指令集（蜂鸣器、条码HRI、行间距、黑标定位）测试
    func testSupplementaryCommands() {
        // 1. 蜂鸣器指令: ESC B 3 2 -> [27, 66, 3, 2]
        let buzzerCmd = Commands.buzzer(times: 3, duration: 2)
        XCTAssertEqual(buzzerCmd.rawValue, [27, 66, 3, 2])
        
        // 2. 行间距指令: 恢复默认 ESC 2 -> [27, 50], 自定义 ESC 3 24 -> [27, 51, 24]
        XCTAssertEqual(Commands.defaultLineSpacing.rawValue, [27, 50])
        XCTAssertEqual(Commands.lineSpacing(24).rawValue, [27, 51, 24])
        
        // 3. 条码 HRI 字符指令: GS H 2 -> [29, 72, 2]
        XCTAssertEqual(Commands.barCodeHRI(.below).rawValue, [29, 72, 2])
        XCTAssertEqual(Commands.barCodeHRI(.none).rawValue, [29, 72, 0])
        
        // 4. 黑标进纸定位: GS FF -> [29, 12]
        XCTAssertEqual(Commands.feedToBlackMark.rawValue, [29, 12])
        
        // 5. 进纸切纸平滑联动: GS V 65 30 -> [29, 86, 65, 30]
        XCTAssertEqual(Commands.feedAndCutPaper(partial: false, feedPoints: 30).rawValue, [29, 86, 65, 30])
        
        // 6. DSL 语法糖组装测试
        let ticket = Ticket(
            chunks: [
                .lineSpacing(20),
                .barcode("12345678", type: .code128, hri: .below),
                .defaultLineSpacing,
                .buzzer(times: 2),
                .feedToBlackMark
            ]
        )
        let data = ticket.bytes(using: .gbk)
        XCTAssertFalse(data.isEmpty)
    }
    
    // MARK: - 原生小票预览模式（ReceiptPreviewView、长图导出与预览控制器）测试
    func testReceiptPreviewMode() {
        #if canImport(UIKit)
        let demoImage = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 40)).image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(CGRect(x: 10, y: 10, width: 80, height: 20))
        }
        
        let ticket = Ticket(
            chunks: [
                .image(demoImage, dither: .floydSteinberg),
                .text("味美餐饮店", bold: true, alignment: .center),
                .splitter(char: "-"),
                .threeColumn("老坛黑鱼饭", "x1", "38.00", wrap: true),
                .twoColumn("实付金额", "￥38.00"),
                .qrcode("https://test.com"),
                .barcode("123456", type: .code128, hri: .below)
            ],
            autoInitialize: true,
            autoCut: true
        )
        
        // 1. 生成 58mm 预览视图
        let view58 = ticket.previewView(paperWidth: .mm58)
        XCTAssertNotNil(view58)
        XCTAssertEqual(view58.paperWidth, .mm58)
        
        // 2. 切换为 80mm 规格
        view58.paperWidth = .mm80
        XCTAssertEqual(view58.paperWidth, .mm80)
        
        // 3. 导出小票静态长图
        let image = ticket.previewImage(paperWidth: .mm58)
        XCTAssertNotNil(image, "小票长图生成不应为 nil")
        if let img = image {
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
        
        // 4. 纸张规格与内容更新
        let view80 = ticket.previewView(paperWidth: .mm80)
        XCTAssertNotNil(view80)
        XCTAssertEqual(view80.paperWidth, .mm80)
        #endif
    }
    // MARK: - JSON 数据驱动解析测试
    func testJSONToTicketDecoding() {
        let jsonString = """
        {
          "autoCut": true,
          "autoInitialize": true,
          "chunks": [
            { "type": "text", "content": "JSON 测试", "bold": true, "alignment": "center" },
            { "type": "splitter", "char": "*" },
            { "type": "twoColumn", "left": "商品", "right": "￥10.00" },
            { "type": "feed", "lines": 3 }
          ]
        }
        """
        
        do {
            let ticket = try Ticket(jsonString: jsonString)
            XCTAssertTrue(ticket.autoCut)
            XCTAssertTrue(ticket.autoInitialize)
            XCTAssertEqual(ticket.chunks.count, 4)
            
            // 验证生成的二进制流是否包含对应的指令特征
            let data = ticket.bytes(using: .utf8)
            let bytes = [UInt8](data)
            
            // 初始化指令 [27, 64]
            XCTAssertEqual(bytes[0], 27)
            XCTAssertEqual(bytes[1], 64)
            
            // 切纸指令 [29, 86]
            XCTAssertTrue(bytes.contains(29))
            XCTAssertTrue(bytes.contains(86))
            
        } catch {
            XCTFail("JSON 解析失败: \(error)")
        }
    }
    
    // MARK: - 预览与图片长图渲染测试
    func testTicketPreviewImageGeneration() {
        let ticket58 = LinePrinter.ticket(
            autoCut: true,
            .text("味美餐饮旗舰店", bold: true, alignment: .center),
            .text("-- 欢迎光临 --", attributes: [TextAttribute.alignment(.center)]),
            .splitter,
            .text("单号: NO.20260907001"),
            .text("时间: 2026-09-07 12:30:00"),
            .text("收银员: 01号"),
            .splitter,
            .threeColumn("品名", "数量", "金额"),
            .splitter(char: "-"),
            .threeColumn("招牌老坛酸菜黑鱼饭(大份)", "x1", "38.00", wrap: true),
            .threeColumn("秘制香辣鸭头", "x2", "16.00"),
            .threeColumn("冰镇大麦若叶汁", "x1", "8.00"),
            .splitter,
            .twoColumn("原价合计", "￥62.00"),
            .twoColumn("会员优惠券", "-￥12.00"),
            .twoColumn("实付金额", "￥50.00"),
            .splitter,
            .text("支付方式: 微信支付"),
            .text("【取餐号: A088】", bold: true, alignment: .center),
            .splitter,
            .text("扫码开具增值税电子发票", alignment: .center),
            .qrcode("https://weixin.qq.com/r/example_invoice"),
            .blank
        )
        
        let img58 = ticket58.previewImage(paperWidth: .mm58)
        XCTAssertNotNil(img58, "58mm 小票长图渲染失败")
        XCTAssertGreaterThan(img58?.size.width ?? 0, 0)
        XCTAssertGreaterThan(img58?.size.height ?? 0, 0)
        
        let ticket80 = LinePrinter.ticket(
            autoCut: true,
            .text("精品生活大型商超购物小票", bold: true, alignment: .center),
            .text("门店: 科技园旗舰总店", alignment: .center),
            .splitter,
            .threeColumn("商品名称/条码", "单价/数量", "金额", totalWidth: 48, wrap: true),
            .splitter(char: "="),
            .threeColumn("波士顿冷冻大龙虾 500g", "128.00 x 2", "256.00", totalWidth: 48, wrap: true),
            .threeColumn("进口有机特级初榨橄榄油 1L", "88.00 x 1", "88.00", totalWidth: 48, wrap: true),
            .threeColumn("日本青森红富士苹果礼盒", "59.90 x 1", "59.90", totalWidth: 48, wrap: true),
            .splitter,
            .twoColumn("商品总计", "￥403.90", totalWidth: 48),
            .twoColumn("限时尊享折上折", "-￥53.90", totalWidth: 48),
            .twoColumn("应收金额", "￥350.00", totalWidth: 48),
            .splitter,
            .barcode("6901234567890"),
            .blank
        )
        
        let img80 = ticket80.previewImage(paperWidth: .mm80)
        XCTAssertNotNil(img80, "80mm 小票长图渲染失败")
        XCTAssertGreaterThan(img80?.size.width ?? 0, 0)
        XCTAssertGreaterThan(img80?.size.height ?? 0, 0)
    }
    
    // MARK: - ResultBuilder 优雅声明式 DSL 测试
    func testTicketResultBuilder() {
        let hasCoupon = true
        let items = [("招牌酸菜鱼", "x1", "38.00"), ("冰镇可乐", "x2", "6.00")]
        
        let ticket = Ticket(autoCut: true) {
            Chunk.text("美味餐厅", bold: true, alignment: .center)
            Chunk.splitter
            
            for item in items {
                Chunk.threeColumn(item.0, item.1, item.2, wrap: true)
            }
            
            if hasCoupon {
                Chunk.twoColumn("优惠券抵扣", "-￥10.00")
            }
            
            Chunk.splitter
            Chunk.twoColumn("实付总计", "￥34.00")
            Chunk.qrcode("https://weixin.qq.com")
        }
        
        XCTAssertTrue(ticket.autoCut)
        // 验证块数量: 1(text) + 1(splitter) + 2(items) + 1(coupon) + 1(splitter) + 1(total) + 1(qr) = 8
        XCTAssertEqual(ticket.chunks.count, 8)
        
        let data = ticket.bytes(using: .utf8)
        XCTAssertFalse(data.isEmpty)
    }
    
    // MARK: - Fluent Chaining 纯链式调用测试
    func testTicketFluentChaining() {
        let hasCoupon = true
        let items = [("招牌酸菜鱼", "x1", "38.00"), ("冰镇可乐", "x2", "6.00")]
        
        let ticket = Ticket.make(autoInitialize: true, autoCut: true)
            .text("美味餐厅", bold: true, alignment: .center)
            .splitter()
            .forEach(items) { t, item in
                t.threeColumn(item.0, item.1, item.2, wrap: true)
            }
            .when(hasCoupon) { $0.twoColumn("优惠券抵扣", "-￥10.00") }
            .splitter()
            .twoColumn("实付总计", "￥34.00")
            .qrcode("https://weixin.qq.com")
            .cut()
        
        XCTAssertTrue(ticket.autoInitialize)
        XCTAssertTrue(ticket.autoCut)
        XCTAssertEqual(ticket.chunks.count, 9) // 包含最后的 .cut
        
        let bytes = ticket.bytes(using: .utf8)
        XCTAssertFalse(bytes.isEmpty)
    }
}

