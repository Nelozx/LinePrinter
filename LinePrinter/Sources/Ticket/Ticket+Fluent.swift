//
//  Ticket+Fluent.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/7.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 极简流畅链式排版 API (Fluent Chaining API)

public extension Ticket {
    
    /// 空小票快捷构建器（链式调用起点）
    ///
    /// ```swift
    /// Ticket.make()
    ///     .text("味美餐饮旗舰店", bold: true, alignment: .center)
    ///     .splitter()
    ///     .twoColumn("实付金额", "￥50.00")
    ///     .qrcode("https://...")
    ///     .cut()
    ///     .print(to: bluetooth)
    /// ```
    static func make(autoInitialize: Bool = true, autoCut: Bool = false) -> Ticket {
        Ticket(chunks: [], autoInitialize: autoInitialize, autoCut: autoCut)
    }
    
    /// 追加单个排版块（链式调用）
    @discardableResult
    func chunk(_ chunk: Chunk) -> Ticket {
        var copy = self
        copy.append(chunk)
        return copy
    }
    
    /// 追加快捷文本（链式调用）
    @discardableResult
    func text(_ content: String, bold: Bool = false, alignment: Commands.Alignment = .left) -> Ticket {
        chunk(.text(content, bold: bold, alignment: alignment))
    }
    
    /// 追加带完整属性修饰的文本（链式调用）
    @discardableResult
    func text(_ content: String, attributes: [Attribute]?) -> Ticket {
        chunk(.text(content, attributes: attributes))
    }
    
    /// 追加默认横向分割线（链式调用）
    @discardableResult
    func splitter() -> Ticket {
        chunk(.splitter)
    }
    
    /// 追加自定义字符分割线（链式调用）
    @discardableResult
    func splitter(char: Character = "-", printDensity: Int = 384, fontDensity: Int = 12) -> Ticket {
        chunk(.splitter(char: char, printDensity: printDensity, fontDensity: fontDensity))
    }
    
    /// 追加双列左右两端对齐文本（链式调用）
    @discardableResult
    func twoColumn(_ left: String, _ right: String, totalWidth: Int = 32, wrap: Bool = false) -> Ticket {
        chunk(.twoColumn(left, right, totalWidth: totalWidth, wrap: wrap))
    }
    
    /// 追加三列对齐文本，支持超长文本智能换行（链式调用）
    @discardableResult
    func threeColumn(_ col1: String, _ col2: String, _ col3: String, totalWidth: Int = 32, wrap: Bool = false) -> Ticket {
        chunk(.threeColumn(col1, col2, col3, totalWidth: totalWidth, wrap: wrap))
    }
    
    /// 追加自定义多列排版（变长参数，链式调用）
    @discardableResult
    func row(totalWidth: Int = 32, _ columns: LineColumn...) -> Ticket {
        chunk(Chunk(Line(totalWidth: totalWidth, columns: columns)))
    }
    
    /// 追加自定义多列排版（数组形式，链式调用）
    @discardableResult
    func row(totalWidth: Int = 32, columns: [LineColumn]) -> Ticket {
        chunk(Chunk(Line(totalWidth: totalWidth, columns: columns)))
    }
    
    /// 追加 ESC/POS 原生硬件二维码（链式调用）
    @discardableResult
    func qrcode(_ content: String) -> Ticket {
        chunk(.qrcode(content))
    }
    
    /// 追加一维条形码（链式调用）
    @discardableResult
    func barcode(_ content: String, type: Commands.BarCodeType = .code128, height: UInt8 = 64, width: UInt8 = 2, hri: Commands.BarCodeHRIPosition = .below) -> Ticket {
        chunk(.barcode(content, type: type, height: height, width: width, hri: hri))
    }
    
    #if canImport(UIKit)
    /// 追加单色热敏位图，支持灰度与误差扩散抖动（链式调用）
    @discardableResult
    func image(_ image: UIImage, dither: ImageDitherStyle = .floydSteinberg) -> Ticket {
        chunk(.image(image, dither: dither))
    }
    #endif
    
    /// 设置小票行间距（链式调用）
    @discardableResult
    func lineSpacing(_ spacing: UInt8) -> Ticket {
        chunk(.lineSpacing(spacing))
    }
    
    /// 恢复默认行间距（链式调用）
    @discardableResult
    func defaultLineSpacing() -> Ticket {
        chunk(.defaultLineSpacing)
    }
    
    /// 触发蜂鸣器提醒（链式调用）
    @discardableResult
    func buzzer(times: UInt8 = 1) -> Ticket {
        chunk(.buzzer(times: times))
    }
    
    /// 进纸指定行数（链式调用）
    @discardableResult
    func feed(lines: UInt8 = 1) -> Ticket {
        chunk(.feed(lines: lines))
    }
    
    /// 空白占位块（链式调用）
    @discardableResult
    func blank() -> Ticket {
        chunk(.blank)
    }
    
    /// 钱箱脉冲弹出（链式调用）
    @discardableResult
    func openDrawer() -> Ticket {
        chunk(.openDrawer)
    }
    
    /// 执行全切纸动作（链式调用）
    @discardableResult
    func cut() -> Ticket {
        chunk(.cut)
    }
    
    /// 执行半切纸动作（链式调用）
    @discardableResult
    func partialCut() -> Ticket {
        chunk(.partialCut)
    }
    
    /// 执行走纸并切纸（链式调用）
    @discardableResult
    func feedAndCut() -> Ticket {
        chunk(.feedAndCut)
    }
    
    // MARK: - 动态条件与集合遍历链式方法
    
    /// 条件链式调用（满足 condition 时执行追加闭包）
    @discardableResult
    func when(_ condition: Bool, _ transform: (Ticket) -> Ticket) -> Ticket {
        condition ? transform(self) : self
    }
    
    /// 可选值解包链式调用（当 value != nil 时执行追加闭包）
    @discardableResult
    func whenLet<T>(_ optionalValue: T?, _ transform: (Ticket, T) -> Ticket) -> Ticket {
        if let value = optionalValue {
            return transform(self, value)
        }
        return self
    }
    
    /// 集合遍历链式调用（动态批量追加）
    @discardableResult
    func forEach<T>(_ elements: [T], _ transform: (Ticket, T) -> Ticket) -> Ticket {
        var current = self
        for item in elements {
            current = transform(current, item)
        }
        return current
    }
}
