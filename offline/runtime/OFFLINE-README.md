# PrivacyGuard standard 离线包

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
