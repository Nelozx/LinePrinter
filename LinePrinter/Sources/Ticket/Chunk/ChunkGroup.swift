//
//  ChunkGroup.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation

/// 垂直纵向块分组容器
///
/// 将多个小票块（`Chunk`）组合成一个逻辑分组，按顺序依次转换为 ESC/POS 数据流。
///
/// 示例：
/// ```swift
/// let group = ChunkGroup(
///     .text("欢迎光临", alignment: .center),
///     .feed(1)
/// )
/// ```
public struct ChunkGroup: ChunkProvider {
    
    /// 包含的子小票块列表
    public private(set) var elements: [Chunk] = []
    
    /// 使用块数组初始化分组容器
    /// - Parameter elements: 小票块数组
    public init(_ elements: [Chunk]) {
        self.elements = elements
    }
    
    /// 使用可变参数列表初始化分组容器
    /// - Parameter elements: 小票块变长列表
    public init(_ elements: Chunk...) {
        self.elements = elements
    }
    
    /// 将分组内所有小票块按字符编码转换为组合的二进制数据
    /// - Parameter encoding: 字符编码（如 `.utf8`、`.gb18030`）
    /// - Returns: 合并后的 ESC/POS 二进制数据
    public func data(using encoding: String.Encoding) -> Data {
        return elements.reduce(Data()) { $0 + $1.data(using: encoding) }
    }
}
