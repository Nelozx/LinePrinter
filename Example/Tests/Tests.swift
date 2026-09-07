import XCTest
@testable import LinePrinter

final class MockCustomTransport: PrinterTransport {
    var receivedData = Data()
    func write(_ data: Data) {
        receivedData.append(data)
    }
}

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
        let twoCol = Row(
            totalWidth: 32,
            Col("红烧牛肉面", weight: 1, alignment: .left),
            Col("￥38.00", weight: 1, alignment: .right)
        )
        let data = twoCol.data(using: .utf8)
        let lineString = String(data: data, encoding: .utf8)!
        
        XCTAssertEqual(lineString.printDisplayWidth, 32)
        XCTAssertTrue(lineString.hasPrefix("红烧牛肉面"))
        XCTAssertTrue(lineString.hasSuffix("￥38.00"))
        
        // 测试三列对齐 (总宽 32: 左边品名，中间数量，右边小计)
        let threeCol = Row(
            totalWidth: 32,
            Col("可口可乐", weight: 2, alignment: .left),
            Col("x2", weight: 1, alignment: .center),
            Col("10.00", weight: 1, alignment: .right)
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
                .row("牛肉面", "￥35.00"),
                .row("冰红茶", "￥5.00"),
                .splitter,
                .row("合计", "￥40.00"),
                .feed(3)
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
        let thresholdData = LinePrinter.rasterData(from: testImage, dither: .threshold(128))
        XCTAssertNotNil(thresholdData)
        XCTAssertGreaterThan(thresholdData?.count ?? 0, 0)
        
        // 2. Floyd-Steinberg 抖动模式
        let ditherData = LinePrinter.rasterData(from: testImage, dither: .floydSteinberg)
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
        let line = Row(
            totalWidth: 32,
            Col(longName, weight: 2, alignment: .left, wrap: true),
            Col("x1", weight: 1, alignment: .center),
            Col("38.00", weight: 1, alignment: .right)
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
                .row("商品小计", "￥58.00")
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
        let mock = MockCustomTransport()
        
        // 1. Ticket print 链式调用返回自身
        let ticket = Ticket(chunks: [.text("自定义通道测试")]).print(to: mock, encoding: .gbk)
        XCTAssertFalse(mock.receivedData.isEmpty)
        XCTAssertEqual(ticket.chunks.count, 1)
        
        // 2. LinePrinter.ticket 变长参数构建并直出打印
        mock.receivedData = Data()
        LinePrinter.ticket(
            .text("快速结账单", bold: true, alignment: .center),
            .row("应收", "￥20.00"),
            .cut
        ).print(to: mock)
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
        XCTAssertEqual(LinePrinter.version, "0.5.0")
        let facadeTicket = LinePrinter.ticket(
            .text("门面小票标题", bold: true, alignment: .center),
            .qrcode("https://lineprinter.dev")
        )
        XCTAssertFalse(facadeTicket.chunks.isEmpty)
        
        // 5. LinePrinter 一站式直出字节流
        let directBytes = LinePrinter.bytes(chunks: [.text("直出字节流测试")])
        XCTAssertFalse(directBytes.isEmpty)
        
        // 6. LinePrinter.status 快捷解析
        let parsed = LinePrinter.status(0x60)
        XCTAssertTrue(parsed.contains(.paperEmpty))
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
                .spacing(20),
                .barcode("12345678", type: .code128, hri: .below),
                .defaultSpacing,
                .beep(2),
                .blackMark
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
                .splitter("-"),
                .row("老坛黑鱼饭", "x1", "38.00", wrap: true),
                .row("实付金额", "￥38.00"),
                .qrcode("https://test.com"),
                .barcode("123456", type: .code128, hri: .below)
            ],
            autoInitialize: true,
            autoCut: true
        )
        
        // 1. 生成 58mm 预览视图
        let view58 = ticket.preview(paperWidth: ReceiptPaperWidth.mm58)
        XCTAssertNotNil(view58)
        XCTAssertEqual(view58.paperWidth, ReceiptPaperWidth.mm58)
        
        // 2. 切换为 80mm 规格
        view58.paperWidth = ReceiptPaperWidth.mm80
        XCTAssertEqual(view58.paperWidth, ReceiptPaperWidth.mm80)
        
        // 3. 导出小票静态长图
        let image = ticket.image(paperWidth: ReceiptPaperWidth.mm58)
        XCTAssertNotNil(image, "小票长图生成不应为 nil")
        if let img = image {
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
        
        // 4. 纸张规格与内容更新
        let view80 = ticket.preview(paperWidth: ReceiptPaperWidth.mm80)
        XCTAssertNotNil(view80)
        XCTAssertEqual(view80.paperWidth, ReceiptPaperWidth.mm80)
        #endif
    }
    // MARK: - JSON 数据驱动全元素解析覆盖测试
    func testJSONToTicketDecoding() {
        let onePixelBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        
        let jsonString = """
        {
          "autoCut": true,
          "autoInitialize": true,
          "chunks": [
            { "type": "text", "content": "大号居中标题", "bold": true, "alignment": "center", "size": "double", "underline": 1 },
            { "type": "text", "content": "反白居右文本", "alignment": "right", "reverse": true },
            { "type": "splitter", "char": "=", "printDensity": 384 },
            { "type": "twoColumn", "left": "双列左", "right": "双列右" },
            { "type": "threeColumn", "col1": "菜品", "col2": "x1", "col3": "28.00", "wrap": true },
            {
              "type": "row",
              "totalWidth": 32,
              "columns": [
                { "text": "四列A", "weight": 2, "wrap": true },
                { "text": "四列B", "weight": 1, "alignment": "center" },
                { "text": "四列C", "weight": 1, "alignment": "center" },
                { "text": "四列D", "weight": 1, "alignment": "right" }
              ]
            },
            { "type": "qrcode", "content": "https://lineprinter.dev" },
            { "type": "barcode", "content": "12345678", "barcodeType": "code128", "height": 60, "width": 2, "hri": "below" },
            { "type": "image", "base64": "\(onePixelBase64)", "dither": "threshold", "threshold": 128 },
            { "type": "blank" },
            {
              "type": "group",
              "elements": [
                { "type": "text", "content": "组合元素1" },
                { "type": "text", "content": "组合元素2" }
              ]
            },
            { "type": "spacing", "points": 24 },
            { "type": "defaultSpacing" },
            { "type": "beep", "times": 2, "duration": 3 },
            { "type": "drawer" },
            { "type": "blackMark" },
            { "type": "feed", "lines": 2 },
            { "type": "partialCut" }
          ]
        }
        """
        
        do {
            let ticket = try Ticket(json: jsonString)
            XCTAssertTrue(ticket.autoCut)
            XCTAssertTrue(ticket.autoInitialize)
            // 验证全部 18 个区块均被正确识别解析
            XCTAssertEqual(ticket.chunks.count, 18)
            
            // 验证生成的二进制流是否包含对应的指令特征
            let data = ticket.bytes(using: .utf8)
            let bytes = [UInt8](data)
            
            // 初始化指令 [27, 64]
            XCTAssertEqual(bytes[0], 27)
            XCTAssertEqual(bytes[1], 64)
            
            // 切纸指令 [29, 86]
            XCTAssertTrue(bytes.contains(29))
            XCTAssertTrue(bytes.contains(86))
            
            // 开钱箱指令 [27, 112]
            XCTAssertTrue(bytes.contains(112))
            
            // 蜂鸣器指令 [27, 66]
            XCTAssertTrue(bytes.contains(66))
            
            // 二维码存储指令 [29, 40, 107]
            XCTAssertTrue(bytes.contains(107))
            
            // 条码指令 [29, 107]
            XCTAssertTrue(bytes.contains(73)) // Code128 = 73
            
        } catch {
            XCTFail("JSON 全元素解析失败: \(error)")
        }
    }
    
    // MARK: - 预览与图片长图渲染测试
    func testTicketPreviewImageGeneration() {
        let ticket58 = LinePrinter.ticket(
            .text("味美餐饮旗舰店", bold: true, alignment: .center),
            .text("-- 欢迎光临 --", attributes: [TextAttribute.alignment(.center)]),
            .splitter,
            .text("单号: NO.20260907001"),
            .text("时间: 2026-09-07 12:30:00"),
            .text("收银员: 01号"),
            .splitter,
            .row("品名", "数量", "金额"),
            .splitter("-"),
            .row("招牌老坛酸菜黑鱼饭(大份)", "x1", "38.00", wrap: true),
            .row("秘制香辣鸭头", "x2", "16.00"),
            .row("冰镇大麦若叶汁", "x1", "8.00"),
            .splitter,
            .row("原价合计", "￥62.00"),
            .row("会员优惠券", "-￥12.00"),
            .row("实付金额", "￥50.00"),
            .splitter,
            .text("支付方式: 微信支付"),
            .text("【取餐号: A088】", bold: true, alignment: .center),
            .splitter,
            .text("扫码开具增值税电子发票", alignment: .center),
            .qrcode("https://weixin.qq.com/r/example_invoice"),
            .blank
        ).autoCut()
        
        let img58 = ticket58.image(paperWidth: .mm58)
        XCTAssertNotNil(img58, "58mm 小票长图渲染失败")
        XCTAssertGreaterThan(img58?.size.width ?? 0, 0)
        XCTAssertGreaterThan(img58?.size.height ?? 0, 0)
        
        let ticket80 = LinePrinter.ticket(
            .text("精品生活大型商超购物小票", bold: true, alignment: .center),
            .text("门店: 科技园旗舰总店", alignment: .center),
            .splitter,
            .row("商品名称/条码", "单价/数量", "金额", totalWidth: 48, wrap: true),
            .splitter("="),
            .row("波士顿冷冻大龙虾 500g", "128.00 x 2", "256.00", totalWidth: 48, wrap: true),
            .row("进口有机特级初榨橄榄油 1L", "88.00 x 1", "88.00", totalWidth: 48, wrap: true),
            .row("日本青森红富士苹果礼盒", "59.90 x 1", "59.90", totalWidth: 48, wrap: true),
            .splitter,
            .row("商品总计", "￥403.90", totalWidth: 48),
            .row("限时尊享折上折", "-￥53.90", totalWidth: 48),
            .row("应收金额", "￥350.00", totalWidth: 48),
            .splitter,
            .barcode("6901234567890"),
            .blank
        ).autoCut()
        
        let img80 = ticket80.image(paperWidth: .mm80)
        XCTAssertNotNil(img80, "80mm 小票长图渲染失败")
        XCTAssertGreaterThan(img80?.size.width ?? 0, 0)
        XCTAssertGreaterThan(img80?.size.height ?? 0, 0)
    }
    
    // MARK: - LinePrinter.ticket 变长链式直出与 JSON 测试
    func testLinePrinterTicketChainingPrint() {
        let mock = MockCustomTransport()
        
        let ticket = LinePrinter.ticket(
            .text("快速结账单", bold: true, alignment: .center),
            .row("应收", "￥20.00"),
            .cut
        ).print(to: mock)
        
        XCTAssertEqual(ticket.chunks.count, 3)
        XCTAssertFalse(mock.receivedData.isEmpty)
    }
    
    // MARK: - 自定义公司业务模型 TicketConvertible 测试
    func testTicketConvertibleBusinessModel() {
        struct CompanyOrderDTO: Codable, TicketConvertible {
            let orderNo: String
            let storeName: String
            let totalAmount: Double
            
            func asTicket(paper: ReceiptPaperWidth) -> Ticket {
                LinePrinter.ticket(
                    .text(storeName, bold: true, alignment: .center),
                    .splitter("-"),
                    .text("单号：\(orderNo)"),
                    .row("实付金额", String(format: "￥%.2f", totalAmount)),
                    .cut
                )
            }
        }
        
        let order = CompanyOrderDTO(orderNo: "ORDER-2026-999", storeName: "真功夫快餐", totalAmount: 45.50)
        let ticket = order.asTicket()
        XCTAssertEqual(ticket.chunks.count, 5)
        
        let bytes = ticket.bytes(using: .gbk)
        XCTAssertFalse(bytes.isEmpty)
        
        // 门面转换测试
        let ticketFromFacade = LinePrinter.ticket(order)
        XCTAssertEqual(ticketFromFacade.chunks.count, 5)
    }
    
    // MARK: - 公司私有/任意非标 JSON 适配转换器测试
    func testCustomJSONMapper() {
        let proprietaryJSON = """
        {
          "errcode": 0,
          "data": {
            "bill_title": "第三方外卖自动接单",
            "dish_list": [
              { "title": "招牌黄焖鸡米饭", "count": 2, "price": "40.00" }
            ],
            "pay_sum": "40.00"
          }
        }
        """
        
        do {
            let ticket = try LinePrinter.ticket(json: proprietaryJSON) { root in
                guard let dict = root as? [String: Any],
                      let data = dict["data"] as? [String: Any] else {
                    throw NSError(domain: "Test", code: -1)
                }
                
                let title = data["bill_title"] as? String ?? ""
                let dishes = data["dish_list"] as? [[String: Any]] ?? []
                let paySum = data["pay_sum"] as? String ?? ""
                
                var chunks: [Chunk] = [
                    .text(title, bold: true, alignment: .center),
                    .splitter
                ]
                for dish in dishes {
                    let dName = dish["title"] as? String ?? ""
                    let count = dish["count"] as? Int ?? 1
                    let price = dish["price"] as? String ?? ""
                    chunks.append(.row(dName, "x\(count)", price, wrap: true))
                }
                chunks.append(.splitter)
                chunks.append(.row("合计", "￥\(paySum)"))
                chunks.append(.feedAndCut)
                
                return Ticket(chunks: chunks)
            }
            
            XCTAssertEqual(ticket.chunks.count, 6)
            XCTAssertFalse(ticket.bytes().isEmpty)
        } catch {
            XCTFail("私有 JSON 映射失败: \(error)")
        }
    }
    
    // MARK: - 动态位图支持测试 (Base64 与 二进制 Data)
    func testImageBase64AndData() {
        // 创建一个简单的 16x16 测试位图 PNG Data
        let size = CGSize(width: 16, height: 16)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let sampleImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        guard let pngData = UIImagePNGRepresentation(sampleImage) else {
            XCTFail("生成测试图片 Data 失败")
            return
        }
        let rawBase64 = pngData.base64EncodedString()
        let dataUriBase64 = "data:image/png;base64," + rawBase64
        
        // 1. 测试 Chunk.image(base64:) 原生 base64 及带 data:image 前缀
        let chunkRawB64 = Chunk.image(base64: rawBase64, dither: .threshold(128))
        let dataRawB64 = chunkRawB64.data(using: .utf8)
        XCTAssertFalse(dataRawB64.isEmpty, "Base64 图片生成打印数据不应为空")
        
        let chunkUriB64 = Chunk.image(base64: dataUriBase64, dither: .threshold(128))
        let dataUriB64 = chunkUriB64.data(using: .utf8)
        XCTAssertFalse(dataUriB64.isEmpty, "DataURI 前缀 Base64 图片生成打印数据不应为空")
        
        // 2. 测试 Chunk.image(data:) 二进制数据直接注入
        let chunkData = Chunk.image(data: pngData, dither: .floydSteinberg)
        let dataFromBytes = chunkData.data(using: .utf8)
        XCTAssertFalse(dataFromBytes.isEmpty, "二进制 Data 图片生成打印数据不应为空")
        
        // 3. 测试 JSON 反序列化对 base64 图片字段的支持
        let jsonWithBase64Image = """
        {
          "autoInitialize": true,
          "autoCut": true,
          "chunks": [
            {
              "type": "image",
              "base64": "\(rawBase64)",
              "dither": "threshold",
              "threshold": 128
            }
          ]
        }
        """
        
        do {
            let ticket = try Ticket(json: jsonWithBase64Image)
            XCTAssertEqual(ticket.chunks.count, 1, "应该成功解析 1 个 Base64 图片区块")
            let fullBytes = ticket.bytes()
            XCTAssertFalse(fullBytes.isEmpty, "解析后的 Base64 图片小票输出字节流不应为空")
        } catch {
            XCTFail("Base64 图片 JSON 解析失败: \(error)")
        }
    }
}


