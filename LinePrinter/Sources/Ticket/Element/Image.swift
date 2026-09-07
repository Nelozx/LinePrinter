//
//  Image.swift
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

/// 单色点阵位图打印元素
///
/// 将图片转换为热敏打印机光栅位图（Raster Bit Image）指令（`GS v 0`）。
///
/// 支持抖动算法优化（如 Floyd-Steinberg 误差扩散算法），让灰度渐变图片在仅支持黑白二值化的热敏纸上也能细腻呈现。
public struct Image: Printable {
    
    /// 经过热敏点阵二值化抖动后的单色黑白图像（真实还原热敏打印效果，非彩色原图）
    public let cgImage: CGImage?
    
    private let rasterData: Data?

    /// 初始化位图打印元素（CoreGraphics CGImage，支持可选值）
    /// - Parameters:
    ///   - cgImage: 需要打印的 CGImage 对象（若为 nil 则为空位图）
    ///   - dither: 抖动算法风格
    public init(cgImage: CGImage?, dither: ImageDitherStyle = .floydSteinberg) {
        if let cgImage = cgImage, let mono = cgImage.monochromeBitmap(dither: dither) {
            self.cgImage = mono.makeCGImage()
            self.rasterData = mono.rasterData()
        } else {
            self.cgImage = cgImage
            self.rasterData = nil
        }
    }
    
    #if canImport(UIKit)
    /// 初始化位图打印元素（iOS / UIKit）
    /// - Parameters:
    ///   - image: 需要打印的 UIImage 图片
    ///   - dither: 抖动算法风格（默认为 `.floydSteinberg`，亦可选 `.threshold` 阈值二值化）
    public init(_ image: UIImage, dither: ImageDitherStyle = .floydSteinberg) {
        self.init(cgImage: image.cgImage, dither: dither)
    }
    #endif
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// 初始化位图打印元素（macOS / AppKit）
    /// - Parameters:
    ///   - image: 需要打印的 NSImage 图片
    ///   - dither: 抖动算法风格（默认为 `.floydSteinberg`，亦可选 `.threshold` 阈值二值化）
    public init(_ image: NSImage, dither: ImageDitherStyle = .floydSteinberg) {
        var rect = CGRect(origin: .zero, size: image.size)
        let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        self.init(cgImage: cg, dither: dither)
    }
    #endif
    
    /// 生成光栅位图 ESC/POS 指令流
    /// - Parameter encoding: 字符编码（位图数据不依赖编码，但遵循 `ChunkProvider` 协议规范）
    /// - Returns: 光栅位图二进制数据
    public func data(using encoding: String.Encoding) -> Data {
        rasterData ?? Data()
    }
}
