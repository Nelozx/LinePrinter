//
//  BarCode.swift
//  LineThermalPrinter
//
//  Created by Nelo on 2022/4/11.
//

import Foundation

/// 条形码打印排版元素
public struct BarCode: ChunkProvider {
    
    /// 条码细线条宽度倍率（1~6）
    public let width: UInt8
    /// 条码垂直高度点阵数
    public let height: UInt8
    /// 条码文本字符串
    public let code: String
    /// 条码类型（如 Code128, EAN13 等）
    public let type: Commands.BarCodeType
    /// HRI 人类可读字符位置（上方、下方、不打印）
    public let hri: Commands.BarCodeHRIPosition
    
    /// 初始化条形码元素
    public init(_ code: String, type: Commands.BarCodeType,
                height: UInt8 = 64, width: UInt8 = 2,
                hri: Commands.BarCodeHRIPosition = .below) {
        self.code = code
        self.height = height
        self.width = width
        self.type = type
        self.hri = hri
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        var playload = Data()
        playload =  Data(escpos: .barCode(height: height),
                         .barCode(width: width),
                         .barCodeHRI(hri)
        )
        if let code = code.data(using: encoding) {
            playload += Data(escpos:
                    .printBarCode(type, n: UInt8(code.count)))
            playload += code
        }
    
        return playload
    }
}

