# PrivacyGuard standard 离线包

安装前要求：

- macOS：macOS 14+、Apple Silicon；先运行 `./check-offline-macos.sh`；
- Windows：Windows 10 22H2/Windows 11 x64；先运行 `.\Check-Offline-Windows.ps1`；
- 至少 10 GB 可用磁盘，建议 15 GB；至少 8 GB 内存，建议 16 GB；
- Windows 可能需要 Microsoft Visual C++ 2015–2022 x64 Runtime，缺失时只从 `https://aka.ms/vs/17/release/vc_redist.x64.exe` 下载。

包内已包含前端、Python 3.11 安装器、Python wheels 和运行时。standard 离线版不需要 Node.js、Git、Homebrew、WSL、Docker、CUDA 或 NVIDIA GPU。

本运行包需要同版本的两个模型包放在运行包目录的上一级：

- `PrivacyGuard-standard-model-has-<version>.tar.gz`
- `PrivacyGuard-standard-model-paddleocr-<version>.tar.gz`

macOS Apple Silicon：

```bash
./install-offline-macos.sh
./scripts/start-macos.sh
```

Windows x64 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-Offline-Windows.ps1 -InstallPython
.\Start-PrivacyGuard.ps1
```

安装过程不访问网络。安装脚本会校验模型包 SHA-256，并使用随包提供的 Python wheel。不得把真实合同、上传文件或导出结果放回发行包。

Windows 包为 CPU 兼容模式，不要求 WSL 或 NVIDIA GPU；大型扫描文件会明显慢于 NVIDIA GPU 部署。macOS 使用 PaddleOCR CPU 与 llama.cpp/Metal。

本包仅用于许可证允许的本地使用或评估。仓库许可证不自动授予公开再分发权；上传 Release、对象存储或交付第三方前必须取得版权方书面许可。
