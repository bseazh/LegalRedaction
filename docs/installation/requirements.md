# 环境要求

## standard v0.1.0 离线包

离线包已经包含构建后的前端、Python wheels、Python 3.11 官方安装器、llama.cpp、HaS 和 PaddleOCR 模型。**不需要** Node.js、npm、Git、Homebrew、WSL、Docker、NVIDIA GPU 或 CUDA。

通用要求：

- 下载量约 1.8 GB；至少 10 GB 可用磁盘，建议 15 GB 以上；
- 至少 8 GB 内存，建议 16 GB；
- 端口 `8000/8080/8082` 未被不相关程序占用；
- 能运行系统自带的 SHA-256、tar/解压和 HTTPS 下载工具；
- 安装前运行对应的只读检查脚本：`scripts/check-offline-macos.sh` 或 `scripts/check-offline-windows.ps1`。

macOS 离线包：

- macOS 14 或更高版本；
- Apple Silicon arm64（M1/M2/M3/M4 及后续），不支持 Intel Mac；
- Python 3.11 缺失时，使用运行包内 `prerequisites/python-3.11.9-macos11.pkg`；
- OCR 使用 CPU，HaS 使用 llama.cpp/Metal。

Windows 离线包：

- Windows 10 22H2（build 19045）或 Windows 11 x64；
- PowerShell 5.1+ 和系统 `tar.exe`；
- Python 3.11 缺失时，安装脚本可使用包内 `prerequisites\python-3.11.9-amd64.exe`；
- 需要 Microsoft Visual C++ 2015–2022 x64 Runtime。若检查不到，只能从微软官方下载：https://aka.ms/vs/17/release/vc_redist.x64.exe 。

## 源码安装 / full 视觉版

以下要求只针对从源码开发或 full 视觉方案，不应套用到 standard 离线包：

- Git、Node.js 24 LTS、npm、Python 3.11；
- macOS 可使用 Homebrew 准备开发依赖；
- Windows standard/full 源码路径可能需要 WSL2；
- full 推荐 NVIDIA GPU、16 GB 显存和匹配的驱动/CUDA；
- Docker Desktop 可选，但不能代替模型权重和 GPU 驱动检查。

## 许可证要求

安装 Agent 必须先确认使用性质：个人非商用、机构评估或生产使用。若是机构生产、付费交付或商业集成，必须停止自动安装并提示用户核对商业授权。
