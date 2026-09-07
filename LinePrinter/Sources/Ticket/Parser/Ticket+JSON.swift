//
//  Ticket+JSON.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
//

import Foundation

public extension Ticket {
    
    /// 解析标准小票 JSON 数据初始化小票（全元素覆盖）
    init(json data: Data) throws {
        let model = try JSONDecoder().decode(TicketModel.self, from: data)
        self.init(chunks: model.chunks.compactMap { $0.toChunk() },
                  autoInitialize: model.autoInitialize ?? true,
                  autoCut: model.autoCut ?? true)
    }
    
    /// 解析标准小票 JSON 字符串初始化小票（全元素覆盖）
    init(json string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "LinePrinter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON String"])
        }
        try self.init(json: data)
    }
    
    /// 使用自定义映射闭包解析任意格式的公司私有 JSON 数据构建小票
    /// - Parameters:
    ///   - data: 任意格式的 JSON 数据
    ///   - mapper: 转换适配闭包（将反序列化得到的原始对象字典/数组映射为 `Ticket`）
    init(json data: Data, mapper: (Any) throws -> Ticket) throws {
        let root = try JSONSerialization.jsonObject(with: data, options: [])
        self = try mapper(root)
    }
    
    /// 使用自定义映射闭包解析任意格式的公司私有 JSON 字符串构建小票
    init(json string: String, mapper: (Any) throws -> Ticket) throws {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "LinePrinter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON String"])
        }
        try self.init(json: data, mapper: mapper)
    }
}
