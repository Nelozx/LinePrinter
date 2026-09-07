//
//  TicketJSONDecoder.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
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

/// 单列 JSON 反序列化模型
struct ColumnModel: Codable {
    var text: String
    var width: Int?
    var weight: Int?
    var alignment: String?
    var wrap: Bool?
    
    func toCol() -> Col {
        Col(
            text,
            width: width,
            weight: weight ?? 1,
            alignment: Commands.Alignment(string: alignment),
            wrap: wrap ?? false
        )
    }
}

/// 内部区块 JSON 反序列化模型（全排版元素与指令覆盖）
struct ChunkModel: Codable {
    var type: String
    
    // MARK: - Text 文本
    var content: String?
    var bold: Bool?
    var alignment: String?
    var size: String?             // "normal", "double", "doubleWidth", "doubleHeight"
    var doubleWidth: Bool?
    var doubleHeight: Bool?
    var doubleSize: Bool?
    var underline: UInt8?         // 0: 无, 1: 单下划线, 2: 双下划线
    var reverse: Bool?            // 反白打印
    
    // MARK: - Splitter 分割线
    var char: String?
    var printDensity: Int?
    var fontDensity: Int?
    
    // MARK: - Row 多列排版（支持任意列数组，以及双列/三列快捷字段）
    var columns: [ColumnModel]?
    var totalWidth: Int?
    var left: String?
    var right: String?
    var col1: String?
    var col2: String?
    var col3: String?
    var wrap: Bool?
    
    // MARK: - Image 点阵位图
    var name: String?             // 本地图片资源名
    var base64: String?           // 远程/服务端下发的 Base64 图片数据
    var url: String?              // 远程图片 URL 地址
    var dither: String?           // "floydSteinberg", "threshold"
    var threshold: UInt8?         // 二值化阈值 (0~255)
    
    // MARK: - BarCode 条码
    var barcodeType: String?      // "code128", "ean13", "code39", etc.
    var height: UInt8?
    var width: UInt8?
    var hri: String?              // "below", "above", "both", "none"
    
    // MARK: - Actions 指令动作
    var lines: UInt8?             // 走纸行数
    var times: UInt8?             // 蜂鸣器发声次数
    var duration: UInt8?          // 蜂鸣器发声时长系数
    var points: UInt8?            // 自定义行间距点数
    
    // MARK: - Group 复合组
    var elements: [ChunkModel]?
    
    // MARK: - 通用走纸
    var feedPoints: UInt8?
}

extension ChunkModel {
    /// 将 JSON 数据模型映射转换为实际的 `Chunk` 对象
    func toChunk() -> Chunk? {
        let chunk: Chunk?
        switch type {
        case "text":
            guard let content = content else { return nil }
            var attrs: [Attribute] = [TextAttribute.alignment(Commands.Alignment(string: alignment))]
            if bold == true { attrs.append(TextAttribute.bold) }
            
            let isDoubleSize = doubleSize == true || size == "double" || size == "doubleSize"
            let isDoubleWidth = doubleWidth == true || size == "doubleWidth"
            let isDoubleHeight = doubleHeight == true || size == "doubleHeight"
            
            if isDoubleSize {
                attrs.append(TextAttribute.doubleSize)
            } else {
                if isDoubleWidth { attrs.append(TextAttribute.doubleWidth) }
                if isDoubleHeight { attrs.append(TextAttribute.doubleHeight) }
            }
            if let u = underline, u > 0 { attrs.append(TextAttribute.underline(u)) }
            if reverse == true { attrs.append(TextAttribute.reverse(true)) }
            
            chunk = Chunk(Text(content, attributes: attrs))
            
        case "splitter":
            chunk = .splitter(char?.first ?? "-", printDensity: printDensity ?? 384, fontDensity: fontDensity ?? 12)
            
        case "twoColumn":
            chunk = .row(left ?? "", right ?? "", totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            
        case "threeColumn":
            chunk = .row(col1 ?? "", col2 ?? "", col3 ?? "", totalWidth: totalWidth ?? 32, wrap: wrap ?? false)
            
        case "row":
            let width = totalWidth ?? 32
            if let cols = columns, !cols.isEmpty {
                // 完全支持任意数量多列配置
                chunk = Chunk(Row(totalWidth: width, columns: cols.map { $0.toCol() }))
            } else if let c3 = col3 {
                chunk = .row(col1 ?? "", col2 ?? "", c3, totalWidth: width, wrap: wrap ?? false)
            } else {
                chunk = .row(left ?? col1 ?? "", right ?? col2 ?? "", totalWidth: width, wrap: wrap ?? false)
            }
            
        case "barcode":
            guard let content = content else { return nil }
            chunk = .barcode(
                content,
                type: Commands.BarCodeType(string: barcodeType),
                height: height ?? 64,
                width: width ?? 2,
                hri: Commands.BarCodeHRIPosition(string: hri)
            )
            
        case "qrcode":
            guard let content = content else { return nil }
            chunk = .qrcode(content)
            
        case "blank":
            chunk = .blank
            
        case "image":
            let ditherStyle: ImageDitherStyle = (dither?.lowercased() == "threshold")
                ? .threshold(threshold ?? 128)
                : .floydSteinberg
            
            if let b64 = base64 {
                chunk = .image(base64: b64, dither: ditherStyle)
            } else if let u = url {
                chunk = .image(url: u, dither: ditherStyle)
            } else if let name = name {
                chunk = .image(named: name, dither: ditherStyle)
            } else {
                chunk = nil
            }
            
        case "group":
            let subChunks = (elements ?? []).compactMap { $0.toChunk() }
            chunk = Chunk(ChunkGroup(subChunks))
            
        case "feed":
            return .feed(lines ?? 1)
            
        case "buzzer", "beep":
            return .beep(times ?? 1, duration: duration ?? 2)
            
        case "spacing", "lineSpacing":
            return .spacing(points ?? 30)
            
        case "defaultSpacing", "defaultLineSpacing":
            return .defaultSpacing
            
        case "blackMark", "feedToBlackMark":
            return .blackMark
            
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
