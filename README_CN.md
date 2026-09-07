# LinePrinter

<p align="right">
  <b>简体中文</b> | <a href="README.md">English</a>
</p>

[![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg?style=flat)](https://swift.org)
[![Platform iOS](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg?style=flat)](https://developer.apple.com/ios/)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-v0.3.0-blue.svg?style=flat)](https://cocoapods.org)
[![License MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](https://github.com/Nelozx/LinePrinter/blob/main/LICENSE)

`LinePrinter` 是一个专为 iOS 设计的 **纯原生、零依赖、无侵入的 ESC/POS 热敏小票声明式排版与高保真预览引擎**。适用于餐饮结账、外卖出单、零售收银、商超购物单与仓储标签等全行业业务场景。

本库的核心职责是**专注于小票声明式排版、标准 ESC/POS 二进制指令流（`Data`）生成与真实外观视觉预览**。库内不强行绑定蓝牙或网络通信连接，彻底避免与您项目原有的蓝牙管理器（`CBCentralManager`）、网络连接池或一体机商用硬件 SDK（如商米、联迪、拉卡拉等）发生冲突，也**无需在 `Info.plist` 中声明任何蓝牙或局域网敏感权限**。

---

## 📸 效果演示 (Screenshots)

<p align="center">
  <img src="Screenshots/demo.png" width="280" alt="Demo App 交互演示" style="margin-right: 16px; border-radius: 8px;" />
  <img src="Screenshots/receipt_58mm.png" width="260" alt="58mm 餐饮多列折行小票" style="margin-right: 16px; border-radius: 8px;" />
  <img src="Screenshots/receipt_80mm.png" width="280" alt="80mm 超市购物小票" style="border-radius: 8px;" />
</p>

| **📱 真实物理出纸仿真与交互** | **🧾 58mm 餐饮多列智能折行小票** | **🏬 80mm 超市购物宽幅小票** |
| :---: | :---: | :---: |
| 仿打印机出纸口物理吐纸、触觉震动反馈 | 智能三列权重分配、超长菜品名自动折行 | 48 字符宽幅对齐、Code128 工业条码渲染 |

---

## ✨ 核心特性

- 🎯 **纯排版引擎与通信彻底解耦**：
  - 直接生成标准连续的 ESC/POS 二进制指令流（`ticket.bytes(using: .gbk) -> Data`）；
  - 提供极简通道协议 `PrinterTransport`（`ticket.print(to: transport)`），任意外部通信对象均可实现即插即用。
- 🛡️ **纯原生、零依赖、零敏感权限**：仅依赖基础 `UIKit`，不包含任何第三方库，宿主 App 无需声明任何额外的硬件网络权限。
- 👁️ **商业级高保真视觉预览 (`TicketPreview`)**：
  - 一比一真实还原热敏纸质感：顶部微倒角切口、底部真实撕纸微锯齿（Serrated Edge）与阴影；
  - 一行代码生成 UI 预览视图（`ticket.previewView()`）或导出 2x Retina 高清长图（`ticket.previewImage()`）。
- 📊 **智能多列对齐与超长折行**：精确测算全角中文与半角英数显示宽度，支持多列权重分配；内置**超长菜品名智能自动换行（`wrap: true`）**，数量和金额列始终保持垂直对齐。
- 🖼️ **工业级点阵位图算法**：直接扩展 `UIImage.rasterEscPosData`，内置 **灰度阈值** 与 **Floyd-Steinberg 误差扩散抖动** 算法，单色热敏纸也能清晰呈现 Logo 与照片层次。
- 🇨🇳 **中文防乱码支持**：深度适配 GB18030 / GBK 汉字编码。
- 🔍 **硬件状态字节解析**：内置 `PrinterHardwareStatus.parse(byte:)`，无论外部通过蓝牙 Notify 还是 Socket 收到单字节状态回传，即可实时解析**缺纸、开盖、脱机**等异常。
- 📱 **声明式 DSL 排版语法**：结构清晰如 SwiftUI，开箱即用。

---

## 📦 安装方式

### Swift Package Manager (推荐)

在 Xcode 中选择 `File` -> `Add Packages...`，输入仓库地址：

```
https://github.com/Nelozx/LinePrinter.git
```

### CocoaPods

在 `Podfile` 中直接通过 GitHub 仓库引入：

```ruby
# 方式 A：指定发布的稳定 Tag 版本 (推荐)
pod 'LinePrinter', :git => 'https://github.com/Nelozx/LinePrinter.git', :tag => '0.3.0'

# 方式 B：直接追踪主分支最新代码
pod 'LinePrinter', :git => 'https://github.com/Nelozx/LinePrinter.git'
```

---

## 🚀 核心排版与直出方式

LinePrinter 崇尚极致的简洁与高效，去除了所有冗余复杂的抽象，仅保留最纯正的 **2 种排版构建方式**：

### 方式 1：变长参数链式直出（代码构建即发送）

无需繁琐数组包装，逗号自由隔开排版块，一气呵成直接输出到传输通道或硬件：

```swift
import LinePrinter

// 1. 链式通道直出（构建即发送到蓝牙/WiFi/硬件）
LinePrinter.ticket(
    .text("快速结账单", bold: true, alignment: .center),
    .splitter,
    .row(totalWidth: 32,
         Col("品名", weight: 2, alignment: .left),
         Col("数量", weight: 1, alignment: .center),
         Col("金额", weight: 1, alignment: .right)),
    .splitter("-"),
    .row("招牌老坛酸菜鱼", "x1", "38.00", wrap: true),
    .row("冰镇大麦若叶汁", "x2", "16.00", wrap: true),
    .splitter,
    .row("应收总计", "￥54.00"),
    .qrcode("https://weixin.qq.com/r/example_invoice"),
    .cut
).print(to: bluetoothTransport)

// 2. 亦可获取标准 ESC/POS 连续二进制字节流 Data 自行下发
let data = LinePrinter.ticket(
    .text("单号：NO.20260907001"),
    .row("实付金额", "￥20.00"),
    .cut
).bytes(using: .gbk)

// 自由下发给你的蓝牙外设或网络 Socket：
myPeripheral.writeValue(data, for: myCharacteristic, type: .withoutResponse)
```

---

### 方式 2：服务端动态驱动 JSON 排版（热更新免发版）

支持云端或后端微服务直接下发标准 JSON 模板，App 本地直接渲染成小票：

```swift
// 1. 从服务端下发的 JSON 字符串构建小票
let jsonString = """
{
  "autoInitialize": true,
  "autoCut": true,
  "chunks": [
    { "type": "text", "text": "云端动态结账单", "bold": true, "alignment": "center" },
    { "type": "splitter" },
    { "type": "twoColumn", "left": "应收金额", "right": "￥98.00" },
    { "type": "qrcode", "content": "https://lineprinter.dev" },
    { "type": "cut" }
  ]
}
"""

let ticket = try Ticket(json: jsonString)

// 2. 一行代码直接发送打印
ticket.print(to: bluetoothTransport)
```

---

### 3. 解耦传输通道协议 `PrinterTransport`

只需让你的蓝牙、TCP Socket 或硬件服务类遵循 `PrinterTransport`，即可无缝支持 `.print(to:)`：

```swift
class MyBluetoothTransport: PrinterTransport {
    func write(_ data: Data) {
        // 在此执行分包发送或写入外设特征值
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
}
```

---

### 3. UI 视觉排版预览与长图导出

无需物理连接打印机，即可在手机屏幕上直观预览逼真小票：

```swift
// 1. 获取小票预览视图并添加进 UI 容器
let previewView = ticket.previewView(paperWidth: .mm58)
myContainerView.addSubview(previewView)

// 2. 导出为高清长图 UIImage (便于保存相册或分享微信)
if let receiptImage = ticket.previewImage(paperWidth: .mm58) {
    UIImageWriteToSavedPhotosAlbum(receiptImage, nil, nil, nil)
}
```

---

### 4. 硬件状态解析（可选）

无论外部通过蓝牙特征值通知，还是 TCP Socket 收到打印机回传的状态字节，均可直接调用内置解析器：

```swift
let status = PrinterHardwareStatus.parse(byte: receivedByte)

if status.contains(.paperEmpty) {
    print("⚠️ 打印机缺纸！")
}
if status.contains(.coverOpen) {
    print("⚠️ 机盖已打开！")
}
if status.contains(.offline) {
    print("⚠️ 打印机脱机！")
}
```

---

## 🎨 常用 DSL 排版元素速查

| DSL 排版 API | 说明 |
|---|---|
| `.text("内容", bold: true, alignment: .center)` | 带样式的文本，支持居左/中/右对齐、加粗与样式自动复位 |
| `.splitter("-")` | 自适应行宽的分割线 |
| `.row("原价", "￥50")` | 快速双列两端对齐 |
| `.row("品名", "x1", "35.00", wrap: true)` | 快速三列对齐（支持超长菜品名自动折行） |
| `.row(totalWidth: 32, Col("品名", weight: 2), ...)` | 自定义多列对齐（支持各列设置固定宽度或权重比例） |
| `.image(uiImage, dither: .floydSteinberg)` | 打印位图，支持灰度阈值法与误差扩散抖动 |
| `.qrcode("https://...")` | ESC/POS 硬件原生二维码 |
| `.barcode("123456", type: .code128)` | 一维条形码（支持下方 HRI 数字） |
| `.drawer` | 弹出收银钱箱 |
| `.cut` / `.partialCut` / `.feedAndCut` | 全切纸 / 半切纸 / 进纸切纸 |
| `.feed(3)` | 走纸指定行数 |
| `.beep(2)` | 蜂鸣器发声提醒 |
| `.spacing(22)` / `.defaultSpacing` | 自定义行间距 / 恢复默认行距 |
| `.blackMark` | 进纸定位至黑标/标签切口 |

---

## 📄 开源协议与贡献

- 协议：[MIT License](LICENSE)
- 更新记录：[CHANGELOG.md](CHANGELOG.md)
- 参与贡献：[CONTRIBUTING.md](CONTRIBUTING.md)
