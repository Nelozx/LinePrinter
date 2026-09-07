//
//  Commands.swift
//
//  Created by Nelo on 2022/3/30.
//  ref: https://www.starmicronics.com/support/Mannualfolder/com-emu_escpos_cm_en.pdf

import Foundation

/// ESC/POS Commands
public struct Commands: RawRepresentable {
    
    /// 单个指令别名
    public typealias Command = Commands
    
    /// 指令集
    public typealias RawValue = [UInt8]
    
    public let rawValue: [UInt8]
    
    public init(rawValue: [UInt8]) {
        self.rawValue = rawValue
    }
    
    init(_ rawValue: [UInt8]) {
        self.rawValue = rawValue
    }
}

// MARK: - Horizontal Direction Position
extension Commands {
    /// 横向跳格
    /// - **ASCII**: [HT]
    /// > 将打印位置移动到下一个水平制表符位置。
    static let horizontalTab = Commands([9])
    
    /// 指定绝对位置
    /// - **ASCII**: [ESC $ nL nH]
    /// - 0 ≤ nL ≤ 255
    /// - 0 ≤ nH ≤ 255
    /// >
    /// - 使用基于左页边距位置的绝对位置指定下一个打印开始位置
    /// - 下一个打印起始位置是[(nL+nH×256) ×基本计算间距]指定的从左边距位置开始的位置
    /// - 当此命令用于指定除左边距位置以外的任何内容时，行首不存在。
    /// - 只有在指定了与左边距位置相同的位置时，才保持行的顶部。
    static func position(horizontal nL: UInt8, _ nH: UInt8) -> Self {
        Commands([27, 36, nL, nH])
    }

    /// 打印内容水平对齐方式
    public enum Alignment: UInt8 {
        /// 左对齐
        case left = 48
        /// 居中对齐
        case center = 49
        /// 右对齐
        case right = 50
    }

    /// 位置对齐
    /// - **ASCII**: [ESC a n]
    /// - 0 ≤ n ≤ 2, 48 ≤ n ≤ 50
    /// > 将一行中的所有打印数据对齐到指定位置
    static func alignment(_ n: Alignment = .left) -> Self {
        Commands([27, 97, n.rawValue])
    }
    
    /// 设置左边边距
    /// - **ASCII**: [GS L nL nH]
    /// - 0 ≤ nL ≤ 255 0 ≤ nH ≤ 255
    /// > nL和nH设置指定的左距
    /// 左距为[(nL + nH x 256) x基本计算间距]
    static func leftMargin(_ nL: UInt8 = 0, _ nH: UInt8 = 0) -> Self {
        Commands([29, 76, nL, nH])
    }
}

// MARK: - Page Mode
extension Commands {
    /// 指定页面模式中字符垂直方向的绝对位置
    /// - **ASCII**: [GS $ nL nH]
    /// - 0 ≤ nL ≤ 255, 0 ≤ nH ≤ 255
    /// >
    /// - 使用基于页面模式中起始点的绝对位置，指定数据扩展起始位置的字符垂直方向位置。
    /// - 下一个数据扩展起始位置的字符垂直方向的位置是从起始点开始[（nL+nH x 256）x基本计算间距]指定的位置
    static func position(vertical nL: UInt8, _ nH: UInt8) -> Self {
        Commands([29, 36, nL, nH])
    }
    
}

// MARK: - Character Expansion, Print Modes
extension Commands {
    /// 批量指定打印模式
    /// - **ASCII**: [ESC ! n]
    /// * 0 ≤ n ≤ 255 默认 0
    /// >
    /// * 当倍宽和倍高模式同时选择时，字符同时在横向和纵向放大两倍。
    /// * 除了 HT 设置的空格和旋转打印的字符，其余任何字符都可以加下划线。
    /// * 下划线度由 ESC -确定，与字符无关。
    /// * 当一行中部分字符为倍高或更高，所有字符以底端对齐。
    static func batchPrint(modes n: UInt8 = 0) -> Commands {
        Commands([27, 33, n])
    }
    
    /// 字符的大小
    /// - **ASCII**: [GS ! n]
    static func size(_ n: UInt8) -> Self {
        Commands([29, 33, n])
    }
    
    /// 指定/取消黑/白 反向的打印
    /// - **ASCII**: [GS B n]
    /// - 0 ≤ n ≤ 255
    ///     - 当 n 的最低位为 0 时，取消反向打印
    ///     - 当 n 的最低位为 1 时，选择反显打印
    static func reverse(_ n: UInt8) -> Self {
        Commands([29, 66, n])
    }
    
    /// 指定/取消平滑
    /// - **ASCII**: [GS b n]
    /// - 0 ≤ n ≤ 255
    ///     - 当 n 的最低位为 0 时，取消平滑打印
    ///     - 当 n 的最低位为 1 时，选择平滑打印
    static func smooth(_ n: UInt8) -> Self {
        Commands([29, 98, n])
    }
}

// MARK: - Line spacing
extension Commands {
    /// 打印并向前走纸n行
    /// - **ASCII**: [ESC d n]
    /// * 0 ≤ n ≤ 255
    ///
    /// >  该指令将打印机的打印起始位置设置在行首
    static func printAndFeed(lines: UInt8 = 1) -> Commands {
        Commands([27, 100, lines])
    }
    /// 打印和送纸
    /// - **ASCII**: [ESC J n]
    /// - 0 ≤ n ≤ 255
    /// > 在打印缓冲区中打印数据，并向纸张进纸[n x 基本计算间距]
    static func printAndFeed(n: UInt8) -> Self {
        Commands([27, 74, n])
    }
    
    /// 换行
    /// - **ASCII**: [LF]
    ///
    /// > 打印缓冲区中的数据，并根据设置的换行量执行换行操作。
    static var lineFeed: Self {
        Commands([10])
    }
    
    /// 恢复默认行间距（约 1/6 英寸，通常为 30-33 点阵）
    /// - **ASCII**: [ESC 2]
    public static let defaultLineSpacing = Commands([27, 50])
    
    /// 设置自定义行间距
    /// - **ASCII**: [ESC 3 n]
    /// - Parameter points: 垂直点阵数（0 ≤ points ≤ 255）
    public static func lineSpacing(_ points: UInt8) -> Self {
        Commands([27, 51, points])
    }
}

// MARK: - Drawer-Kick Connector Control
extension Commands {
    /// 开钱箱连接线控制
    /// - **ASCII**: [ESC p m t1 t2]
    /// - 定义区域
    ///   * 0 ≤ m ≤ 1, 48 ≤ m ≤ 49
    ///   * 0 ≤ t1 ≤ 255
    ///   * 0 ≤ t2 ≤ 255
    /// > 这会将t1和t2指定的信号输出到m指定的连接器引脚。
    /// - **ASCII**: [ESC p m t1 t2]
    /// - Parameters:
    ///   - m: 连接器管脚 48: connector pin #2, 49: connector pin #5
    ///   - t1: 开钱箱开机时间设置为t1 × 2 ms
    ///   - t2: 开钱箱关机时间设置为t2 × 2 ms
    static func drawerKick(m: UInt8, t1: UInt8, t2: UInt8) -> Self {
        Commands([27, 112, m, t1, t2])
    }
}

// MARK: - Font Style and Character Set
extension Commands {
    /// 字符内置点阵字型
    public enum Font: UInt8 {
        /// Font A: 标准字体（通常为 12x24 点阵）
        case a = 48
        /// Font B: 压缩字体（通常为 9x17 点阵）
        case b = 49
    }
    
    /// 字符字体
    /// - **ASCII**: [ESC M n]
    static func font(_ n: Font) -> Self {
        Commands([27, 77, n.rawValue])
    }
    
    /// 设置字符右空格量
    /// - **ASCII**: [ESC SP n]
    /// 0 ≤n ≤255
    static func space(_ n: UInt8 = 0) -> Self {
        Commands([27, 32, n])
    }
    
    /// 设置字符颜色
    /// - **ASCII**: [ESC r n]
    static func color(_ n: UInt8) -> Self {
        Commands([27, 114, n])
    }
    
    /// 国际字符集代码
    public enum Country: UInt8 {
        case America = 0
        case France =  1
        case Germany = 2
        case UK = 3
        case DenmarkI = 4
        case Sweden = 5
        case Italy = 6
        case SpainI = 7
        case Japan = 8
        case Norway = 9
        case DenmarkII = 10
        case SpainII = 11
        case LatinAmerica = 12
        case Korea = 13
    }
    
    
    ///  国际字符
    /// - **ASCII**: [ESC R n]
    /// - 0 ≤n ≤13
    /// > 选择上面列出的国家的字符集
    static func international(_ n: Country = .America) -> Self {
        Commands([27, 82, n.rawValue])
    }
    
    /// 字符代码页 (Code Page)
    public enum CodePage: UInt8 {
        case pc437 = 0      // USA: Standard Europe
        case katakana = 1   // Katakana
        case pc850 = 2      // Multilingual
        case pc860 = 3      // Portuguese
        case pc863 = 4      // Canadian-French
        case pc865 = 5      // Nordic
        case wpc1252 = 16   // Latin 1
        case pc866 = 17     // Cyrillic #2
        case pc852 = 18     // Latin 2
        case pc858 = 19     // Euro
        case thai42 = 20    // Thai character code 42
        case thai11 = 21    // Thai character code 11
        case thai13 = 22    // Thai character code 13
        case thai14 = 23    // Thai character code 14
        case thai16 = 24    // Thai character code 16
        case thai17 = 25    // Thai character code 17
        case thai18 = 26    // Thai character code 18
        case cp936 = 255    // Simplified Chinese
    }
    
    /// 选择字符代码页 (Code Page)
    /// - **ASCII**: [ESC t n]
    /// - 0 ≤ n ≤ 255
    /// > 选择上面列出的代码页，用于打印不同语种的特殊字符
    static func characterCodePage(_ n: CodePage = .pc437) -> Self {
        Commands([27, 116, n.rawValue])
    }
}

// MARK: - Character Expansion, Print Modes
extension Commands {
    /// 指定/取消下划线模式
    /// - **ASCII**: [ESC – n]
    /// - 48: 取消下划线
    /// - 49: 设置为单点宽度下划线并指定下划线
    /// - 50: 设置为双点宽度下划线并指定下划线
    static func underline(_ n: UInt8) -> Self {
        Commands([27, 45, n])
    }
    
    /// 指定/取消双重打印
    /// - **ASCII**: [ESC G n]
    /// - 本打印机无法进行双重打印，因此打印与emphasize使用相同
    static func doublePrinting(_ n: UInt8 = 0) -> Self {
        Commands([27, 71, n])
    }
    
    /// 指定/取消 强调（加粗）
    /// - **ASCII**: [ESC E n]
    /// - 0 取消加粗，1 开启加粗
    static func emphasize(_ n: UInt8 = 0) -> Self {
        Commands([27, 69, n])
    }
    
    /// 指定/取消字符90度顺时针
    /// - **ASCII**: [ESC V n]
    /// - 0 ≤ n ≤ 1, 48 ≤ n ≤ 49
    /// - 48 取消顺时针旋转90度
    /// - 49 顺时针旋转90度
    static func rotate(_ n: UInt8 = 48) -> Self {
        Commands([27, 86, n])
    }
    
    /// 指定/取消颠倒打印
    /// - **ASCII**: [ESC { n]
    /// - 0 ≤ n ≤ 255
    ///     - 当 n 的最低位为 0 时，取消颠倒
    ///     - 当 n 的最低位为 1 时，选择颠倒
    /// >
    /// - 倒置打印时打印的字符是颠倒的，但打印行的顺序不是颠倒的
    static func upsideDown(_ n: UInt8 = 0) -> Self {
        Commands([27, 123, n])
    }
}

// MARK: - Other
extension Commands {
    /// 初始化打印机
    /// - **ASCII**: [ESC @]
    /// > 从打印缓冲区清除数据，并将打印机设置为其默认设置
    static let initialize = Commands([27, 64])
}

// MARK: - Bit Image Graphics
extension Commands {
    /// 光栅位图倍率放大模式
    public enum ImageMode: UInt8 {
        /// 正常模式（1倍宽、1倍高）
        case normal = 48
        /// 倍宽模式
        case doubleWidth = 49
        /// 倍高模式
        case doubleHeight = 50
        /// 4倍大小（倍宽且倍高）
        case doubleSize = 51
    }

    
    
    /// 打印光栅位图
    /// - **ASCII**: [GS v 0 m xL xH yL yH d1 ... dk]
    /// - 定义区域
    ///     * 0 ≤ m ≤ 3, 48 ≤ m ≤ 51
    ///     * 0≤xL≤128,xH=0 (0≤xL+xH×256) ≤128) 0≤yL≤255,0≤yH≤15
    ///     * (0≤yL+yH×256 ≤4095) 0 ≤ d ≤ 255
    ///     * k = (xL+xH×256) × (yL+yH×256) However, k ≠ 0
    /// - Parameters:
    ///   - m: 使用模式m打印光栅方法位图像。
    ///   - xl: 和xH指定1位图像(xL + xH x 256)的水平方向数据计数，以字节为单位
    ///   - yH: yH表示1比特图像(yL + yH x 256)的垂直方向数据计数，单位为点。
    /// >
    /// - 在星型打印机上，使用并行接口时的ACK脉冲宽度固定为1μs
    /// - 在页面模式下，禁止传输此命令。如果发送，打印结果不保证
    /// - 星形打印机上的点密度（当星形打印头=203 DPI）
    static func printRasterBitImages(m: ImageMode = .normal,
                                     xl: UInt8, xH: UInt8,
                                     yl: UInt8, yH: UInt8) -> Self {
        Commands([29, 118, 48, m.rawValue, xl, xH, yl, yH])
    }
}

// MARK: - Cutter Control
extension Commands {
    
    /// 切纸
    /// - **ASCII**: [GS V m]
    /// - 定义区域
    ///     * m = 0, 1, 48, 49
    /// - Parameters:
    ///   - m: 0,48 全切, 1,49 部分切割(不切割一点)
    static func cutPaper(m: UInt8) -> Self {
        Commands([29, 86, m])
    }
    
    /// 进纸指定点数并切纸（硬件级平滑协同）
    /// - **ASCII**: [GS V m n]
    /// - Parameters:
    ///   - partial: 是否为半切（true: 半切保留连接点，false: 全切）
    ///   - feedPoints: 切割前走纸点阵数（0~255）
    public static func feedAndCutPaper(partial: Bool = false, feedPoints: UInt8 = 0) -> Self {
        Commands([29, 86, partial ? 66 : 65, feedPoints])
    }
}

// MARK: - Chinese Characters
extension Commands {
    
    /// 指定汉字模式
    /// - **ASCII**: [FS &]
    static let kanjiMode = Commands([28, 38])
    
    /// 取消汉字模式
    /// - **ASCII**: [FS .]
    public static let cancelKanjiMode = Commands([28, 46])
    
    /// 汉字下划线模式
    /// - **ASCII**: [FS - n]
    /// - Parameter n: 0 取消下划线，1 设置 1 点宽下划线，2 设置 2 点宽下划线
    public static func kanjiUnderline(_ n: UInt8 = 0) -> Self {
        Commands([28, 45, n])
    }
}

// MARK: - QR Code
extension Commands {

    /// 选择 QR 码的编码纠错等级
    /// 51 50 49 48
    static func QRCodeRecoveryLevel() -> Self {
        //
        Commands([29, 40, 107, 3, 0, 49, 69, 48])
    }
    
    /// 二维码大小
    static func QRCodeSize(point: UInt8 = 8) -> Self {
        Commands([29, 40, 107, 3, 0, 49, 67, point])
    }
    
    /// 将数据存储在符号存储区中（按二进制字节数计算真实长度）
    /// 存入 QR 二维码数据（d1...dk）
    /// - Parameter byteCount: 编码后的真实二进制字节长度
    static func QRGetReadyToStore(byteCount: Int) -> Self {
        let s  = byteCount + 3
        let pl = s % 256
        let ph = s / 256
        return Commands([29, 40, 107, UInt8(pl), UInt8(ph), 49, 80, 48])
    }
    
    /// 将数据存储在符号存储区中（按字符串与其编码计算字节长度）
    static func QRGetReadyToStore(text: String, encoding: String.Encoding = .utf8) -> Self {
        let count = text.data(using: encoding)?.count ?? text.utf8.count
        return QRGetReadyToStore(byteCount: count)
    }
    
    /// 打印二维码
    static func QRCodePrint() -> Commands {
        return Commands([29, 40, 107, 3, 0, 49, 81, 48])
    }
    
    
}

// MARK: - Bar Codes
extension Commands {
    
    /// 一维条形码编码制式
    public enum BarCodeType: UInt8 {
        /// UPC-A 条码（11-12 位数字）
        case upcA = 65
        /// UPC-E 条码（6-12 位数字）
        case upcE = 66
        /// JAN13 / EAN13 条码（12-13 位数字）
        case jan13 = 67
        /// JAN8 / EAN8 条码（7-8 位数字）
        case jan8 = 68
        /// CODE39 条码（数字、大写英文字母及特定符号）
        case code39 = 69
        /// ITF 交叉二五码（偶数位数字）
        case itf = 70
        /// CODABAR 条码
        case codabar = 71
        /// CODE93 条码
        case code93 = 72
        /// CODE128 条码（全 ASCII 字符集）
        case code128 = 73
    }
    /// 打印条码
    /// - **ASCII**: [G S k m d1...dk NUL] / [GS k m n d1...dk]
    /// > * 如果条码数据 d 超出了规定的范围，该命令无效。
    /// > * 如果条码横向超出了打印区域，无效。
    /// > * 这条命令不管由 ESC 2 或 ESC 3 命令设置的行高是多少，走纸距离都与设 定的条码高度相等
    static func printBarCode(_ m: BarCodeType, n: UInt8) -> Self {
        Commands([29, 107,  m.rawValue, n])
    }
    
    /// 设置bar code的宽度
    /// - **ASCII**: [GS w n]
    /// - 1 ≤ n ≤ 6
    static func barCode(width: UInt8 = 3) -> Self {
        Commands([29, 119, width])
    }
    
    /// 设置bar code的高度
    /// - **ASCII**: [GS h n]
    /// - 1 ≤ n ≤ 255
    static func barCode(height: UInt8 = 162) -> Self {
        Commands([29, 104, height])
    }
    
    /// 条形码可读字符（HRI）打印位置
    public enum BarCodeHRIPosition: UInt8 {
        /// 不打印可读文字
        case none = 0
        /// 打印在条码上方
        case above = 1
        /// 打印在条码下方（工业标准与常用）
        case below = 2
        /// 打印在条码上方与下方
        case both = 3
    }
    
    /// 设置条形码 HRI 字符打印位置
    /// - **ASCII**: [GS H n]
    public static func barCodeHRI(_ position: BarCodeHRIPosition = .below) -> Self {
        Commands([29, 72, position.rawValue])
    }
    
    /// 设置条形码 HRI 字符字型
    /// - **ASCII**: [GS f n]
    /// - Parameter font: 字型（Font A 标准，Font B 压缩）
    public static func barCodeHRIFont(_ font: Font = .a) -> Self {
        Commands([29, 102, font == .a ? 0 : 1])
    }
}


public extension Data {
    
    /// 将一系列 `Commands` 拼接并初始化为二进制 `Data`
    /// - Parameter cmds: ESC/POS 命令列表
    init(escpos cmds: Commands...) {
        self.init(cmds.reduce([], { $0 + $1.rawValue }))
    }
    /// 开钱箱指令数据
    static let drawer = Data(escpos: .drawerKick(m: 48, t1: 10, t2: 10))
    static var openDrawer: Data { drawer }
    
    /// 结束输出
    static let endOutput = Data(escpos: Commands([250]))
    
    /// 全切纸指令数据
    static var cut: Data {
        Data(escpos:
             .printAndFeed(n: 240),
             .cutPaper(m: 48))
    }
    
    /// 半切纸指令数据
    static let partialCut = Data(escpos: .cutPaper(m: 49))
    
    /// 开启钱箱脉冲（通用）
    static var cash: Data {
        Data(escpos: .drawerKick(m: 48, t1: 10, t2: 255))
    }
    
    /// 进纸一行指令数据
    static let formfeed = Data(escpos: .printAndFeed())
    
    /// 钱箱电平脉冲
    static var pulse: Data {
        Data(escpos: .drawerKick(m: 48, t1: 2, t2: 2))
    }
    
    /// 水平移动
    static func move(x: Int) -> Data {
        Data(escpos: .position(horizontal: UInt8(x % 256), UInt8(x / 256)))
    }
    
    /// 垂直移动
    static func move(y: Int) -> Data {
        Data(escpos: .position(vertical: UInt8(y % 256), UInt8(y / 256)))
    }
    
    /// 走纸并切纸组合指令数据
    static let feedAndCut = formfeed + cut
}

// MARK: - Buzzer / Sound
extension Commands {
    /// 打印机蜂鸣器发声提醒（餐饮外卖出单、后厨催单提醒）
    /// - **ASCII**: [ESC B n t]
    /// - Parameters:
    ///   - times: 蜂鸣次数（1 ≤ n ≤ 9，默认 1）
    ///   - duration: 每次蜂鸣时长系数（duration × 50ms，默认 2 即 100ms）
    public static func buzzer(times: UInt8 = 1, duration: UInt8 = 2) -> Self {
        Commands([27, 66, max(1, min(9, times)), duration])
    }
}

// MARK: - Label / Black Mark
extension Commands {
    /// 标签纸/黑标纸进纸定位至切纸口（用于带黑标或间隙不干胶小票纸）
    /// - **ASCII**: [GS FF]
    public static let feedToBlackMark = Commands([29, 12])
}

// MARK: - Status Checking
extension Commands {
    /// 实时状态请求类型（DLE EOT n）
    public enum RealtimeStatusType: UInt8 {
        /// 打印机状态（联机/脱机、等待恢复等）
        case printerStatus = 1
        /// 脱机原因状态（机盖开启、缺纸脱机等）
        case offlineStatus = 2
        /// 错误原因状态（切刀卡纸、可恢复/不可恢复错误）
        case errorStatus = 3
        /// 卷纸传感器状态（即将用尽、纸已空）
        case paperSensorStatus = 4
    }
    
    /// 实时状态传输指令（DLE EOT n）
    ///
    /// 向打印机发送实时请求，打印机会在硬件底层即刻返回 1 字节状态码，即使在缓冲区满或发生错误时也会立即响应。
    /// - Parameter n: 状态请求类型
    /// - Returns: ESC/POS 状态查询指令
    public static func realtimeStatus(_ n: RealtimeStatusType) -> Self {
        Commands([16, 4, n.rawValue])
    }
    
    /// 开启或关闭自动状态返回（Auto Status Back, ASB）
    /// - Parameter enable: 是否启用自动状态回传
    /// - Returns: ESC/POS ASB 配置指令
    public static func enableAutoStatusBack(enable: Bool = true) -> Self {
        Commands([29, 97, enable ? 255 : 0])
    }
}

public extension Data {
    /// 查询打印机实时纸张状态的二进制指令（发送至打印机，其将返回 1 字节状态供 `PrinterHardwareStatus.parse(byte:)` 解析）
    static let checkPaperStatus = Data(escpos: .realtimeStatus(.paperSensorStatus))
    
    /// 查询打印机实时开盖/脱机状态的二进制指令（发送至打印机，其将返回 1 字节状态供 `PrinterHardwareStatus.parse(byte:)` 解析）
    static let checkCoverStatus = Data(escpos: .realtimeStatus(.offlineStatus))
    
    /// 蜂鸣器发声提示二进制数据
    static func buzzer(times: UInt8 = 1, duration: UInt8 = 2) -> Data {
        Data(escpos: .buzzer(times: times, duration: duration))
    }
    
    /// 恢复默认行间距二进制指令
    static let defaultSpacing = Data(escpos: .defaultLineSpacing)
    static var defaultLineSpacing: Data { defaultSpacing }
    
    /// 设置行间距二进制指令
    static func spacing(_ points: UInt8) -> Data {
        Data(escpos: .lineSpacing(points))
    }
    static func lineSpacing(_ points: UInt8) -> Data { spacing(points) }
    
    /// 走纸定位至黑标/标签切缝二进制指令
    static let blackMark = Data(escpos: .feedToBlackMark)
    static var feedToBlackMark: Data { blackMark }
}


