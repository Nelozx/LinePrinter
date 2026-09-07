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
        let feed = feedPoints ?? Chunk.defaultFeedPoints
        
        switch type {
        case "text":
            guard let content = content else { return nil }
            let isBold = bold ?? false
            var align: Commands.Alignment = .left
            if alignment == "center" { align = .center }
            else if alignment == "right" { align = .right }
            
            var attrs: [Attribute] = [TextAttribute.alignment(align)]
            if isBold { attrs.append(TextAttribute.bold) }
            
            return Chunk(Text(content, attributes: attrs), feedPoints: feed)
            
        case "splitter":
            let c = (char?.first) ?? "-"
            return Chunk(Splitter(provider: c, printDensity: printDensity ?? 384, fontDensity: fontDensity ?? 12), feedPoints: feed)
            
        case "twoColumn":
            let l = left ?? ""
            let r = right ?? ""
            return Chunk(Row(totalWidth: totalWidth ?? 32,
                             Col(l, weight: 1, alignment: .left, wrap: wrap ?? false),
                             Col(r, weight: 1, alignment: .right)), feedPoints: feed)
            
        case "threeColumn":
            let c1 = col1 ?? ""
            let c2 = col2 ?? ""
            let c3 = col3 ?? ""
            return Chunk(Row(totalWidth: totalWidth ?? 32,
                             Col(c1, weight: 2, alignment: .left, wrap: wrap ?? false),
                             Col(c2, weight: 1, alignment: .center),
                             Col(c3, weight: 1, alignment: .right)), feedPoints: feed)
            
        case "barcode":
            guard let content = content else { return nil }
            var bType: Commands.BarCodeType = .code128
            if barcodeType == "upcA" { bType = .upcA }
            else if barcodeType == "ean13" || barcodeType == "jan13" { bType = .jan13 }
            return Chunk(BarCode(content, type: bType, height: height ?? 64, width: width ?? 2, hri: .below), feedPoints: feed)
            
        case "qrcode":
            guard let content = content else { return nil }
            return Chunk(QRCode(content), feedPoints: feed)
            
        case "image":
            guard let name = name else { return nil }
            #if canImport(UIKit)
            if let img = UIImage(named: name) {
                return Chunk(Image(img, dither: .floydSteinberg), feedPoints: feed)
            }
            #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let img = NSImage(named: name) {
                return Chunk(Image(img, dither: .floydSteinberg), feedPoints: feed)
            }
            #endif
            return nil
            
        case "feed":
            return .feed(lines ?? 1)
            
        case "buzzer":
            return .beep(times ?? 1)
            
        case "cut":
            return .cut
            
        case "partialCut":
            return .partialCut
            
        case "openDrawer":
            return .openDrawer
            
        case "feedAndCut":
            return .feedAndCut
            
        default:
            return nil
        }
    }
}
