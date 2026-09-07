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

## 🚀 快速上手

### 1. 声明式构建一张小票 (SwiftUI 风格 Result Builder)

```swift
import LinePrinter

let ticket = Ticket(autoCut: true) {
    // 1. 店铺标题 (加粗居中)
    Chunk.text("味美餐饮旗舰店", bold: true, alignment: .center)
    Chunk.text("-- 欢迎光临 --", attributes: [TextAttribute.alignment(.center)])
    Chunk.splitter
    
    // 2. 基础单号信息
    Chunk.text("单号：NO.20260907001")
    Chunk.text("时间：2026-09-07 12:30:00")
    Chunk.splitter
    
    // 3. 多列表头 (品名 2 权重、数量 1 权重、金额 1 权重)
    Chunk.row(totalWidth: 32,
              LineColumn("品名", weight: 2, alignment: .left),
              LineColumn("数量", weight: 1, alignment: .center),
              LineColumn("金额", weight: 1, alignment: .right))
    Chunk.splitter(char: "-")
    
    // 4. 明细 (原生支持 for-in 循环，支持超长菜名智能折行 wrap: true)
    for item in orderItems {
        Chunk.threeColumn(item.name, "x\(item.quantity)", item.price, wrap: true)
    }
    Chunk.splitter
    
    // 5. 汇总金额 (原生支持 if 条件控制)
    Chunk.twoColumn("原价合计", "￥49.00")
    if hasCoupon {
        Chunk.twoColumn("会员优惠", "-￥9.00")
    }
    Chunk.twoColumn("实付金额", "￥40.00")
    Chunk.splitter
    
    // 6. 二维码与条形码
    Chunk.text("扫码开具电子发票", attributes: [TextAttribute.alignment(.center)])
    Chunk.qrcode("https://weixin.qq.com/r/example_invoice")
    Chunk.barcode("20260907001", type: .code128)
    
    // 7. 尾部提示与走纸
    Chunk.text("多谢惠顾，欢迎再次光临！", attributes: [TextAttribute.alignment(.center)])
    Chunk.feed(lines: 4)
}

// 亦可使用超简变长参数形式（无中括号，逗号隔开）：
let quickTicket = LinePrinter.ticket(
    .text("快速收银单", bold: true, alignment: .center),
    .splitter,
    .twoColumn("实付金额", "￥25.00"),
    .qrcode("https://...")
)
```

---

### 2. 输出小票数据（完全由外部自由发送）

#### 方式 A：直接获取纯连续二进制流（推荐）

```swift
// 1. 生成标准的 ESC/POS 连续二进制数据
let data: Data = ticket.bytes(using: .gbk)

// 2. 外部自由下发（按你自己项目的现有连接方式发送）：

// 场景 1：写入你已连接的低功耗蓝牙外设
myPeripheral.writeValue(data, for: myCharacteristic, type: .withoutResponse)

// 场景 2：写入你自己的局域网 TCP Socket
myTcpSocket.write(data)

// 场景 3：直接传给商米 / 联迪 / 新大陆等一体机硬件 SDK
SunmiPrinterService.shared.sendRAWData(data)
```

#### 方式 B：通过通道协议 `PrinterTransport`（链式直出 / 构建即发送）

让你的通信管理类遵循 `PrinterTransport` 协议：

```swift
class MyBluetoothManager: PrinterTransport {
    func write(_ data: Data) {
        // 在此执行分包发送或直接写入外设特征值
        currentPeripheral?.writeValue(data, for: writeChar, type: .withoutResponse)
    }
}

let bluetooth = MyBluetoothManager()

// 语法 1：变长参数构建即发送（一行直出，无需临时变量）
LinePrinter.print(to: bluetooth, autoCut: true,
    .text("快速收银小票", bold: true, alignment: .center),
    .splitter,
    .twoColumn("实付金额", "￥30.00"),
    .qrcode("https://...")
)

// 语法 2：ResultBuilder 闭包构建即发送（支持 if/for，手感如 SwiftUI）
LinePrinter.print(to: bluetooth, autoCut: true) {
    Chunk.text("味美餐饮店", bold: true, alignment: .center)
    for item in orderItems {
        Chunk.threeColumn(item.name, "x\(item.quantity)", item.price)
    }
    Chunk.twoColumn("实付金额", "￥50.00")
    Chunk.qrcode("https://...")
}

// 语法 3：现有 Ticket 对象链式发送
ticket.print(to: bluetooth)
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
| `.splitter(char: "-")` | 自适应行宽的分割线 |
| `.twoColumn("原价", "￥50")` | 快速两列左右对齐 |
| `.threeColumn("品名", "x1", "35.00", wrap: true)` | 快速三列对齐（支持超长菜品名自动换行） |
| `.row(totalWidth: 32, ...)` | 自定义多列对齐（支持各列设置固定宽度或权重比例） |
| `.group(...)` | 垂直块分组容器 |
| `.image(uiImage, dither: .floydSteinberg)` | 打印位图，支持灰度阈值法与误差扩散抖动 |
| `.qrcode("https://...")` | ESC/POS 原生二维码 |
| `.barcode("123456", type: .code128)` | 一维条形码 |
| `.openDrawer` | 弹出收银钱箱 |
| `.cut` / `.partialCut` / `.feedAndCut` | 全切纸 / 半切纸 / 进纸切纸 |
| `.feed(lines: 3)` | 走纸指定行数 |

---

## 📄 开源协议与贡献

- 协议：[MIT License](LICENSE)
- 更新记录：[CHANGELOG.md](CHANGELOG.md)
- 参与贡献：[CONTRIBUTING.md](CONTRIBUTING.md)
