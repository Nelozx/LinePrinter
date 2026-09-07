//
//  TicketJSONDecoder.swift
//  LinePrinter
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// 内部小票 JSON 反序列化模型
struct TicketModel: Codable {
    var autoCut: Bool?
    var autoInitialize: Bool?
    var chunks: [ChunkModel]
}

/// 内部区块 JSON 反序列化模型
struct ChunkModel: Codable {
    var type: String
    
    // Text
    var content: String?
    var bold: Bool?
    var alignment: String?
    
    // Splitter
    var char: String?
    var printDensity: Int?
    var fontDensity: Int?
    
    // Columns
    var left: String?
    var right: String?
    var col1: String?
    var col2: String?
    var col3: String?
    var wrap: Bool?
    var totalWidth: Int?
    
    // Image
    var name: String?
    
    // Barcode / QRCode
    var barcodeType: String?
    var height: UInt8?
    var width: UInt8?
    
    // Actions
    var lines: UInt8?
    var times: UInt8?
    
    var feedPoints: UInt8?
}

extension ChunkModel {
    /// 将 JSON 数据模型映射转换为实际的 `Chunk` 对象
    func toChunk() -> Chunk? {
        let chunk: Chunk?
        switch type {
        case "text":
            guard let content = content else { return nil }
            chunk = .text(content, bold: bold ?? false, alignment: Commands.Alignment(string: alignment))
            
        case "splitter":
            chunk = .splitter(char?.first ?? "-", printDensity: printDensity ?? 384, fontDensity: fontDensity ?? 12)
            
        case "twoColumn":
            chunk = .row(left ?? "", right ?? "", totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            
        case "threeColumn":
            chunk = .row(col1 ?? "", col2 ?? "", col3 ?? "", totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            
        case "row":
            if let c3 = col3 {
                chunk = .row(col1 ?? "", col2 ?? "", c3, totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            } else {
                chunk = .row(left ?? col1 ?? "", right ?? col2 ?? "", totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            }
            
        case "barcode":
            guard let content = content else { return nil }
            chunk = .barcode(content, type: Commands.BarCodeType(string: barcodeType), height: height ?? 64, width: width ?? 2)
            
        case "qrcode":
            guard let content = content else { return nil }
            chunk = .qrcode(content)
            
        case "image":
            guard let name = name else { return nil }
            #if canImport(UIKit)
            chunk = .image(UIImage(named: name))
            #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
            chunk = .image(NSImage(named: name))
            #else
            chunk = nil
            #endif
            
        case "feed":
            return .feed(lines ?? 1)
            
        case "buzzer", "beep":
            return .beep(times ?? 1)
            
        case "cut":
            return .cut
            
        case "partialCut":
            return .partialCut
            
        case "openDrawer", "drawer":
            return .drawer
            
        case "feedAndCut":
            return .feedAndCut
            
        default:
            return nil
        }
        
        if let feed = feedPoints, let valid = chunk {
            return valid.feed(feed)
        }
        return chunk
    }
}
