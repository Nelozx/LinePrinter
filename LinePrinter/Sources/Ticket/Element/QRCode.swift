//
//  QRCode.swift
//  LineThermalPrinter
//
//  Created by Nelo on 2022/4/11.
//

import Foundation

/// 二维码打印排版元素
public struct QRCode: Printable {
    
    /// 二维码文本或链接内容
    public let content: String
    
    /// 初始化二维码元素
    /// - Parameter content: 二维码文本或 URL
    public init(_ content: String) {
        self.content = content
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        var playload = Data()
        let contentData = content.data(using: encoding) ?? Data(content.utf8)
        
        playload += Data(escpos: .QRCodeSize(),
                         .QRCodeRecoveryLevel(),
                         .QRGetReadyToStore(byteCount: contentData.count))
        
        playload += contentData
        playload += Data(escpos: .QRCodePrint())
        return playload
    }
    
}
