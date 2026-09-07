# LinePrinter

<p align="right">
  <a href="README_CN.md"><b>简体中文</b></a> | <b>English</b>
</p>

[![Swift 5.0+](https://img.shields.io/badge/Swift-5.0+-orange.svg?style=flat)](https://swift.org)
[![Platform iOS](https://img.shields.io/badge/Platform-iOS%2012.0+-lightgrey.svg?style=flat)](https://developer.apple.com/ios/)
[![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-v0.3.0-blue.svg?style=flat)](https://cocoapods.org)
[![License MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat)](https://github.com/Nelozx/LinePrinter/blob/main/LICENSE)

`LinePrinter` is a pure native, zero-dependency, and non-intrusive **declarative ESC/POS thermal receipt layout engine and visual previewer** designed for iOS. Tailored for restaurant dining, takeout tickets, retail checkout, supermarkets, and warehouse logistics.

The core mission of `LinePrinter` is **declarative receipt layout, binary ESC/POS command stream (`Data`) generation, and realistic UI simulation**. It does not enforce Bluetooth or network connection management, completely avoiding conflicts with your app's existing `CBCentralManager`, network connection pools, or commercial POS hardware SDKs (e.g., Sunmi, Landi, Newland). **No sensitive Bluetooth or local network permissions are required in `Info.plist`**.

---

## 📸 Visual Showcase (Screenshots)

<p align="center">
  <img src="Screenshots/demo.png" width="280" alt="Demo App Interactive Flow" style="margin-right: 16px; border-radius: 8px;" />
  <img src="Screenshots/receipt_58mm.png" width="260" alt="58mm Restaurant Receipt" style="margin-right: 16px; border-radius: 8px;" />
  <img src="Screenshots/receipt_80mm.png" width="280" alt="80mm Supermarket Receipt" style="border-radius: 8px;" />
</p>

| **📱 Physical Feed & Interactive Simulation** | **🧾 58mm Restaurant Multi-Column Wrapping** | **🏬 80mm Supermarket Wide Receipt** |
| :---: | :---: | :---: |
| Realistic paper feed translation & haptic feedback | Smart weight distribution & long item name wrapping | 48-char wide layout & Code128 barcode rendering |

---

## ✨ Key Features

- 🎯 **Decoupled Layout Engine & Transport**:
  - Compiles directly into standard ESC/POS binary data (`ticket.bytes(using: .gbk) -> Data`);
  - Provides a lightweight channel protocol `PrinterTransport` (`ticket.print(to: transport)`), making any external communication interface plug-and-play.
- 🛡️ **Zero Dependencies & Zero Permissions**: Built strictly on top of `UIKit` and standard system libraries. No 3rd-party dependencies, no permission declarations needed.
- 👁️ **High-Fidelity Visual Previewer (`TicketPreview`)**:
  - Realistic thermal paper aesthetics: chamfered top cut, serrated bottom tear-off edge, and soft shadows;
  - Generate a live interactive preview (`ticket.previewView()`) or export a high-res Retina (2x) long image (`ticket.previewImage()`) in a single line of code.
- 📊 **Smart Multi-Column Alignment & Auto-Wrapping**: Accurately computes display widths for full-width CJK characters and half-width ASCII; features **intelligent text wrapping (`wrap: true`)** while preserving price and quantity vertical alignment.
- 🖼️ **Industrial Bitmap Algorithms**: Native extension for `UIImage.rasterEscPosData` with both **Luminance Threshold** and **Floyd-Steinberg Error Diffusion Dithering**, delivering sharp logos and smooth gradient photos on 1-bit thermal paper.
- 🇨🇳 **Chinese Encoding Support**: Deeply optimized for GB18030 / GBK encoding to prevent garbled text.
- 🔍 **Hardware Status Parser**: Built-in `PrinterHardwareStatus.parse(byte:)` to instantly parse real-time error flags like **Out of Paper**, **Cover Open**, or **Offline**.
- 📱 **Declarative Swift DSL**: SwiftUI-like structure, clean and expressive.

---

## 📦 Installation

### Swift Package Manager (Recommended)

In Xcode, navigate to `File` -> `Add Packages...` and enter the repository URL:

```
https://github.com/Nelozx/LinePrinter.git
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
# Option A: Specify the tagged release version (Recommended)
pod 'LinePrinter', :git => 'https://github.com/Nelozx/LinePrinter.git', :tag => '0.3.0'

# Option B: Track the latest main branch
pod 'LinePrinter', :git => 'https://github.com/Nelozx/LinePrinter.git'
```

---

## 🚀 Quick Start

### 1. Build a Receipt Declaratively (SwiftUI-Style Result Builder)

```swift
import LinePrinter

let ticket = Ticket(autoCut: true) {
    // 1. Header (Bold & Centered)
    Chunk.text("Gourmet Restaurant Flagship", bold: true, alignment: .center)
    Chunk.text("-- Welcome --", attributes: [TextAttribute.alignment(.center)])
    Chunk.splitter
    
    // 2. Order Metadata
    Chunk.text("Order No: NO.20260907001")
    Chunk.text("Time: 2026-09-07 12:30:00")
    Chunk.splitter
    
    // 3. Multi-Column Header
    Chunk.row(totalWidth: 32,
              LineColumn("Item", weight: 2, alignment: .left),
              LineColumn("Qty", weight: 1, alignment: .center),
              LineColumn("Amount", weight: 1, alignment: .right))
    Chunk.splitter(char: "-")
    
    // 4. Line Items (Native for-in loops and auto-wrapping)
    for item in orderItems {
        Chunk.threeColumn(item.name, "x\(item.qty)", item.price, wrap: true)
    }
    Chunk.splitter
    
    // 5. Total & Discounts (Native if-condition support)
    Chunk.twoColumn("Subtotal", "$49.00")
    if hasCoupon {
        Chunk.twoColumn("VIP Discount", "-$9.00")
    }
    Chunk.twoColumn("Total Paid", "$40.00")
    Chunk.splitter
    
    // 6. QR Code & Barcode
    Chunk.text("Scan for e-Invoice", attributes: [TextAttribute.alignment(.center)])
    Chunk.qrcode("https://weixin.qq.com/r/example_invoice")
    Chunk.barcode("20260907001", type: .code128)
    
    // 7. Footer & Paper Feed
    Chunk.text("Thank you for your visit!", attributes: [TextAttribute.alignment(.center)])
    Chunk.feed(lines: 4)
}

// Alternatively, use lightweight variadic parameters (no brackets):
let quickTicket = LinePrinter.ticket(
    .text("Quick Checkout", bold: true, alignment: .center),
    .splitter,
    .twoColumn("Total", "$25.00"),
    .qrcode("https://...")
)
```

---

### 2. Dispatch Binary Data (Completely Decoupled)

#### Approach A: Direct Raw Binary Stream (`Data`) (Recommended)

```swift
// 1. Generate standard ESC/POS continuous binary data
let data: Data = ticket.bytes(using: .gbk)

// 2. Transmit via your app's existing pipeline:

// Scenario 1: Write to connected CoreBluetooth peripheral
myPeripheral.writeValue(data, for: myCharacteristic, type: .withoutResponse)

// Scenario 2: Write to your local TCP Socket
myTcpSocket.write(data)

// Scenario 3: Forward to commercial POS hardware SDKs (Sunmi / Landi / Newland)
SunmiPrinterService.shared.sendRAWData(data)
```

#### Approach B: Via `PrinterTransport` Protocol

Conform your communication manager to `PrinterTransport`:

```swift
class MyBluetoothManager: PrinterTransport {
    func write(_ data: Data) {
        currentPeripheral?.writeValue(data, for: writeChar, type: .withoutResponse)
    }
}

let transport = MyBluetoothManager()
// Print directly through transport
ticket.print(to: transport, encoding: .gbk)
```

---

### 3. Visual UI Preview & High-Res Image Export

Inspect physical paper aesthetics and layout on screen without connecting to a hardware printer:

```swift
// 1. Obtain live preview UIView and insert into UI hierarchy
let previewView = ticket.previewView(paperWidth: .mm58)
myContainerView.addSubview(previewView)

// 2. Export as high-resolution Retina UIImage (Save to Photos or share)
if let receiptImage = ticket.previewImage(paperWidth: .mm58) {
    UIImageWriteToSavedPhotosAlbum(receiptImage, nil, nil, nil)
}
```

---

### 4. Real-time Hardware Status Parsing (Optional)

Whether notified via Bluetooth characteristic notification or received from a TCP socket response:

```swift
let status = PrinterHardwareStatus.parse(byte: receivedByte)

if status.contains(.paperEmpty) {
    print("⚠️ Printer is out of paper!")
}
if status.contains(.coverOpen) {
    print("⚠️ Platen cover is open!")
}
if status.contains(.offline) {
    print("⚠️ Printer is offline!")
}
```

---

## 🎨 DSL Elements Quick Reference

| DSL Element | Description |
|---|---|
| `.text("Content", bold: true, alignment: .center)` | Styled text with auto-reset alignment, size, and weight |
| `.splitter(char: "-")` | Responsive full-width horizontal separator line |
| `.twoColumn("Left", "Right")` | Quick two-column aligned layout |
| `.threeColumn("Name", "Qty", "Price", wrap: true)` | Three-column layout with optional auto-wrapping for long names |
| `.row(totalWidth: 32, ...)` | Fully customizable multi-column layout with fixed widths or weights |
| `.group(...)` | Vertical block container |
| `.image(uiImage, dither: .floydSteinberg)` | Raster bitmap with thresholding or Floyd-Steinberg error diffusion |
| `.qrcode("https://...")` | ESC/POS native hardware QR code |
| `.barcode("123456", type: .code128)` | Standard 1D barcode (Code128, EAN13, etc.) |
| `.openDrawer` | Sends cash drawer pulse |
| `.cut` / `.partialCut` / `.feedAndCut` | Full cut / Partial cut / Feed & Cut |
| `.feed(lines: 3)` | Feed paper by specified number of lines |

---

## 📄 License & Contributing

- License: [MIT License](LICENSE)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
