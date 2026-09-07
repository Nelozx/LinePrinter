# 更新日志 (Changelog)

所有重要变更均记录于此文件中。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)。

---

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
