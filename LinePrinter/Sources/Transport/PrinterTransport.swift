//
//  PrinterTransport.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/19.
//

import Foundation

/// 打印机物理硬件状态集合（OptionSet）
///
/// 解析标准 ESC/POS 状态查询指令（`DLE EOT`）返回的原始单字节，可方便地通过 `.contains(...)` 判断打印机是否存在异常。
///
/// ```swift
/// let status = PrinterHardwareStatus.parse(byte: receivedByte)
///
/// if status.isNormal {
///     print("打印机正常就绪")
/// } else {
///     if status.contains(.paperEmpty) {
///         print("⚠️ 打印机缺纸！")
///     }
///     if status.contains(.coverOpen) {
///         print("⚠️ 打印机机盖打开！")
///     }
///     if status.contains(.offline) {
///         print("⚠️ 打印机脱机！")
///     }
/// }
/// ```
public struct PrinterHardwareStatus: OptionSet, CustomStringConvertible {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    /// 打印机正常就绪（无任何异常）
    public static let normal = PrinterHardwareStatus([])
    
    /// 机盖已打开
    public static let coverOpen = PrinterHardwareStatus(rawValue: 1 << 0)
    
    /// 纸将尽（提示即将缺纸）
    public static let paperNearEnd = PrinterHardwareStatus(rawValue: 1 << 1)
    
    /// 已经缺纸（纸卷已用尽）
    public static let paperEmpty = PrinterHardwareStatus(rawValue: 1 << 2)
    
    /// 打印机脱机（未联机或暂停）
    public static let offline = PrinterHardwareStatus(rawValue: 1 << 3)
    
    /// 打印机发生硬件错误（如切刀卡纸、过热保护）
    public static let error = PrinterHardwareStatus(rawValue: 1 << 4)
    
    /// 是否处于完全正常的就绪状态
    public var isNormal: Bool {
        rawValue == 0
    }
    
    /// 人类可读的状态文本描述（如 "机盖已打开, 缺纸"）
    public var description: String {
        if isNormal { return "正常就绪" }
        var list = [String]()
        if contains(.coverOpen) { list.append("机盖已打开") }
        if contains(.paperNearEnd) { list.append("纸将尽") }
        if contains(.paperEmpty) { list.append("缺纸") }
        if contains(.offline) { list.append("脱机") }
        if contains(.error) { list.append("打印机错误") }
        return list.joined(separator: ", ")
    }
    
    /// 解析标准 ESC/POS 状态单字节
    /// - Parameter byte: 打印机通过蓝牙通知或 Socket 返回的状态字节（0~255）
    /// - Returns: 解析后的结构化状态
    public static func parse(byte: UInt8) -> PrinterHardwareStatus {
        var status = PrinterHardwareStatus()
        if (byte & 0x04) != 0 {
            status.insert(.coverOpen)
        }
        if (byte & 0x0C) == 0x0C {
            status.insert(.paperNearEnd)
        }
        if (byte & 0x60) == 0x60 {
            status.insert(.paperEmpty)
        }
        if (byte & 0x08) != 0 || (byte & 0x20) != 0 {
            status.insert(.offline)
        }
        if (byte & 0x40) != 0 {
            status.insert(.error)
        }
        return status
    }
}

/// 打印机输出通道极简协议
///
/// 凡是能够向外输出打印机二进制数据（`Data`）的对象（如外部自建的蓝牙管理器、TCP Socket 连接池、USB 驱动等）均可遵循此协议。
///
/// ```swift
/// class MyBluetoothManager: PrinterTransport {
///     func write(_ data: Data) {
///         // 外部自行执行 BLE 分包发送
///         peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
///     }
/// }
///
/// let transport = MyBluetoothManager()
/// ticket.print(to: transport)
/// ```
public protocol PrinterTransport: AnyObject {
    /// 向外部硬件通信通道输出打印小票连续二进制数据流
    /// - Parameter data: 标准 ESC/POS 二进制字节流
    func write(_ data: Data)
}
