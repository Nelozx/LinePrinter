//
//  LinePrinter.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
/// `LinePrinter` 核心统一入口与门面命名空间
///
/// 提供了快速构建小票（`ticket`）、一行代码直出二进制流（`bytes`）以及硬件状态解析（`parseStatus`）的能力。
///
/// ```swift
/// import LinePrinter
///
/// // 1. 便捷声明式排版
/// let ticket = LinePrinter.ticket(
///     .text("餐饮结账单", bold: true, alignment: .center),
///     .splitter,
///     .threeColumn("老坛酸菜鱼", "x1", "38.00", wrap: true),
///     .twoColumn("实付金额", "￥38.00"),
///     .qrcode("https://weixin.qq.com/..."),
///     .feed(lines: 3)
/// )
///
/// // 2. 获取 ESC/POS 二进制字节流
/// let data = ticket.bytes(using: .gbk)
/// ```
public enum LinePrinter {
    
    /// 框架版本号
    public static let version = "0.3.0"
    
    /// 便捷构建小票对象（变长参数 DSL）
    ///
    /// - Parameters:
    ///   - autoInitialize: 是否在小票头部自动添加 ESC/POS 初始化指令（`ESC @`），默认为 `true`
    ///   - autoCut: 是否在小票结尾自动走纸并切纸，默认为 `false`
    ///   - chunks: 排版块列表（如 `.text`, `.splitter`, `.row`, `.qrcode` 等）
    /// - Returns: 构建完成的 `Ticket` 小票对象
    ///
    /// ```swift
    /// let ticket = LinePrinter.ticket(
    ///     .text("欢迎光临", bold: true, alignment: .center),
    ///     .splitter,
    ///     .text("单号: NO.1001")
    /// 便捷构建小票对象（变长参数 DSL，支持链式 .print(to:)）
    ///
    /// - Parameters:
    ///   - autoInitialize: 是否在小票头部自动添加 ESC/POS 初始化指令（`ESC @`），默认为 `true`
    ///   - autoCut: 是否在小票结尾自动走纸并切纸，默认为 `false`
    ///   - chunks: 排版块列表（如 `.text`, `.splitter`, `.twoColumn`, `.qrcode` 等）
    /// - Returns: 构建完成的 `Ticket` 小票对象（可链式调用 .print(to:)、.previewImage() 等）
    ///
    /// ```swift
    /// LinePrinter.ticket(
    ///     .text("快速结账单", bold: true, alignment: .center),
    ///     .twoColumn("应收", "￥20.00"),
    ///     .cut
    /// ).print(to: bluetoothTransport)
    /// 便捷构建小票对象（纯变长参数 DSL，支持链式 .print(to:)）
    ///
    /// ```swift
    /// LinePrinter.ticket(
    ///     .text("快速结账单", bold: true, alignment: .center),
    ///     .twoColumn("应收", "￥20.00"),
    ///     .cut
    /// ).print(to: bluetoothTransport)
    /// ```
    public static func ticket(_ chunks: Chunk...) -> Ticket {
        Ticket(chunks: chunks, autoInitialize: true, autoCut: false)
    }

    /// 便捷构建小票对象（带初始化/切纸控制的变长参数 DSL）
    public static func ticket(
        autoInitialize: Bool = true,
        autoCut: Bool = false,
        _ chunks: Chunk...
    ) -> Ticket {
        Ticket(chunks: chunks, autoInitialize: autoInitialize, autoCut: autoCut)
    }
    
    /// 便捷构建小票对象（数组参数）
    ///
    /// - Parameters:
    ///   - chunks: 排版块数组
    ///   - autoInitialize: 是否在头部自动初始化（`ESC @`），默认为 `true`
    ///   - autoCut: 是否在末尾自动切纸，默认为 `false`
    /// - Returns: 构建完成的 `Ticket` 小票对象
    public static func ticket(
        chunks: [Chunk],
        autoInitialize: Bool = true,
        autoCut: Bool = false
    ) -> Ticket {
        Ticket(chunks: chunks, autoInitialize: autoInitialize, autoCut: autoCut)
    }
    
    /// 直接由排版块生成标准 ESC/POS 连续二进制字节流（数组块直出）
    ///
    /// 无需手动管理 `Ticket` 变量，直接传入排版块即可获得连续的 `Data`。
    /// - Parameters:
    ///   - chunks: 排版块数组
    ///   - encoding: 中文编码，默认 `.gbk`（GB18030 / GBK）
    ///   - autoInitialize: 是否自动在头部插入 `ESC @` 初始化指令，默认 `true`
    ///   - autoCut: 是否在末尾自动切纸，默认 `false`
    /// - Returns: 标准连续的 ESC/POS 二进制字节流 `Data`
    ///
    /// ```swift
    /// let data = LinePrinter.bytes(chunks: [.text("外卖结算单"), .cut])
    /// ```
    public static func bytes(
        chunks: [Chunk],
        encoding: String.Encoding = .gbk,
        autoInitialize: Bool = true,
        autoCut: Bool = false
    ) -> Data {
        Ticket(chunks: chunks, autoInitialize: autoInitialize, autoCut: autoCut).bytes(using: encoding)
    }
    
    /// 直接由排版块生成标准 ESC/POS 连续二进制字节流（变长参数直出）
    ///
    /// - Parameters:
    ///   - encoding: 字符编码，默认 `.gbk`
    ///   - autoInitialize: 是否自动在头部初始化，默认 `true`
    ///   - autoCut: 是否在末尾自动切纸，默认 `false`
    ///   - chunks: 变长排版块列表
    /// - Returns: 标准连续的 ESC/POS 二进制指令字节流 `Data`
    ///
    /// ```swift
    /// let data = LinePrinter.bytes(.text("桌号: A08"), .feedAndCut)
    /// ```
    public static func bytes(
        encoding: String.Encoding = .gbk,
        autoInitialize: Bool = true,
        autoCut: Bool = false,
        _ chunks: Chunk...
    ) -> Data {
        bytes(chunks: chunks, encoding: encoding, autoInitialize: autoInitialize, autoCut: autoCut)
    }
    
    /// 解析打印机回传的标准 ESC/POS 实时硬件状态字节（实时查询或 DLE EOT 回执）
    ///
    /// - Parameter byte: 打印机返回的原始字节（如通过蓝牙特征值通知或 Socket 读取到的单字节）
    /// - Returns: 解析后的结构化状态（可使用 `.contains(.paperEmpty)`、`.contains(.coverOpen)` 判断）
    ///
    /// ```swift
    /// let status = LinePrinter.parseStatus(byte: 0x60)
    /// if status.contains(.paperEmpty) {
    ///     print("⚠️ 打印机缺纸！")
    /// }
    /// ```
    public static func parseStatus(byte: UInt8) -> PrinterHardwareStatus {
        PrinterHardwareStatus.parse(byte: byte)
    }
    
    #if canImport(UIKit)
    /// 将 `UIImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    ///
    /// 内部自动提取 32 位 RGBA 像素、计算灰度并执行二值化抖动，输出可直接写入小票机的二进制数据。
    /// - Parameters:
    ///   - image: 待转换的 UIImage 图片对象
    ///   - dither: 二值化抖动风格，默认为 `.floydSteinberg` 误差扩散抖动
    /// - Returns: ESC/POS 光栅指令数据 `Data`，若转换失败或尺寸无效则返回 `nil`
    ///
    /// ```swift
    /// if let rasterBytes = LinePrinter.imageRasterData(from: myLogoImage) {
    ///     myTransport.write(rasterBytes)
    /// }
    /// ```
    public static func imageRasterData(
        from image: UIImage,
        dither: ImageDitherStyle = .floydSteinberg
    ) -> Data? {
        image.rasterEscPosData(dither: dither)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// 将 `NSImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    public static func imageRasterData(
        from image: NSImage,
        dither: ImageDitherStyle = .floydSteinberg
    ) -> Data? {
        image.rasterEscPosData(dither: dither)
    }
    #endif

    /// 将 `CGImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    public static func imageRasterData(
        from cgImage: CGImage,
        dither: ImageDitherStyle = .floydSteinberg
    ) -> Data? {
        cgImage.rasterEscPosData(dither: dither)
    }
}

/// 语义别名：小票收据（等同于 Ticket）
public typealias Receipt = Ticket
