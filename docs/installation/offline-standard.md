# standard 离线包

standard 离线发行由四个组件组成：

1. macOS Apple Silicon 运行包；
2. Windows x64 CPU 兼容运行包；
3. 两个平台共用的 HaS GGUF 模型包；
4. 两个平台共用的 PaddleOCR/PP-Structure 模型包。

用户只需要下载自己平台的运行包，以及两个共享模型包。所有文件必须使用 Release 中的 `SHA256SUMS` 校验。

## 下载入口

- GitHub Release（当前可用）：https://github.com/bseazh/PrivacyGuard/releases/tag/offline-standard-v0.1.0
- 国内镜像（DNS 生效后）：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/

国内镜像无法访问时直接改用 GitHub；不要关闭 TLS 校验。两个来源中的同名文件应通过相同的 `SHA256SUMS` 校验。

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

解压运行包，把两个模型包放在解压目录的上一级，然后执行：

```bash
./install-offline-macos.sh
./scripts/start-macos.sh
```

## Windows x64

解压运行包，把两个模型包放在解压目录的上一级，在 PowerShell 中执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-Offline-Windows.ps1 -InstallPython
.\Start-PrivacyGuard.ps1
```

Windows standard 离线包使用 CPU 兼容运行方式，不依赖 WSL 或 NVIDIA GPU。它需要在 Windows x64 实机完成最终验收；在 macOS 上只能完成文件与依赖的交叉构建检查。

## 构建

在已经具备模型、PaddleX 缓存和 macOS Python 环境的 Apple Silicon 构建机执行：

```bash
./scripts/build-offline-standard.sh
```

输出目录默认为 `dist/offline/v0.1.0/`。发行包不包含 `backend/data`、`backend/uploads`、`backend/outputs`、日志或任何用户材料。此 v0.1.0 发行已按授权发布；后续版本或第三方再次分发仍须单独确认许可。
