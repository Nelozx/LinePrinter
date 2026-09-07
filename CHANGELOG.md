# 更新日志 (Changelog)

所有重要变更均记录于此文件中。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

## [0.6.0] - 2026-09-08

### 新增与增强 (Added & Enhanced)
- **纯内存 Base64 与二进制 Data 位图无缝支持**：
  - 支持服务端动态下发 Base64 编码图案（自动清洗 `data:image/...;base64,` 前缀），纯内存二值化，零网络请求、零主线程卡顿隐患。
  - 纯 Data 基于跨平台 `ImageIO` 硬件解码，彻底消除 UIKit / AppKit 平台宏耦合。
- **双列智能自适应排版（彻底解决长单号截断问题）**：
  - 优化 `Row` 热敏排版算法：双列等权重下，右列紧凑占用自身所需宽度，剩余全部空间自动分配给左侧长文本，杜绝长单号被死板 50% 机械截断。
  - 优化 `TicketPreview` 渲染引擎：动态配置 Content Hugging 与 Compression 阻抗，UI 预览与高清长图导出绝无省略号截断。

### 重构与精简 (Refactor & Cleanup)
- **JSON 解析器全面精简（`TicketJSONDecoder`）**：
  - 消除多余平台依赖与重复分支，动作控制指令统一收敛归拢，修复原代码提前 `return` 导致的 `feedPoints` 偶发不生效问题。
  - 保持底层核心金标准协议纯粹，配合 `TicketConvertible` 和 `Ticket(json:mapper:)` 闭包适配器，任意第三方/私有非标 JSON 零门槛无侵入对接。
- **Demo App 升级**：
  - 界面与 JSON 模板全面接入 Base64 品牌 Logo 实装演示与 Floyd-Steinberg 误差扩散抖动出纸动效。

## [0.5.0] - 2026-09-08

### 重构与优化 (Refactor & Architecture)
- **纯粹现代 API，彻底移除所有历史兼容垫片与废弃别名**：
  - 彻底剔除 `Line` 别名，排版列单元统一为 `Col`（`Column`）。
  - 彻底剔除 `twoColumn` / `threeColumn`，统一为重载的 `.row(...)`。
  - 清理旧指令别名，统一为 `.drawer`、`.beep`、`.spacing`、`.defaultSpacing`、`.blackMark`。
- **职责清晰分层与最大化代码复用**：
  - 抽象统一单色点阵模型 `MonochromeBitmap`，消除二值化抖动在光栅数据与 UI 预览间的双重计算，性能显著提升。
  - 服务端 JSON 解析解码全面复用 DSL 静态工厂方法，确保双端行为 100% 同步。
  - 统筹对齐方式 `Commands.Alignment` 与 UIKit `NSTextAlignment` 的属性映射。

## [0.3.0] - 2026-09-07

### 新增功能 (Added)
- **商业级真实热敏小票视觉预览引擎 (`TicketPreview` / `ReceiptPreviewView`)**：
  - 逼真纸质质感模拟：包括顶部倒角切口、底部真实物理撕纸微锯齿（Serrated Edge）与阴影渲染。
  - 原生 CoreImage 条码（Code128）与二维码生成预览。
  - 支持多列弹性排版与长文本自动换行视觉渲染。
  - 支持单小票高清晰度（Retina 2x）长图导出（`ticket.previewImage()`）。
- **仿真出纸物理动画支持**：
  - 完美复刻打印机出纸口下移送纸与触觉震动反馈。
  - 优化 GPU 硬件加速合成，避免离屏渲染与布局重算开销。

### 规范调整 (Specification)
- 更新 `LinePrinter.podspec`：补充 `CoreGraphics`、`CoreImage` 系统 Frameworks 依赖声明。
- 规范化单元测试用例，移除私有绝对路径依赖。


## [0.2.0] - 2026-09-07

### 架构与核心升级 (Architecture)
- **纯粹的排版引擎与通信彻底解耦**：
  - 核心库专注于小票声明式排版与 ESC/POS 连续二进制指令流（`Data`）生成，不强行绑定蓝牙或网络通信；
  - 蓝牙/网络连接完全由宿主项目自主管理，彻底避免与现有连接池或一体机商用硬件 SDK（商米/联迪等）发生冲突；
  - 抽象极简的输出通道协议 `PrinterTransport` (`func write(_ data: Data)`)，实现即插即用；
  - 宿主 App 无需在 `Info.plist` 中声明任何蓝牙或本地网络敏感权限。
- **纯原生零依赖 (Zero Dependencies)**：无任何第三方依赖，仅依赖基础 `UIKit`。
- **硬件双向状态反馈**：内置 `PrinterHardwareStatus.parse(byte:)`，支持实时解析外部回传的“缺纸”、“开盖”、“脱机”等物理异常。
- **多列长文本智能折行 (wrap: true)**：超长菜名自动多行排列，数量和金额列保持精准对齐。
- **图像算法升级**：支持 Floyd-Steinberg 误差扩散抖动算法，提升单色热敏纸打印质感。
- **现代包管理与规范**：
  - 增加根目录 `Package.swift`，支持 Swift Package Manager (SPM)；
  - 增加 GitHub Actions CI 自动化测试流程 (`.github/workflows/ci.yml`)，移除废弃的 Travis CI。

### 修复 (Fixed)
- 修复了图片点阵转换时因灰度值作为下标导致的数组越界致命崩溃。
- 修复了图片宽度非 8 倍数时的边界越界与画面错位。
- 修复了文本样式属性未注入字节流及未自动复位的问题。
