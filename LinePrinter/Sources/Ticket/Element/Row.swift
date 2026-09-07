//
//  Row.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation

/// 小票多列排版中的单列配置项
///
/// 定义了一列的文本内容、宽度/权重分配方式、对齐方式以及是否开启超长折行。
///
/// ```swift
/// Col("招牌老坛酸菜鱼", weight: 2, alignment: .left, wrap: true)
/// Col("38.00", weight: 1, alignment: .right)
/// ```
public struct Col {
    /// 该列显示的文本内容
    public let text: String
    
    /// 该列的固定字符宽度（若设置则优先于权重生效；若为 nil 则使用权重 weight 自适应分配）
    public let width: Int?
    
    /// 该列在自适应分配中所占的权重比例（默认 1，必须 ≥ 1）
    public let weight: Int
    
    /// 该列文本的对齐方式（`.left` 居左, `.center` 居中, `.right` 居右）
    public let alignment: Commands.Alignment
    
    /// 当文本显示宽度超过该列分配的宽度时，是否自动智能折行排版（保持其他列垂直精准对齐）
    public let isWrapEnabled: Bool
    
    /// 创建单列配置
    /// - Parameters:
    ///   - text: 列文本
    ///   - width: 固定字符宽度（可选）
    ///   - weight: 权重比例，默认为 1
    ///   - alignment: 对齐方式，默认为居左 `.left`
    ///   - wrap: 超长文本是否自动折行，默认为 `false`
    public init(
        _ text: String,
        width: Int? = nil,
        weight: Int = 1,
        alignment: Commands.Alignment = .left,
        wrap: Bool = false
    ) {
        self.text = text
        self.width = width
        self.weight = max(1, weight)
        self.alignment = alignment
        self.isWrapEnabled = wrap
    }
}

/// 列别名
public typealias Column = Col
public typealias Line = Col

/// 多列排版行组件（属于 Element 排版元素）
///
/// 精确测算中英文全半角宽度，支持自适应权重比例分配，保持小票各列竖向垂直对齐。
public struct Row: Printable {
    
    /// 整行总字符宽度（58mm 纸宽通常为 32，80mm 纸宽通常为 48，默认为 32）
    public var totalWidth: Int
    
    /// 包含的列配置列表
    public private(set) var columns: [Col]
    
    /// 初始化多列排版行（数组形式）
    public init(totalWidth: Int = 32, columns: [Col]) {
        self.totalWidth = totalWidth
        self.columns = columns
    }
    
    /// 初始化多列排版行（变长参数形式）
    public init(totalWidth: Int = 32, _ columns: Col...) {
        self.totalWidth = totalWidth
        self.columns = columns
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        guard !columns.isEmpty else { return Data() }
        let widths = computeColumnWidths()
        let needsWrap = zip(columns, widths).contains { col, width in
            col.isWrapEnabled && col.text.printDisplayWidth > width
        }
        
        if needsWrap {
            return formatWrappedLines(calculatedWidths: widths, encoding: encoding)
        } else {
            let line = zip(columns, widths).map { col, width in
                formatColumn(text: col.text, targetWidth: width, alignment: col.alignment)
            }.joined()
            return line.data(using: encoding) ?? Data()
        }
    }
    
    /// 智能折行排版
    private func formatWrappedLines(calculatedWidths: [Int], encoding: String.Encoding) -> Data {
        var columnLines = [[String]]()
        var maxLines = 1
        
        for (col, width) in zip(columns, calculatedWidths) {
            if col.isWrapEnabled {
                let segments = splitTextToLines(col.text, maxWidth: width)
                let padded = segments.map { formatColumn(text: $0, targetWidth: width, alignment: col.alignment) }
                columnLines.append(padded)
                maxLines = max(maxLines, padded.count)
            } else {
                columnLines.append([formatColumn(text: col.text, targetWidth: width, alignment: col.alignment)])
            }
        }
        
        let formattedLines = (0..<maxLines).map { lineIndex in
            zip(columnLines, calculatedWidths).map { lines, width in
                lineIndex < lines.count ? lines[lineIndex] : String(repeating: " ", count: width)
            }.joined()
        }
        
        return formattedLines.joined(separator: "\n").data(using: encoding) ?? Data()
    }
    
    /// 将文本拆分为多行
    private func splitTextToLines(_ text: String, maxWidth: Int) -> [String] {
        guard maxWidth > 0 else { return [text] }
        var result = [String]()
        var current = ""
        var currentW = 0
        
        for char in text {
            let charW = char.printWidth
            if currentW + charW <= maxWidth {
                current.append(char)
                currentW += charW
            } else {
                if !current.isEmpty {
                    result.append(current)
                }
                current = String(char)
                currentW = charW
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result.isEmpty ? [""] : result
    }
    
    /// 计算每列的最终宽度
    private func computeColumnWidths() -> [Int] {
        var widths = Array(repeating: 0, count: columns.count)
        var remainingWidth = totalWidth
        var totalWeight = 0
        var flexibleIndices = [Int]()
        
        for (index, col) in columns.enumerated() {
            if let fixedWidth = col.width {
                let actual = min(fixedWidth, remainingWidth)
                widths[index] = actual
                remainingWidth -= actual
            } else {
                flexibleIndices.append(index)
                totalWeight += col.weight
            }
        }
        
        if !flexibleIndices.isEmpty && remainingWidth > 0 && totalWeight > 0 {
            var allocated = 0
            for (idx, flexIdx) in flexibleIndices.enumerated() {
                if idx == flexibleIndices.count - 1 {
                    widths[flexIdx] = max(1, remainingWidth - allocated)
                } else {
                    let w = max(1, (remainingWidth * columns[flexIdx].weight) / totalWeight)
                    widths[flexIdx] = w
                    allocated += w
                }
            }
        }
        
        return widths
    }
    
    /// 截断或对齐列文本
    private func formatColumn(text: String, targetWidth: Int, alignment: Commands.Alignment) -> String {
        let currentWidth = text.printDisplayWidth
        if currentWidth == targetWidth {
            return text
        } else if currentWidth < targetWidth {
            return text.padToPrintWidth(targetWidth, alignment: alignment)
        } else {
            var truncated = ""
            var currentW = 0
            for char in text {
                let charW = char.printWidth
                if currentW + charW <= targetWidth {
                    truncated.append(char)
                    currentW += charW
                } else {
                    break
                }
            }
            if currentW < targetWidth {
                truncated.append(String(repeating: " ", count: targetWidth - currentW))
            }
            return truncated
        }
    }
}
