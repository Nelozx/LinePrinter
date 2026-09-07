//
//  Typography.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/8.
//

import Foundation

// MARK: - 字符打印宽度测算
public extension Character {
    /// 是否为全角字符（全角符号、汉字、Emoji 等宽度为 2）
    var isFullWidth: Bool {
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
    var printWidth: Int {
        isFullWidth ? 2 : 1
    }
}

// MARK: - 字符串排版宽度与对齐填充
public extension String {
    /// 字符串在小票上的实际占用打印宽度（全角汉字=2，半角=1）
    var printDisplayWidth: Int {
        reduce(0) { $0 + $1.printWidth }
    }
    
    /// 按照小票打印宽度对齐并填充空格
    func padToPrintWidth(_ targetWidth: Int, alignment: Commands.Alignment = .left) -> String {
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

// MARK: - 字符集编码扩展
public extension String.Encoding {
    /// 中文编码字符集 (GB18030 / GBK)
    static let gbk: String.Encoding = .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
}
