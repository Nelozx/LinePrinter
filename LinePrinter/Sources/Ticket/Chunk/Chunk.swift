//
//  Chunk.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// 可输出小票 ESC/POS 二进制数据的协议
public protocol Printable {
    /// 转换为对应编码的 ESC/POS 二进制指令流
    func data(using encoding: String.Encoding) -> Data
}

/// 支持 Data 直接作为可打印排版项
extension Data: Printable {
    public func data(using encoding: String.Encoding) -> Data { self }
}

/// 文本修饰属性协议
public protocol Attribute {
    /// 对应的 ESC/POS 属性控制字节
    var attribute: [UInt8] { get }
}

/// 小票排版基本单元（块）
///
/// 包含一个具体的内容提供者（文本、图片、二维码、指令等）以及打印后的走纸点数（feedPoints）。
public struct Chunk: Printable {
    /// 默认行间距走纸点数（70 点）
    public static var defaultFeedPoints: UInt8 = 70

    /// 当前块打印完成后的垂直走纸点数
    public let feedPoints: UInt8
    
    /// 具体排版内容提供者
    public let provider: Printable

    /// 构造小票排版块
    /// - Parameters:
    ///   - provider: 内容提供器（文本、条码、图片、Data 等）
    ///   - feedPoints: 打印完成后的进纸点数，默认为 70 点，若为 0 则不自动走纸
    public init(_ provider: Printable, feedPoints: UInt8 = Chunk.defaultFeedPoints) {
        self.feedPoints = feedPoints
        self.provider = provider
    }

    public func data(using encoding: String.Encoding) -> Data {
        if feedPoints > 0 {
            return provider.data(using: encoding) + Data(escpos: .printAndFeed(lines: feedPoints))
        } else {
            return provider.data(using: encoding)
        }
    }
}

// MARK: - 声明式 DSL 排版语法糖
public extension Chunk {
    
    /// 空白走纸块
    static var blank: Chunk {
        Chunk(Blank(), feedPoints: 0)
    }

    /// 原生 ESC/POS 二维码
    ///
    /// 直接生成 ESC/POS 原生点阵二维码指令，打印机硬件原生渲染，清晰度最高且打印速度极快。
    /// - Parameter content: 二维码文本内容或 URL 链接
    /// - Returns: 二维码排版块
    ///
    /// ```swift
    /// .qrcode("https://weixin.qq.com/r/example_invoice")
    /// ```
    static func qrcode(_ content: String) -> Self {
        Chunk(QRCode(content))
    }
    
    /// 原生 ESC/POS 一维条形码
    ///
    /// - Parameters:
    ///   - content: 条形码内容字符串（需符合对应码制字符集规则）
    ///   - type: 条形码码制类型，默认 `.code128`，支持 CODE39、EAN13 等
    ///   - height: 条形码垂直高度点阵数（1~255，默认 64）
    ///   - width: 条形码条粗细倍率（1~6，默认 2）
    ///   - hri: 条码下方/上方是否打印人类可读数字，默认 `.below`（条码下方）
    /// - Returns: 条形码排版块
    ///
    /// ```swift
    /// .barcode("20220419001", type: .code128)
    /// ```
    static func barcode(
        _ content: String,
        type: Commands.BarCodeType = .code128,
        height: UInt8 = 64,
        width: UInt8 = 2,
        hri: Commands.BarCodeHRIPosition = .below
    ) -> Self {
        Chunk(BarCode(content, type: type, height: height, width: width, hri: hri))
    }
    
    /// 带完整属性修饰的文本块
    ///
    /// - Parameters:
    ///   - content: 要打印的文本字符串
    ///   - attributes: 文本样式数组，如加粗、对齐等
    /// - Returns: 文本排版块
    ///
    /// ```swift
    /// .text("欢迎光临", attributes: [TextAttribute.bold, TextAttribute.alignment(.center)])
    /// ```
    static func text(_ content: String, attributes: [Attribute]? = nil) -> Self {
        Chunk(Text(content, attributes: attributes))
    }
    
    /// 快捷文本块（加粗与对齐）
    ///
    /// - Parameters:
    ///   - content: 文本内容
    ///   - bold: 是否加粗，默认为 `false`
    ///   - alignment: 对齐方式（`.left`, `.center`, `.right`），默认为居左 `.left`
    /// - Returns: 文本排版块
    ///
    /// ```swift
    /// .text("味美餐饮旗舰店", bold: true, alignment: .center)
    /// ```
    static func text(_ content: String, bold: Bool = false, alignment: Commands.Alignment = .left) -> Self {
        var attrs: [Attribute] = [TextAttribute.alignment(alignment)]
        if bold {
            attrs.append(TextAttribute.bold)
        }
        return Chunk(Text(content, attributes: attrs))
    }
    
    /// 默认横向分割线（自适应纸宽充满一行 "-"）
    static var splitter: Chunk {
        Chunk(Splitter(provider: Character("-"), printDensity: 384, fontDensity: 12))
    }
    
    /// 自定义字符分割线
    ///
    /// - Parameters:
    ///   - char: 构成分割线的字符，默认为 `"-"`，亦可使用 `"="`、`"*"` 等
    ///   - printDensity: 打印机横向点阵密度，58mm 打印机通常为 384，80mm 通常为 576
    ///   - fontDensity: 单字符点阵宽度，默认 12
    /// - Returns: 分割线排版块
    ///
    /// ```swift
    /// .splitter(char: "=")
    /// ```
    static func splitter(char: Character = "-", printDensity: Int = 384, fontDensity: Int = 12) -> Self {
        Chunk(Splitter(provider: char, printDensity: printDensity, fontDensity: fontDensity))
    }
    
    /// 空占位排版块（不打印任何内容，不走纸）
    static var empty: Self {
        Chunk(Data(), feedPoints: 0)
    }
    
    #if canImport(UIKit)
    /// 打印位图（iOS UIKit）
    ///
    /// 将 `UIImage` 转换为 ESC/POS 标准单色光栅位图指令（`GS v 0`），可清晰还原 Logo 或图形层次。若传入 `nil` 则自动转换为空块。
    /// - Parameters:
    ///   - image: 需要打印的可选 UIImage 对象
    ///   - dither: 二值化处理方式，默认 `.floydSteinberg` 误差扩散抖动（适合照片或渐变图形），亦可选用 `.threshold(128)` 灰度阈值法（适合纯黑白线条 Logo）
    /// - Returns: 位图排版块
    ///
    /// ```swift
    /// .image(logoImage, dither: .floydSteinberg)
    /// ```
    static func image(_ image: UIImage?, dither: ImageDitherStyle = .floydSteinberg) -> Self {
        guard let image = image else { return .empty }
        return Chunk(Image(image, dither: dither))
    }
    #endif
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// 打印位图（macOS AppKit）
    static func image(_ image: NSImage?, dither: ImageDitherStyle = .floydSteinberg) -> Self {
        guard let image = image else { return .empty }
        return Chunk(Image(image, dither: dither))
    }
    #endif

    /// 打印位图（CoreGraphics CGImage）
    static func image(cgImage: CGImage?, dither: ImageDitherStyle = .floydSteinberg) -> Self {
        guard let cgImage = cgImage else { return .empty }
        return Chunk(Image(cgImage: cgImage, dither: dither))
    }
    
    /// 自定义多列排版行
    ///
    /// 支持指定总列宽及各列权重比例或固定宽度，精准控制每列文本居左/居中/居右对齐。
    /// - Parameters:
    ///   - totalWidth: 行总字符宽度，58mm 纸宽通常填 32，80mm 纸宽通常填 48，默认为 32
    ///   - columns: 列配置列表（`Line`）
    /// - Returns: 多列排版行块
    ///
    /// ```swift
    /// .row(totalWidth: 32,
    ///      Line("品名", weight: 2, alignment: .left),
    ///      Line("数量", weight: 1, alignment: .center),
    ///      Line("金额", weight: 1, alignment: .right))
    /// ```
    static func row(totalWidth: Int = 32, _ columns: Line...) -> Self {
        Chunk(Row(totalWidth: totalWidth, columns: columns))
    }
    
    /// 快速双列左右两端对齐排版
    ///
    /// 常用于小票账单金额汇总、单号与时间的排版（左侧品名/标签居左，右侧金额/数值居右）。
    /// - Parameters:
    ///   - left: 左侧文本内容
    ///   - right: 右侧文本内容
    ///   - totalWidth: 行总字符宽度，58mm 纸宽默认 32，80mm 纸宽填 48
    ///   - wrap: 左侧文本超出宽度时是否自动智能折行，默认为 `false`
    /// - Returns: 双列排版块
    ///
    /// ```swift
    /// .twoColumn("实付金额", "￥40.00")
    /// ```
    static func twoColumn(_ left: String, _ right: String, totalWidth: Int = 32, wrap: Bool = false) -> Self {
        Chunk(Row(totalWidth: totalWidth,
                  Line(left, weight: 1, alignment: .left, wrap: wrap),
                  Line(right, weight: 1, alignment: .right)))
    }
    
    /// 快速三列排版（左品名，中数量，右金额）
    ///
    /// 餐饮及零售小票最常用的明细排版结构。品名占 2 权重居左，数量占 1 权重居中，金额占 1 权重居右。
    /// - Parameters:
    ///   - col1: 第一列文本（品名）
    ///   - col2: 第二列文本（数量/规格）
    ///   - col3: 第三列文本（金额/小计）
    ///   - totalWidth: 行总字符宽度，58mm 纸宽默认 32，80mm 纸宽填 48
    ///   - wrap: 超长品名是否自动折行，开启后品名超长会自动换行且保证数量与金额垂直对齐，默认为 `false`
    /// - Returns: 三列排版块
    ///
    /// ```swift
    /// .threeColumn("招牌老坛酸菜黑鱼饭(大份)", "x1", "38.00", wrap: true)
    /// ```
    static func threeColumn(_ col1: String, _ col2: String, _ col3: String, totalWidth: Int = 32, wrap: Bool = false) -> Self {
        Chunk(Row(totalWidth: totalWidth,
                  Line(col1, weight: 2, alignment: .left, wrap: wrap),
                  Line(col2, weight: 1, alignment: .center),
                  Line(col3, weight: 1, alignment: .right)))
    }
    
    /// 垂直块分组容器
    ///
    /// 将多个 Chunk 顺序组合为一个连续的逻辑单元。
    /// - Parameter elements: 包含的排版块集合
    /// - Returns: 分组排版块
    static func group(_ elements: Chunk...) -> Self {
        Chunk(ChunkGroup(elements))
    }
    
    /// 全切纸指令块
    static var cut: Self { Chunk(Data.cut, feedPoints: 0) }
    
    /// 半切纸指令块
    static var partialCut: Self { Chunk(Data.partialCut, feedPoints: 0) }
    
    /// 自动进纸并全切纸
    static var feedAndCut: Self { Chunk(Data.feedAndCut, feedPoints: 0) }
    
    /// 弹出收银钱箱
    static var openDrawer: Self { Chunk(Data.openDrawer, feedPoints: 0) }
    
    /// 走纸指定行数
    static func feed(lines: UInt8 = 1) -> Self {
        Chunk(Data(escpos: .printAndFeed(lines: lines)), feedPoints: 0)
    }
    
    /// 蜂鸣器发声提示块（后厨出单提醒、外卖催单）
    static func buzzer(times: UInt8 = 1, duration: UInt8 = 2) -> Self {
        Chunk(Data.buzzer(times: times, duration: duration), feedPoints: 0)
    }
    
    /// 设置自定义行间距（紧凑排版/节省纸张）
    static func lineSpacing(_ points: UInt8) -> Self {
        Chunk(Data.lineSpacing(points), feedPoints: 0)
    }
    
    /// 恢复出厂默认行间距（约 30 点阵）
    static var defaultLineSpacing: Self { Chunk(Data.defaultLineSpacing, feedPoints: 0) }
    
    /// 进纸定位至黑标/标签缝隙（标签小票机专用）
    static var feedToBlackMark: Self { Chunk(Data.feedToBlackMark, feedPoints: 0) }
}
