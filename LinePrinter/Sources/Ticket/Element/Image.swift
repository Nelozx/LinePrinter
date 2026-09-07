//
//  Image.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation
import CoreGraphics
import ImageIO

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
/// 支持原生 UIImage / NSImage、CGImage、远程图片 URL（带缓存加载）以及 Base64 编码图片。
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
    
    /// 初始化位图打印元素（图片原始文件二进制 Data，支持 PNG、JPEG、BMP、WebP 等）
    /// - Parameters:
    ///   - data: 图片原始二进制数据
    ///   - dither: 抖动算法风格
    public init(data: Data, dither: ImageDitherStyle = .floydSteinberg) {
        let cg = Image.decodeCGImage(from: data)
        self.init(cgImage: cg, dither: dither)
    }
    
    /// 初始化位图打印元素（Base64 编码图片字符串，支持带或不带 data:image 前缀）
    /// - Parameters:
    ///   - base64: Base64 编码字符串
    ///   - dither: 抖动算法风格
    public init(base64: String, dither: ImageDitherStyle = .floydSteinberg) {
        // 清除可能的 data:image/png;base64, 前缀
        let cleanBase64: String
        if let range = base64.range(of: "base64,") {
            cleanBase64 = String(base64[range.upperBound...])
        } else {
            cleanBase64 = base64
        }
        
        if let data = Data(base64Encoded: cleanBase64, options: .ignoreUnknownCharacters) {
            self.init(data: data, dither: dither)
        } else {
            self.init(cgImage: nil, dither: dither)
        }
    }
    
    /// 初始化位图打印元素（远程网络图片 URL，内置内存缓存）
    /// - Parameters:
    ///   - url: 远程图片 URL
    ///   - dither: 抖动算法风格
    ///   - timeout: 网络拉取超时时间（秒，默认 5 秒）
    public init(url: URL, dither: ImageDitherStyle = .floydSteinberg, timeout: TimeInterval = 5.0) {
        if let data = RemoteImageLoader.shared.loadData(from: url, timeout: timeout) {
            self.init(data: data, dither: dither)
        } else {
            self.init(cgImage: nil, dither: dither)
        }
    }
    
    /// 初始化位图打印元素（远程网络图片 URL 字符串）
    /// - Parameters:
    ///   - urlString: 图片 URL 字符串
    ///   - dither: 抖动算法风格
    ///   - timeout: 网络超时时间
    public init(urlString: String, dither: ImageDitherStyle = .floydSteinberg, timeout: TimeInterval = 5.0) {
        if let url = URL(string: urlString) {
            self.init(url: url, dither: dither, timeout: timeout)
        } else {
            self.init(cgImage: nil, dither: dither)
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
    
    /// 初始化本地 Bundle 图片资源位图（iOS / UIKit）
    public init(named name: String, bundle: Bundle? = nil, dither: ImageDitherStyle = .floydSteinberg) {
        let image = UIImage(named: name, in: bundle, compatibleWith: nil)
        self.init(cgImage: image?.cgImage, dither: dither)
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
    
    /// 初始化本地 Bundle 图片资源位图（macOS / AppKit）
    public init(named name: String, bundle: Bundle? = nil, dither: ImageDitherStyle = .floydSteinberg) {
        let image = bundle?.image(forResource: NSImage.Name(name)) ?? NSImage(named: NSImage.Name(name))
        var rect = CGRect(origin: .zero, size: image?.size ?? .zero)
        let cg = image?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        self.init(cgImage: cg, dither: dither)
    }
    #endif
    
    /// 生成光栅位图 ESC/POS 指令流
    /// - Parameter encoding: 字符编码（位图数据不依赖编码，但遵循 `Printable` 协议规范）
    /// - Returns: 光栅位图二进制数据
    public func data(using encoding: String.Encoding) -> Data {
        rasterData ?? Data()
    }
    
    /// 跨平台图片二进制解码为 CGImage
    private static func decodeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

// MARK: - 远程图片缓存加载器
final class RemoteImageLoader {
    static let shared = RemoteImageLoader()
    private let cache = NSCache<NSString, NSData>()
    
    private init() {
        cache.countLimit = 100
    }
    
    func loadData(from url: URL, timeout: TimeInterval = 5.0) -> Data? {
        let key = url.absoluteString as NSString
        if let cached = cache.object(forKey: key) {
            return cached as Data
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, error == nil {
                resultData = data
                self.cache.setObject(data as NSData, forKey: key)
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        return resultData
    }
}
