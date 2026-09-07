//
//  Ticket+JSON.swift
//  LinePrinter
//

import Foundation

public extension Ticket {
    
    /// 解析 JSON 数据初始化小票
    /// - Parameter jsonData: JSON 二进制数据
    /// - Throws: 如果 JSON 格式错误或无法解析，将抛出 `DecodingError`
    init(jsonData: Data) throws {
        let decoder = JSONDecoder()
        let model = try decoder.decode(TicketModel.self, from: jsonData)
        
        let chunks = model.chunks.compactMap { $0.toChunk() }
        
        self.init(
            chunks: chunks,
            autoInitialize: model.autoInitialize ?? true,
            autoCut: model.autoCut ?? true
        )
    }
    
    /// 解析 JSON 字符串初始化小票
    /// - Parameter jsonString: 包含排版描述的 JSON 字符串
    /// - Throws: 如果 JSON 格式错误或无法解析，将抛出异常
    init(jsonString: String) throws {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "LinePrinter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON String encoding"])
        }
        try self.init(jsonData: data)
    }
}
