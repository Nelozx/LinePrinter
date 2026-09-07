//
//  TicketBuilder.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
//

import Foundation

#if swift(>=5.4)
/// 小票排版块结果构造器 (Result Builder)
///
/// 赋予 `LinePrinter` 如同 SwiftUI 一般纯净的声明式 DSL 语法。
/// 无需中括号 `[]`，无需逗号，支持原生 `if / else` 条件控制与 `for ... in` 列表循环遍历。
@resultBuilder
public struct TicketBuilder {
    public static func buildBlock(_ components: [Chunk]...) -> [Chunk] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ expression: Chunk) -> [Chunk] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [Chunk]) -> [Chunk] {
        expression
    }
    
    public static func buildOptional(_ component: [Chunk]?) -> [Chunk] {
        component ?? []
    }
    
    public static func buildEither(first component: [Chunk]) -> [Chunk] {
        component
    }
    
    public static func buildEither(second component: [Chunk]) -> [Chunk] {
        component
    }
    
    public static func buildArray(_ components: [[Chunk]]) -> [Chunk] {
        components.flatMap { $0 }
    }
}
#else
@_functionBuilder
public struct TicketBuilder {
    public static func buildBlock(_ components: [Chunk]...) -> [Chunk] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ expression: Chunk) -> [Chunk] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [Chunk]) -> [Chunk] {
        expression
    }
    
    public static func buildOptional(_ component: [Chunk]?) -> [Chunk] {
        component ?? []
    }
    
    public static func buildEither(first component: [Chunk]) -> [Chunk] {
        component
    }
    
    public static func buildEither(second component: [Chunk]) -> [Chunk] {
        component
    }
}
#endif
