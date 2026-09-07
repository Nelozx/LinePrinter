//
//  Blank.swift
//  LinePrinter
//
//  Created by Nelo on 2022/4/20.
//

import Foundation

/// 空白占位排版元素
public struct Blank: ChunkProvider {
    public init() {}
    public func data(using encoding: String.Encoding) -> Data {
        Data()
    }
}
