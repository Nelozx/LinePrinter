//
//  ReceiptPaperWidth.swift
//  LinePrinter
//
//  Created by Nelo on 2026/9/8.
//

import Foundation
import CoreGraphics

/// 小票纸张规格尺寸定义
public enum ReceiptPaperWidth: Equatable {
    /// 58mm 规格（标准点阵约 384 点，UI 预览基准宽度约 300pt，单行排版约 32 个半角字符）
    case mm58
    /// 80mm 规格（标准点阵约 576 点，UI 预览基准宽度约 380pt，单行排版约 48 个半角字符）
    case mm80
    /// 自定义点阵/点数宽度
    case custom(CGFloat)
    
    /// 预览视图对应的点数宽度
    public var points: CGFloat {
        switch self {
        case .mm58: return 300
        case .mm80: return 380
        case .custom(let w): return w
        }
    }
    
    /// 对应的字符排版总宽度（58mm 为 32 字符，80mm 为 48 字符）
    public var totalWidth: Int {
        switch self {
        case .mm58: return 32
        case .mm80: return 48
        case .custom(let w): return max(1, Int(w / 9.0))
        }
    }
    
    /// 打印机横向点阵密度（58mm 通常为 384 点，80mm 通常为 576 点）
    public var printDensity: Int {
        switch self {
        case .mm58: return 384
        case .mm80: return 576
        case .custom(let w): return max(1, Int(w * 1.28))
        }
    }
    
    /// 纸张规格标题
    public var title: String {
        switch self {
        case .mm58: return "58mm 纸宽"
        case .mm80: return "80mm 纸宽"
        case .custom(let w): return "自定义 (\(Int(w))pt)"
        }
    }
}
