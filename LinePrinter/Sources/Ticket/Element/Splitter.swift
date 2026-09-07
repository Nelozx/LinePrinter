//
//  Splitter.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation


/// 分隔线/分割条打印元素
///
/// 根据指定的打印纸宽度密度与单字符密度，自动重复填充字符生成横跨整行的小票分割线。
public struct Splitter: Printable {
    
    let provider: SplitterProvider
    let printDensity: Int
    let fontDensity: Int
    
    /// 初始化小票分割线
    /// - Parameters:
    ///   - provider: 分割字符提供者（如 `"-"`、`"="`、`"*"`）
    ///   - printDensity: 纸张总宽度打印点数/字符容量（58mm 通常为 384 或 32，80mm 通常为 576 或 48）
    ///   - fontDensity: 单个字符占用宽度（通常为 12 或 1）
    public init(provider: SplitterProvider, printDensity: Int, fontDensity: Int) {
        self.provider = provider
        self.printDensity = printDensity
        self.fontDensity = fontDensity
    }
    
    /// 生成分割线文本的二进制数据
    /// - Parameter encoding: 字符编码
    /// - Returns: 编码后的分割线二进制数据
    public func data(using encoding: String.Encoding) -> Data {
        let num = printDensity / fontDensity
        let content: String
        if let char = provider as? Character {
            content = String(repeating: char, count: max(0, num))
        } else {
            content = (0..<num).map { String(provider.character(for: $0, total: num)) }.joined()
        }
        return Text(content).data(using: encoding)
    }
    
}

/// 分割条字符提供者协议
public protocol SplitterProvider {
    /// 获取指定索引处的字符
    /// - Parameters:
    ///   - current: 当前字符索引（0-indexed）
    ///   - total: 一行中的总字符数
    /// - Returns: 应当显示的字符
    func character(for current: Int, total: Int) -> Character
}

extension Character: SplitterProvider {
    /// Character 默认实现 SplitterProvider，整行重复该单一字符
    public func character(for current: Int, total: Int) -> Character {
        return self
    }
}
