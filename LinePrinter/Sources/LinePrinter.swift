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
    
    /// 构建小票对象（变长参数 DSL，支持链式 .print(to:)）
    public static func ticket(_ chunks: Chunk...) -> Ticket {
        Ticket(chunks: chunks, autoInitialize: true, autoCut: false)
    }

    /// 解析服务端下发的 JSON 构建小票对象
    public static func ticket(json: String) throws -> Ticket { try Ticket(json: json) }
    public static func ticket(json: Data) throws -> Ticket { try Ticket(json: json) }
    
    /// 由排版块直接生成连续的 ESC/POS 二进制字节流（变长参数直出）
    public static func bytes(_ chunks: Chunk...) -> Data {
        Ticket(chunks: chunks).bytes()
    }

    /// 由排版块直接生成连续的 ESC/POS 二进制字节流（数组直出）
    public static func bytes(chunks: [Chunk], encoding: String.Encoding = .gbk) -> Data {
        Ticket(chunks: chunks).bytes(using: encoding)
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
