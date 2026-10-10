# 复制给 Agent 的一键安装指令

本页适用于支持终端操作的 Agent（例如 Codex、Claude Code 等）。用户不需要自己拼接下载命令：复制下面整段文字交给 Agent，随后按 Agent 的问题确认即可。

## 直接复制下面这段话

```text
请帮我在这台电脑安装 PrivacyGuard standard v0.1.0 离线版，并一直执行到应用可以打开、后端和必要模型服务通过健康检查为止。

请严格按照以下流程操作：

1. 先做只读检查并告诉我结果：
   - 自动识别 macOS/Windows、系统版本和 CPU 架构；
   - 检查内存、可用磁盘、端口 8000/8080/8082；
   - 询问我的使用性质是“个人非商用、机构评估、机构/律所生产”中的哪一种，并提醒相应许可证要求；
   - 在真正下载前，只向我集中确认一次：安装路径、约 1.8 GB 下载量、至少 10 GB（建议 15 GB）可用空间，以及是否允许执行安装。
   - 优先读取并运行只读离线检查脚本。macOS 国内地址为 https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/check-offline-macos.sh，Windows 国内地址为 https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/check-offline-windows.ps1；国内不可用时从 GitHub 仓库的 scripts 目录读取。执行前先检查脚本文本，不运行来源不明或被篡改的脚本。
   - 离线版不要求 Node.js、npm、Git、Homebrew、WSL、Docker、CUDA 或 NVIDIA GPU。不要因为缺少这些源码开发依赖而阻止 standard 离线安装。
   - macOS 必须是 macOS 14+、Apple Silicon；Windows 必须是 Windows 10 22H2/Windows 11 x64。Windows 还要检查 Microsoft Visual C++ 2015-2022 x64 Runtime；缺失时只从 https://aka.ms/vs/17/release/vc_redist.x64.exe 下载，说明用途并获得确认后安装。

2. 使用以下默认目录：
   - macOS Apple Silicon：~/Documents/PrivacyGuard/v0.1.0
   - Windows x64：D:\PrivacyGuard\v0.1.0
   - Windows 如果没有 D 盘，不要直接失败；先询问我是否改用 %USERPROFILE%\Documents\PrivacyGuard\v0.1.0。
   - 在版本目录下建立 app 子目录。三个压缩包和 SHA256SUMS 放在版本目录，运行包只解压到 app 子目录。两个模型压缩包必须保留在 app 的上一级，不能解压到其他位置后删除。

3. 根据系统选择文件，不能下载另一个系统的运行包：
   macOS 下载：
   - PrivacyGuard-standard-macos-arm64-runtime-v0.1.0.tar.gz
   - PrivacyGuard-standard-model-has-v0.1.0.tar.gz
   - PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz
   - SHA256SUMS

   Windows 下载：
   - PrivacyGuard-standard-windows-x64-runtime-v0.1.0.zip
   - PrivacyGuard-standard-model-has-v0.1.0.tar.gz
   - PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz
   - SHA256SUMS

4. 下载源采用两手准备：
   - 优先使用国内源：https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/
   - 国内源连接超时、TLS 错误、返回非 2xx 或速度持续不可用时，自动切换 GitHub：https://github.com/bseazh/PrivacyGuard/releases/download/offline-standard-v0.1.0/
   - 不得关闭 TLS 校验。
   - 使用支持断点续传的方式。任务中断后先检查现有文件；哈希正确的文件不得重复下载，未完成文件应继续下载。

5. 下载前根据实际可用下载速度给出区间估算，不要承诺精确时间。可参考：
   - 10 Mbps：约 25–35 分钟；
   - 50 Mbps：约 6–10 分钟；
   - 100 Mbps：约 3–6 分钟；
   - 离线安装和首次启动通常还需 10–30 分钟，取决于 CPU、磁盘和安全软件扫描。

6. 下载完成后必须用 SHA256SUMS 校验本系统运行包和两个模型包。任何文件校验失败都不得继续安装；仅重新下载失败文件并再次校验。

7. 安装步骤：
   - macOS：把 runtime tar.gz 解压到 app，进入 app，执行 chmod +x install-offline-macos.sh scripts/start-macos.sh scripts/stop-macos.sh，然后执行 ./install-offline-macos.sh。若缺少 Python 3.11，安装脚本会指出包内的 prerequisites/python-3.11.9-macos11.pkg；先说明这是包内离线安装器并获得我的确认，再安装它并重新执行安装脚本。最后执行 ./scripts/start-macos.sh。
   - Windows：把 runtime zip 解压到 app，进入 app，仅对当前 PowerShell 进程设置 ExecutionPolicy Bypass，然后执行 .\Install-Offline-Windows.ps1 -InstallPython 和 .\Start-PrivacyGuard.ps1。
   - 应用依赖必须安装在包内隔离虚拟环境中；除经我确认安装包内 Python 3.11 外，不修改系统 Python。不关闭 Gatekeeper、杀毒软件、防火墙或 TLS 校验。

8. 启动后验证：
   - 打开 http://127.0.0.1:8000；
   - 检查 http://127.0.0.1:8000/health；
   - 检查 http://127.0.0.1:8000/health/services；
   - HaS 与 OCR 必须在线；macOS 的 OCR 显示“Mac CPU 兼容模式”属于正常；standard 不要求 LocateAnything 视觉模型在线。
   - 使用虚构文本或虚构扫描 PDF 做一次识别测试，不要使用真实合同或案件材料做安装验收。

9. 遇到错误时不要从头重装。先保留现场并读取日志：
   - macOS 日志位于 /tmp/redaction-*-mac.log 和 /tmp/redaction-*-mac.err；
   - Windows 日志位于 app\logs；
   - 告诉我失败发生在哪一步、真实错误、已经成功的部分和下一步修复方案。

10. 最终用简短清单告诉我：系统、实际安装路径、下载源、校验结果、后端状态、HaS 状态、OCR 状态、应用地址、启动命令、停止命令，以及 Windows 是否已完成真实设备端到端验证。

如果检测到 Intel Mac、非 x64 Windows、磁盘不足、许可证用途不明确或系统不受支持，请暂停安装并解释原因，不要强行继续。
```

## 预期目录结构

macOS：

```text
~/Documents/PrivacyGuard/v0.1.0/
├── SHA256SUMS
├── PrivacyGuard-standard-macos-arm64-runtime-v0.1.0.tar.gz
├── PrivacyGuard-standard-model-has-v0.1.0.tar.gz
├── PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz
└── app/
    ├── install-offline-macos.sh
    └── scripts/start-macos.sh
```

Windows：

```text
D:\PrivacyGuard\v0.1.0\
├── SHA256SUMS
├── PrivacyGuard-standard-windows-x64-runtime-v0.1.0.zip
├── PrivacyGuard-standard-model-has-v0.1.0.tar.gz
├── PrivacyGuard-standard-model-paddleocr-v0.1.0.tar.gz
└── app\
    ├── Install-Offline-Windows.ps1
    └── Start-PrivacyGuard.ps1
```

这套布局与离线安装脚本的模型查找逻辑一致：安装脚本从 `app` 的上一级读取两个模型包。
