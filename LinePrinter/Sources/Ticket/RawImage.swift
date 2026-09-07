//
//  RawImage.swift
//  LineThermalPrinter
//
//  Created by Nelo on 2022/4/11.
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// 单色热敏打印图像二值化与抖动算法样式
public enum ImageDitherStyle {
    /// 纯灰度阈值法（0~255，默认 128）
    ///
    /// 灰度小于阈值的像素判定为黑色打点，适合黑白分明的简单矢量线条、Logo 图标。
    case threshold(UInt8)
    
    /// Floyd-Steinberg 误差扩散抖动算法（推荐）
    ///
    /// 模拟半色调效果，将量化误差扩散至周围相邻像素，适合包含丰富渐变、灰阶阴影或照片层次的图像。
    case floydSteinberg
}

extension CGImage {
    
    /// 将 `CGImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    ///
    /// 内部自动提取 32 位 RGBA 像素、计算灰度并执行二值化抖动，输出可直接写入小票机的二进制数据。
    /// - Parameter dither: 二值化抖动风格，默认为 `.floydSteinberg` 误差扩散抖动
    /// - Returns: ESC/POS 光栅指令数据 `Data`，若转换失败或尺寸无效则返回 `nil`
    public func rasterEscPosData(dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        let width = self.width
        let height = self.height
        guard width > 0 && height > 0 else { return nil }
        
        var finalData = Data()
        let maxChunkHeight = 2000
        var currentY = 0
        
        while currentY < height {
            let chunkHeight = min(maxChunkHeight, height - currentY)
            let rect = CGRect(x: 0, y: currentY, width: width, height: chunkHeight)
            guard let cropped = self.cropping(to: rect) else { break }
            
            if let chunkData = cropped.processChunkToEscPosData(dither: dither) {
                finalData.append(chunkData)
            }
            currentY += chunkHeight
        }
        
        return finalData.isEmpty ? nil : finalData
    }
    
    private func processChunkToEscPosData(dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        let width = self.width
        let height = self.height
        guard width > 0 && height > 0 else { return nil }
        
        // 1. 获取标准 32-bit RGBA 像素数据
        guard let rgbaData = getRGBAPixels(from: self, width: width, height: height) else {
            return nil
        }
        
        // 2. 将 RGBA 转换为灰度矩阵
        var grays = [Int](repeating: 255, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Int(rgbaData[offset])
                let g = Int(rgbaData[offset + 1])
                let b = Int(rgbaData[offset + 2])
                let a = Int(rgbaData[offset + 3])
                
                // 透明区域视为白底
                if a < 128 {
                    grays[y * width + x] = 255
                } else {
                    // 心理学灰度公式: 0.299 R + 0.587 G + 0.114 B
                    let gray = (r * 299 + g * 587 + b * 114) / 1000
                    grays[y * width + x] = gray
                }
            }
        }
        
        // 3. 二值化处理 (0 表示白色，1 表示黑色需要打印)
        var bitmap = [UInt8](repeating: 0, count: width * height)
        switch dither {
        case .threshold(let th):
            let threshold = Int(th)
            for i in 0..<(width * height) {
                bitmap[i] = grays[i] < threshold ? 1 : 0
            }
        case .floydSteinberg:
            var buffer = grays
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let oldVal = buffer[index]
                    let newVal = oldVal < 128 ? 0 : 255
                    bitmap[index] = newVal == 0 ? 1 : 0
                    let error = oldVal - newVal
                    
                    // 误差扩散给相邻像素
                    if x + 1 < width {
                        buffer[y * width + (x + 1)] += (error * 7) / 16
                    }
                    if y + 1 < height {
                        if x > 0 {
                            buffer[(y + 1) * width + (x - 1)] += (error * 3) / 16
                        }
                        buffer[(y + 1) * width + x] += (error * 5) / 16
                        if x + 1 < width {
                            buffer[(y + 1) * width + (x + 1)] += (error * 1) / 16
                        }
                    }
                }
            }
        }
        
        // 4. 将二值位图转换为 ESC/POS GS v 0 光栅数据
        return createRasterEscPosData(from: bitmap, width: width, height: height)
    }
    
    var rasterEscPosData: Data? {
        rasterEscPosData(dither: .threshold(128))
    }
    
    private func getRGBAPixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return rawData
    }
    
    private func createRasterEscPosData(from bitmap: [UInt8], width: Int, height: Int) -> Data {
        let bytesPerLine = (width + 7) / 8
        var result = Data()
        
        // ESC/POS GS v 0 指令限制最大高度 4095 点，按最大 4095 切片处理
        let maxChunkHeight = 2000
        var currentY = 0
        
        while currentY < height {
            let chunkHeight = min(maxChunkHeight, height - currentY)
            
            let xL = UInt8(bytesPerLine % 256)
            let xH = UInt8(bytesPerLine / 256)
            let yL = UInt8(chunkHeight % 256)
            let yH = UInt8(chunkHeight / 256)
            
            // GS v 0 0 xL xH yL yH
            result.append(contentsOf: Commands.printRasterBitImages(m: .normal, xl: xL, xH: xH, yl: yL, yH: yH).rawValue)
            
            var chunkData = [UInt8](repeating: 0, count: bytesPerLine * chunkHeight)
            for row in 0..<chunkHeight {
                let actualY = currentY + row
                for byteIndex in 0..<bytesPerLine {
                    var byteVal: UInt8 = 0
                    for bit in 0..<8 {
                        let actualX = byteIndex * 8 + bit
                        if actualX < width {
                            let pixel = bitmap[actualY * width + actualX]
                            if pixel == 1 {
                                byteVal |= (1 << (7 - bit))
                            }
                        }
                    }
                    chunkData[row * bytesPerLine + byteIndex] = byteVal
                }
            }
            result.append(contentsOf: chunkData)
            currentY += chunkHeight
        }
        
        return result
    }
    
    /// 将图像转换为与热敏打印机二值化抖动效果完全一致的单色黑白 CGImage（用于高保真小票物理预览）
    ///
    /// 彩色或灰度图片将自动通过 Floyd-Steinberg 误差扩散或阈值二值化处理为纯黑白点阵，杜绝预览图出现彩色。
    /// - Parameter dither: 抖动风格
    /// - Returns: 单色黑白 CGImage
    public func ditheredMonochromeCGImage(dither: ImageDitherStyle = .floydSteinberg) -> CGImage? {
        let width = self.width
        let height = self.height
        guard width > 0 && height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        let maxChunkHeight = 2000
        var currentY = 0
        
        while currentY < height {
            let chunkHeight = min(maxChunkHeight, height - currentY)
            let rect = CGRect(x: 0, y: currentY, width: width, height: chunkHeight)
            guard let cropped = self.cropping(to: rect) else { break }
            
            if let croppedMono = cropped.processChunkToMonochromeCGImage(dither: dither) {
                let drawRect = CGRect(x: 0, y: height - currentY - chunkHeight, width: width, height: chunkHeight)
                context.draw(croppedMono, in: drawRect)
            }
            currentY += chunkHeight
        }
        
        return context.makeImage()
    }
    
    private func processChunkToMonochromeCGImage(dither: ImageDitherStyle = .floydSteinberg) -> CGImage? {
        let width = self.width
        let height = self.height
        guard width > 0 && height > 0 else { return nil }
        
        guard let rgbaData = getRGBAPixels(from: self, width: width, height: height) else {
            return nil
        }
        
        // 灰度矩阵提取
        var grays = [Int](repeating: 255, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Int(rgbaData[offset])
                let g = Int(rgbaData[offset + 1])
                let b = Int(rgbaData[offset + 2])
                let a = Int(rgbaData[offset + 3])
                
                // 透明区域视为白底
                if a < 128 {
                    grays[y * width + x] = 255
                } else {
                    let gray = (r * 299 + g * 587 + b * 114) / 1000
                    grays[y * width + x] = gray
                }
            }
        }
        
        // 二值化点阵计算（0 为黑，255 为白）
        var monoPixels = [UInt8](repeating: 255, count: width * height)
        switch dither {
        case .threshold(let th):
            let threshold = Int(th)
            for i in 0..<(width * height) {
                monoPixels[i] = grays[i] < threshold ? 0 : 255
            }
        case .floydSteinberg:
            var buffer = grays
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    let oldVal = buffer[index]
                    let newVal = oldVal < 128 ? 0 : 255
                    monoPixels[index] = UInt8(newVal)
                    let error = oldVal - newVal
                    
                    if x + 1 < width {
                        buffer[y * width + (x + 1)] += (error * 7) / 16
                    }
                    if y + 1 < height {
                        if x > 0 {
                            buffer[(y + 1) * width + (x - 1)] += (error * 3) / 16
                        }
                        buffer[(y + 1) * width + x] += (error * 5) / 16
                        if x + 1 < width {
                            buffer[(y + 1) * width + (x + 1)] += (error * 1) / 16
                        }
                    }
                }
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &monoPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
}

#if canImport(UIKit)
extension UIImage {
    /// 将 `UIImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    public func rasterEscPosData(dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        return cgImage.rasterEscPosData(dither: dither)
    }
    
    public var rasterEscPosData: Data? {
        rasterEscPosData(dither: .threshold(128))
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension NSImage {
    /// 将 `NSImage` 转换为 ESC/POS 标准光栅位图指令数据流（`GS v 0`）
    public func rasterEscPosData(dither: ImageDitherStyle = .floydSteinberg) -> Data? {
        var proposedRect = CGRect(origin: .zero, size: size)
        guard let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }
        return cgImage.rasterEscPosData(dither: dither)
    }
    
    public var rasterEscPosData: Data? {
        rasterEscPosData(dither: .threshold(128))
    }
}
#endif
