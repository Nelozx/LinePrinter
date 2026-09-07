//
//  TicketJSONDecoder.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
//

import Foundation

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

/// 内部区块 JSON 反序列化模型（覆盖排版元素与硬件动作指令）
struct ChunkModel: Codable {
    var type: String
    
    // MARK: - 文本排版
    var content: String?
    var bold: Bool?
    var alignment: String?
    var size: String?             // "normal", "double", "doubleWidth", "doubleHeight"
    var doubleWidth: Bool?
    var doubleHeight: Bool?
    var doubleSize: Bool?
    var underline: UInt8?         // 0: 无, 1: 单下划线, 2: 双下划线
    var reverse: Bool?            // 反白打印
    
    // MARK: - 分割线
    var char: String?
    var printDensity: Int?
    var fontDensity: Int?
    
    // MARK: - 多列排版
    var columns: [ColumnModel]?
    var totalWidth: Int?
    var left: String?
    var right: String?
    var col1: String?
    var col2: String?
    var col3: String?
    var wrap: Bool?
    
    // MARK: - 位图与条码
    var name: String?             // 本地图片资源名
    var base64: String?           // Base64 图片数据
    var dither: String?           // "floydSteinberg", "threshold"
    var threshold: UInt8?         // 二值化阈值 (0~255)
    var barcodeType: String?      // "code128", "ean13", "code39" 等
    var height: UInt8?
    var width: UInt8?
    var hri: String?              // "below", "above", "both", "none"
    
    // MARK: - 动作指令参数
    var lines: UInt8?             // 走纸行数
    var times: UInt8?             // 蜂鸣器发声次数
    var duration: UInt8?          // 蜂鸣器发声时长系数
    var points: UInt8?            // 自定义行间距点数
    var feedPoints: UInt8?        // 块末进纸点数
    
    // MARK: - 复合组
    var elements: [ChunkModel]?
}

extension ChunkModel {
    /// 将 JSON 数据模型映射转换为具体的 `Chunk` 排版对象
    func toChunk() -> Chunk? {
        var chunk: Chunk?
        
        switch type {
        case "text":
            guard let content = content else { return nil }
            var attrs: [Attribute] = [TextAttribute.alignment(Commands.Alignment(string: alignment))]
            if bold == true { attrs.append(TextAttribute.bold) }
            
            if doubleSize == true || size == "double" || size == "doubleSize" {
                attrs.append(TextAttribute.doubleSize)
            } else {
                if doubleWidth == true || size == "doubleWidth" { attrs.append(TextAttribute.doubleWidth) }
                if doubleHeight == true || size == "doubleHeight" { attrs.append(TextAttribute.doubleHeight) }
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
            let cols = (columns ?? []).map { $0.toCol() }
            chunk = cols.isEmpty ? nil : Chunk(Row(totalWidth: width, columns: cols))
            
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
            
        case "image":
            let ditherStyle: ImageDitherStyle = (dither?.lowercased() == "threshold")
                ? .threshold(threshold ?? 128)
                : .floydSteinberg
            if let b64 = base64 {
                chunk = .image(base64: b64, dither: ditherStyle)
            } else if let name = name {
                chunk = .image(named: name, dither: ditherStyle)
            }
            
        case "group":
            let subChunks = (elements ?? []).compactMap { $0.toChunk() }
            chunk = Chunk(ChunkGroup(subChunks))
            
        // MARK: - 控制与动作指令（统一收敛）
        case "blank":
            chunk = .blank
        case "feed":
            chunk = .feed(lines ?? 1)
        case "beep", "buzzer":
            chunk = .beep(times ?? 1, duration: duration ?? 2)
        case "spacing":
            chunk = .spacing(points ?? 30)
        case "defaultSpacing":
            chunk = .defaultSpacing
        case "blackMark":
            chunk = .blackMark
        case "cut":
            chunk = .cut
        case "partialCut":
            chunk = .partialCut
        case "drawer", "openDrawer":
            chunk = .drawer
        case "feedAndCut":
            chunk = .feedAndCut
            
        default:
            return nil
        }
        
        guard let validChunk = chunk else { return nil }
        return feedPoints.map { validChunk.feed($0) } ?? validChunk
    }
}
