# 安装 FAQ

## 应该选择哪个档位？

只处理可复制文字的 PDF/DOCX 选 basic；需要扫描 PDF 选 standard；需要人脸、印章和签名定位才选 full。

## standard 离线包从哪里下载？

进入[国内平台选择页](https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/)，选择 macOS 或 Windows。系统专用页只展示该平台需要的 4 个文件。国内镜像不可用时改用 [GitHub Release](https://github.com/bseazh/PrivacyGuard/releases/tag/offline-standard-v0.1.0)，下载后必须用 `SHA256SUMS` 校验。

不想自己操作命令时，复制[完整安装任务书](./copy-paste-agent-prompt.md)给支持终端操作的 Agent。Agent 会先说明路径、预计时间和系统修改，获得确认后再执行。

## 为什么不能只下载运行包？

运行包不包含全部模型权重。standard 还需要 HaS 文本识别模型和 PaddleOCR 模型；请下载系统专用页列出的全部 4 个文件并放在同一目录。

## 离线版还要安装哪些依赖？

大部分依赖已经包含：构建后的前端、Python wheels、Python 3.11 安装器、llama.cpp、HaS 和 PaddleOCR。standard 离线版不需要 Node.js、Git、Homebrew、WSL、Docker、CUDA 或 NVIDIA GPU。Windows 若缺少 Microsoft Visual C++ 2015–2022 x64 Runtime，需要从微软官方下载；macOS 当前包要求 macOS 14+ Apple Silicon。详见 [环境要求](./requirements.md)。

## 为什么页面显示离线？

页面通过 `/health/services` 检查本地服务。常见原因是模型未下载、虚拟环境缺依赖、端口占用、服务启动后崩溃，或所选档位本来就没有安装该服务。

## macOS 为什么显示 OCR CPU 兼容模式？

这是预期配置。PaddleOCR 在当前 Mac 方案中使用 CPU；HaS 使用 llama.cpp/Metal，LocateAnything 可尝试 MPS。

## 离线包是否经过真实环境测试？

是。macOS v0.1.0 已在 macOS 14.8.1 Apple Silicon（M2、16 GB）完成离线启动验证。Windows v0.1.0 已在 GitHub 托管的 Windows Server 2025 x64 完成完整测试，包括下载、SHA-256、完全离线安装、模型解压、HaS、PaddleOCR、后端健康检查、停止和日志收集；测试记录为 [GitHub Actions 38041971610](https://github.com/bseazh/PrivacyGuard/actions/runs/38041971610)。不同用户电脑仍应先运行预检脚本，以排除磁盘、端口和 Visual C++ Runtime 等本机差异。

## 为什么不提供一个脚本把所有模型全部下载？

模型体积、许可证和硬件要求不同。向所有用户默认下载 full 模型会浪费空间，也可能违反使用目的对应的模型许可。向导会先问能力和授权，再下载必要部分。

## 安装完成为什么还要跑虚构样本？

服务在线只说明进程可访问，不代表识别、坐标映射和 PDF 安全删除都正常。验收必须覆盖一次完整导出。

## 可以使用真实合同测试安装吗？

不建议。安装验收应使用仓库提供或单独生成的虚构样本，确认本地隐私边界后再处理真实材料。
