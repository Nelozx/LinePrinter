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
/// 提供了快速构建小票（`ticket`）、一行代码直出二进制流（`bytes`）以及硬件状态解析（`status`）的能力。
///
/// ```swift
/// import LinePrinter
///
/// // 1. 便捷声明式排版
/// let ticket = LinePrinter.ticket(
///     .text("餐饮结账单", bold: true, alignment: .center),
///     .splitter,
///     .row("老坛酸菜鱼", "x1", "38.00", wrap: true),
///     .row("实付金额", "￥38.00"),
///     .qrcode("https://weixin.qq.com/..."),
///     .feed(3)
/// )
///
/// // 2. 获取 ESC/POS 二进制字节流
/// let data = ticket.bytes(using: .gbk)
/// ```
public enum LinePrinter {
    
    /// 框架版本号
    public static let version = "0.5.0"
    
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
    
    /// 解析打印机硬件实时状态
    public static func status(_ byte: UInt8) -> PrinterHardwareStatus {
        PrinterHardwareStatus.parse(byte: byte)
    }
    
    #if canImport(UIKit)
    /// 将 `UIImage` 转换为 ESC/POS 光栅位图数据
    public static func rasterData(from image: UIImage, dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        image.rasterEscPosData(dither: dither)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// 将 `NSImage` 转换为 ESC/POS 光栅位图数据
    public static func rasterData(from image: NSImage, dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        image.rasterEscPosData(dither: dither)
    }
    #endif

    /// 将 `CGImage` 转换为 ESC/POS 光栅位图数据
    public static func rasterData(from cgImage: CGImage, dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        cgImage.rasterEscPosData(dither: dither)
    }
}
