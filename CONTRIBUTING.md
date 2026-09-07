# 贡献指南 (Contributing to LinePrinter)

感谢你对 `LinePrinter` 项目的关注与支持！无论是提出 Issue、优化文档，还是提交 Pull Request，我们都非常欢迎。

## 提交代码规范
1. Fork 本仓库并基于 `main` 分支创建新的特性分支（如 `feature/xxx` 或 `fix/xxx`）。
2. 在修改代码后，请确保在 `Example` 工程中运行单元测试，保证所有测试用例通过：
   ```bash
   xcodebuild test -workspace Example/LinePrinter.xcworkspace -scheme LinePrinter-Example -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
   ```
3. 遵循 Swift 官方编码风格指南。
4. 提交 Pull Request 并详细描述改动原因与验证方式。
