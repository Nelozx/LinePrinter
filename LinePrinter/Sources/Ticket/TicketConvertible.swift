//
//  TicketConvertible.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/8.
//

import Foundation
import CoreGraphics

/// 可转换为小票实体的模型协议（业务数据 DTO、第三方订单模型均可遵循此协议）
///
/// 适合“服务端只返回业务数据（订单号、菜品列表、总价），而不关心排版”的真实商业场景。
/// 业务方无需修改后端接口，只需在客户端声明一个扩展遵循此协议，即可直接获取 `Ticket` 进行预览或打印。
///
/// ```swift
/// // 1. 公司自己原有的业务模型
/// struct OrderDTO: Codable, TicketConvertible {
///     let orderNo: String
///     let items: [Item]
///     let total: Double
///     
///     func asTicket(paper: ReceiptPaperWidth) -> Ticket {
///         LinePrinter.ticket(
///             .text("订单号：\(orderNo)", bold: true, alignment: .center),
///             .splitter,
///             .row(items.map { Col($0.name, weight: 2) }),
///             .row("合计", "￥\(total)")
///         )
///     }
/// }
///
/// // 2. 一行代码优雅调用
/// let order = try JSONDecoder().decode(OrderDTO.self, from: data)
/// order.asTicket().preview()
/// order.asTicket().print(to: transport)
/// ```
public protocol TicketConvertible {
    /// 转换为 LinePrinter 小票模型
    /// - Parameter paper: 目标纸张规格（默认 58mm）
    /// - Returns: 可直接排版、预览或打印的小票实体 `Ticket`
    func asTicket(paper: ReceiptPaperWidth) -> Ticket
}

public extension TicketConvertible {
    /// 默认使用 58mm 规格生成小票
    func asTicket() -> Ticket {
        asTicket(paper: .mm58)
    }
}

public extension LinePrinter {
    /// 门面便捷方法：快速将任意遵循 `TicketConvertible` 的业务模型转为小票实体
    static func ticket(_ convertible: TicketConvertible, paper: ReceiptPaperWidth = .mm58) -> Ticket {
        convertible.asTicket(paper: paper)
    }
}
