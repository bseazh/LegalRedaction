# standard 离线包

standard 离线发行由四个组件组成：

1. macOS Apple Silicon 运行包；
2. Windows x64 CPU 兼容运行包；
3. 两个平台共用的 HaS GGUF 模型包；
4. 两个平台共用的 PaddleOCR/PP-Structure 模型包。

用户只需要下载自己平台的运行包，以及两个共享模型包。所有文件必须使用 Release 中的 `SHA256SUMS` 校验。

## 下载入口

- GitHub Release（当前可用）：https://github.com/bseazh/PrivacyGuard/releases/tag/offline-standard-v0.1.0
- 国内平台选择页：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/
- macOS 专用页：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/macos.html
- Windows 专用页：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/windows.html
- 可复制给 Agent 的任务书：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/agent-install.md

国内镜像无法访问时直接改用 GitHub；不要关闭 TLS 校验。两个来源中的同名文件应通过相同的 `SHA256SUMS` 校验。

## 依赖检查

- macOS：macOS 14+、Apple Silicon、至少 10 GB 可用磁盘；运行 `scripts/check-offline-macos.sh`。
- Windows：Windows 10 22H2/Windows 11 x64、PowerShell 5.1+、`tar.exe`、至少 10 GB 可用磁盘；运行 `scripts\check-offline-windows.ps1`。
- 两个平台均建议 16 GB 内存和 15 GB 以上可用磁盘。
- Python 3.11 安装器和全部 Python wheels 已包含；不需要 Node.js、Git、Homebrew、WSL、Docker、GPU 或 CUDA。
- Windows 如果缺少 Microsoft Visual C++ 2015–2022 x64 Runtime，应只从微软官方地址下载：https://aka.ms/vs/17/release/vc_redist.x64.exe 。

macOS Apple Silicon 下载以下四个文件：

- `PrivacyGuard-standard-macos-arm64-runtime-v0.1.0.tar.gz`
- `PrivacyGuard-standard-model-has-v0.1.0.tar.gz`
- `PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz`
- `SHA256SUMS`

Windows x64 下载以下四个文件：

- `PrivacyGuard-standard-windows-x64-runtime-v0.1.0.zip`
- `PrivacyGuard-standard-model-has-v0.1.0.tar.gz`
- `PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz`
- `SHA256SUMS`

下载完成后校验：

```bash
# macOS：在下载目录执行
grep -E 'macos-arm64|model-' SHA256SUMS | shasum -a 256 -c -
```

```powershell
# Windows PowerShell：逐项与 SHA256SUMS 对照
Get-FileHash .\PrivacyGuard-standard-*-v0.1.0* -Algorithm SHA256
```

> 许可提醒：仓库当前的 `DataInfra RedactionEverything Personal Use License 1.0` 不允许未经单独书面授权公开重新分发项目副本。可以为已获许可的本地使用构建离线包，但在上传 GitHub Release、对象存储或交付第三方之前，必须先取得项目版权方的书面再分发许可。构建成功不等于获得发布权。

## macOS Apple Silicon

解压运行包，把两个模型包放在解压目录的上一级，然后双击：

1. `Install-PrivacyGuard.command`
2. `Launch-PrivacyGuard.command`

检测使用 `Test-PrivacyGuard.command`，停止使用 `Stop-PrivacyGuard.command`。

## Windows x64

解压运行包，把两个模型包放在解压目录的上一级，然后双击：

1. `Install-PrivacyGuard.cmd`
2. `Launch-PrivacyGuard.cmd`

检测使用 `Check-PrivacyGuard.cmd`，停止使用 `Stop-PrivacyGuard.cmd`。

Windows standard 离线包使用 CPU 兼容运行方式，不依赖 WSL 或 NVIDIA GPU。v0.1.0 已在 GitHub 托管的 Windows Server 2025 x64 环境完成端到端验收：离线安装、模型解压、HaS、PaddleOCR、后端健康检查、停止和日志收集均通过。测试记录：[GitHub Actions 38041971610](https://github.com/bseazh/PrivacyGuard/actions/runs/38041971610)。

macOS v0.1.0 已在 macOS 14.8.1 Apple Silicon（M2、16 GB）完成纯离线启动验证，后端、HaS、OCR 均可访问；OCR 使用“Mac CPU 兼容模式”。

## 构建

在已经具备模型、PaddleX 缓存和 macOS Python 环境的 Apple Silicon 构建机执行：

```bash
./scripts/build-offline-standard.sh
```

输出目录默认为 `dist/offline/v0.1.0/`。发行包不包含 `backend/data`、`backend/uploads`、`backend/outputs`、日志或任何用户材料。此 v0.1.0 发行已按授权发布；后续版本或第三方再次分发仍须单独确认许可。
