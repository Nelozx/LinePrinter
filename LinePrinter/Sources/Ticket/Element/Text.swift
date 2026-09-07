//
//  Text.swift
//  LineThermalPrinter
//
//  Created by Nelo on 2022/4/11.
//

import Foundation

/// 文本排版样式修饰属性
public enum TextAttribute: Attribute {
    /// 文本对齐方式（居左、居中、居右）
    case alignment(Commands.Alignment)
    /// 字体加粗
    case bold
    /// 普通标准样式（清除所有加粗、倍宽倍高）
    case normal
    /// 双倍宽度（横向拉伸 2 倍）
    case doubleWidth
    /// 双倍高度（纵向拉伸 2 倍）
    case doubleHeight
    /// 双倍尺寸（同时倍宽倍高，常用于大号单号、叫号标题）
    case doubleSize
    /// 字体选择（标准字体 A 或压缩字体 B）
    case font(Commands.Font)
    /// 下划线（0 为关闭，1 为单下划线，2 为双下划线）
    case underline(UInt8)
    /// 反白打印（黑底白字）
    case reverse(Bool)
    /// 附加走纸行数
    case feed(UInt8)
    
    public var attribute: [UInt8] {
        switch self {
        case .alignment(let align):
            return Commands.alignment(align).rawValue
        case .bold:
            return Commands.emphasize(1).rawValue
        case .normal:
            return Commands.batchPrint(modes: 0).rawValue
        case .doubleWidth:
            return Commands.batchPrint(modes: 32).rawValue
        case .doubleHeight:
            return Commands.batchPrint(modes: 16).rawValue
        case .doubleSize:
            return Commands.batchPrint(modes: 48).rawValue
        case .font(let font):
            return Commands.font(font).rawValue
        case .underline(let n):
            return Commands.underline(n).rawValue
        case .reverse(let on):
            return Commands.reverse(on ? 1 : 0).rawValue
        case .feed(let v):
            return Commands.printAndFeed(lines: v).rawValue
        }
    }
    
    public var resetAttribute: [UInt8]? {
        switch self {
        case .alignment:
            return Commands.alignment(.left).rawValue
        case .bold:
            return Commands.emphasize(0).rawValue
        case .doubleWidth, .doubleHeight, .doubleSize:
            return Commands.batchPrint(modes: 0).rawValue
        case .underline:
            return Commands.underline(0).rawValue
        case .reverse:
            return Commands.reverse(0).rawValue
        default:
            return nil
        }
    }
}

/// 基础文本排版元素
///
/// 封装了文本内容与其附加的 ESC/POS 样式属性，并在打印完成后自动复位样式，防止样式污染下一行。
public struct Text: Printable {
    
    /// 文本内容
    public let content: String
    
    /// 样式属性集合（如加粗、对齐等）
    public let attributes: [Attribute]?
    
    /// 初始化文本排版元素
    /// - Parameters:
    ///   - content: 文本字符串
    ///   - attributes: 样式属性数组
    public init(_ content: String, attributes: [Attribute]? = nil) {
        self.content = content
        self.attributes = attributes
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        var payload = Data()
        var resetBytes = [UInt8]()
        
        if let attributes = attributes {
            for attr in attributes {
                payload.append(contentsOf: attr.attribute)
                if let textAttr = attr as? TextAttribute, let reset = textAttr.resetAttribute {
                    resetBytes.append(contentsOf: reset)
                }
            }
        }
        
        if let textData = content.data(using: encoding) {
            payload += textData
        }
        
        if !resetBytes.isEmpty {
            payload.append(contentsOf: resetBytes)
        }
        
        return payload
    }
}

// MARK: - 字符宽度扩展（用于小票对齐排版）
extension Character {
    /// 是否为全角字符（全角符号、汉字、Emoji 等宽度为 2）
    public var isFullWidth: Bool {
        for scalar in unicodeScalars {
            // ASCII 字符为半角 (1)
            if scalar.value <= 0x007F {
                continue
            }
            // 常见全角区间 (CJK、全角标点、中文扩展等)
            if (0x3000...0x9FFF).contains(scalar.value) ||
               (0xFF01...0xFF60).contains(scalar.value) ||
               (0xFFE0...0xFFE6).contains(scalar.value) ||
               (0x20000...0x2FA1F).contains(scalar.value) {
                return true
            }
            // 其它非 ASCII 字符也视为全角
            return true
        }
        return false
    }
    
    /// 字符在热敏小票上的打印宽度（半角=1，全角=2）
    public var printWidth: Int {
        isFullWidth ? 2 : 1
    }
}

extension String {
    /// 字符串在小票上的实际占用打印宽度（考虑全角汉字=2，半角=1）
    public var printDisplayWidth: Int {
        reduce(0) { $0 + $1.printWidth }
    }
    
    /// 按照小票打印宽度对齐并填充空格
    public func padToPrintWidth(_ targetWidth: Int, alignment: Commands.Alignment = .left) -> String {
        let currentWidth = printDisplayWidth
        if currentWidth >= targetWidth {
            return self
        }
        let spaceCount = targetWidth - currentWidth
        switch alignment {
        case .left:
            return self + String(repeating: " ", count: spaceCount)
        case .right:
            return String(repeating: " ", count: spaceCount) + self
        case .center:
            let leftSpaces = spaceCount / 2
            let rightSpaces = spaceCount - leftSpaces
            return String(repeating: " ", count: leftSpaces) + self + String(repeating: " ", count: rightSpaces)
        }
    }
}

extension String.Encoding {
    /// 中文编码字符集 (GB18030 / GBK)
    public static let gbk: String.Encoding = .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
