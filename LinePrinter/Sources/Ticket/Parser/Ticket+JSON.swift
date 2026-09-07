//
//  Ticket+JSON.swift
//  LinePrinter
//

import Foundation

public extension Ticket {
    
    /// 解析 JSON 数据初始化小票
    init(json data: Data) throws {
        let model = try JSONDecoder().decode(TicketModel.self, from: data)
        self.init(chunks: model.chunks.compactMap { $0.toChunk() },
                  autoInitialize: model.autoInitialize ?? true,
                  autoCut: model.autoCut ?? true)
    }
    
    /// 解析 JSON 字符串初始化小票
    init(json string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "LinePrinter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON String"])
        }
        try self.init(json: data)
    }
}
