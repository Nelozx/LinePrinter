//
//  Ticket.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/11.
//

import Foundation

/// 小票实体模型
///
/// 承载所有小票排版块（`Chunk`），负责组装头部初始化指令（`ESC @`）、各个排版块的字节流以及小票末尾的走纸与切纸动作。
///
/// ```swift
/// let ticket = Ticket(
///     chunks: [
///         .text("味美餐饮店", bold: true, alignment: .center),
///         .splitter,
///         .twoColumn("实付金额", "￥40.00")
///     ],
///     autoInitialize: true,
///     autoCut: true
/// )
///
/// // 获取连续二进制指令流
/// let data: Data = ticket.bytes(using: .gbk)
/// ```
public struct Ticket {
    
    /// 是否在小票头部自动执行打印机初始化指令（`ESC @`），默认为 `true`
    ///
    /// 开启后会在每次打印前重置打印机状态（清除之前未打印完的字符、样式与行间距）。
    public var autoInitialize: Bool = true
    
    /// 是否在小票末尾自动走纸并切纸，默认为 `false`
    ///
    /// 开启后会在最后一个块输出后自动执行进纸切纸指令（`Data.feedAndCut`）。
    public var autoCut: Bool = false
    
    /// 当前小票包含的排版块列表
    public private(set) var chunks: [Chunk] = []
    
    /// 使用变长参数初始化小票
    /// - Parameter chunks: 变长排版块
    public init(_ chunks: Chunk...) {
        self.chunks = chunks
    }
    
    /// 初始化小票
    /// - Parameters:
    ///   - chunks: 排版块数组
    ///   - autoInitialize: 是否在头部自动初始化，默认 `true`
    ///   - autoCut: 是否在末尾自动走纸切纸，默认 `false`
    public init(chunks: [Chunk], autoInitialize: Bool = true, autoCut: Bool = false) {
        self.chunks = chunks
        self.autoInitialize = autoInitialize
        self.autoCut = autoCut
    }
    
    /// 使用声明式 DSL 构建小票（SwiftUI 风格，无需方括号与逗号，原生支持 if / for 循环）
    /// - Parameters:
    ///   - autoInitialize: 是否在头部自动初始化，默认 `true`
    ///   - autoCut: 是否在末尾自动切纸，默认 `false`
    ///   - builder: 排版构建闭包
    ///
    /// ```swift
    /// let ticket = Ticket(autoCut: true) {
    ///     Chunk.text("味美餐饮店", bold: true, alignment: .center)
    ///     Chunk.splitter
    ///     for item in items {
    ///         Chunk.threeColumn(item.name, item.qty, item.price)
    ///     }
    ///     Chunk.qrcode("https://...")
    /// }
    /// ```
    public init(autoInitialize: Bool = true, autoCut: Bool = false, @TicketBuilder builder: () -> [Chunk]) {
        self.chunks = builder()
        self.autoInitialize = autoInitialize
        self.autoCut = autoCut
    }
    
    /// 向小票末尾追加单个排版块
    /// - Parameter chunk: 要追加的排版块
    public mutating func append(_ chunk: Chunk) {
        chunks.append(chunk)
    }
    
    /// 向小票末尾批量追加排版块
    /// - Parameter newChunks: 排版块数组
    public mutating func append(_ newChunks: [Chunk]) {
        chunks.append(contentsOf: newChunks)
    }
    
    /// 生成小票各个块的分包二进制数据数组
    /// - Parameter encoding: 字符编码（中文通常为 `.gbk` 或 `.utf8`）
    /// - Returns: 二进制数据分包数组
    public func data(using encoding: String.Encoding) -> [Data] {
        var payload = [Data]()
        
        // 头部初始化
        if autoInitialize {
            payload.append(Data(escpos: .initialize, .printAndFeed(lines: 0)))
        }
        
        for chunk in chunks {
            payload.append(chunk.data(using: encoding))
        }
        
        // 尾部切纸
        if autoCut {
            payload.append(Data.feedAndCut)
        }
        
        return payload
    }
    
    /// 生成完整连续的 ESC/POS 标准二进制数据流
    ///
    /// 便于直接写入任意外部蓝牙外设特征值（`CBPeripheral.writeValue`）、局域网 Socket 或商用 POS 硬件 SDK。
    /// - Parameter encoding: 字符编码，默认 `.gbk`（GBK / GB18030 汉字编码）
    /// - Returns: 完整连续的标准二进制小票指令数据 `Data`
    ///
    /// ```swift
    /// let data: Data = ticket.bytes(using: .gbk)
    /// myPeripheral.writeValue(data, for: myChar, type: .withoutResponse)
    /// ```
    public func bytes(using encoding: String.Encoding = .gbk) -> Data {
        data(using: encoding).reduce(Data(), +)
    }
    
    /// 将小票输出到指定的外部通信通道（`PrinterTransport`）
    /// - Parameters:
    ///   - transport: 遵循 `PrinterTransport` 的输出目标对象
    ///   - encoding: 字符编码，默认 `.gbk`
    /// - Returns: 当前小票对象（支持流式链式调用）
    ///
    /// ```swift
    /// ticket.print(to: myTransport, encoding: .gbk)
    /// ```
    @discardableResult
    public func print(to transport: PrinterTransport, encoding: String.Encoding = .gbk) -> Ticket {
        transport.write(bytes(using: encoding))
        return self
    }
    
    /// 获取当前小票编译出的十六进制指令字符串（便于调试与协议比对）
    /// - Parameter encoding: 字符编码，默认 `.gbk`
    /// - Returns: 形如 `"1B 40 1B 61 01 ..."` 的十六进制字符串
    public func hexDump(using encoding: String.Encoding = .gbk) -> String {
        bytes(using: encoding).map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
