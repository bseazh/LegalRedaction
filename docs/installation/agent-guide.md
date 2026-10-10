# Agent 新手安装向导

本文件提供给能运行终端命令的 Agent。Agent 不得一上来就执行安装，必须先完成问答和只读检查。

面向最终用户的整段可复制任务书见 [copy-paste-agent-prompt.md](./copy-paste-agent-prompt.md)。执行该任务书时，本文件仍是必须遵守的安全与验收规范。

## 必须先问的问题

一次只问必要问题，并给出推荐选项：

1. 使用性质：个人非商用、机构评估、机构/律所生产？
2. 系统：macOS 还是 Windows？版本和 CPU 架构是什么？
3. 能力：只处理文本文件，还是需要扫描 PDF/OCR，或者还需要人脸、印章、签名？
4. 资源：内存、可用磁盘、NVIDIA GPU/显存分别是多少？
5. 网络：能否访问 GitHub、Hugging Face、ModelScope？是否必须离线？
6. 权限：是否允许安装系统依赖和下载数 GB 模型？

若用户选择机构生产、付费交付或商业集成，先展示许可证风险并请求用户确认已取得所需授权。不得自行替用户判断授权有效。

## standard 离线包下载源选择

1. 必须先确认用户使用 macOS 还是 Windows，不得先给出一整页混合文件让用户自行判断；
2. macOS 用户给出 `https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/macos.html`，Windows 用户给出 `https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/windows.html`；尚未确认系统时才给平台选择页 `https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/`；
3. 先探测对应国内页面；若连接超时、TLS 错误或返回非 2xx，则改用 GitHub Release：`https://github.com/bseazh/PrivacyGuard/releases/tag/offline-standard-v0.1.0`；
4. macOS 下载 macOS runtime、HaS、PaddleOCR 和 `SHA256SUMS`；Windows 下载 Windows runtime、HaS、PaddleOCR 和 `SHA256SUMS`；
5. 支持断点续传，但不得通过关闭 TLS 校验解决网络问题；
6. 下载完成后必须校验 SHA-256，失败的文件应删除并重新下载。

## 执行流程

1. 读取本文件、[requirements.md](./requirements.md) 和对应系统指南；
2. 运行 `doctor-macos.sh` 或 `doctor-windows.ps1`；
3. 根据答案推荐 `basic/standard/full`，说明缺失能力；
4. 安装前再次列出预计下载量（standard 约 1.7 GB）、建议预留磁盘（至少 8 GB）和系统修改；
5. 创建隔离虚拟环境，不污染系统 Python；
6. 下载模型时记录来源和校验值；
7. 启动后检查 `/health` 和 `/health/services`；
8. 使用虚构样本完成识别、复核、自然假名 PDF 导出；
9. 验证输出 PDF 无法搜索到原敏感文字；
10. 向用户报告成功项、降级项、日志位置和停止命令。

## 禁止事项

- 不得上传用户文件、数据库、日志、权重或输出到 Git；
- 不得关闭 TLS 校验、Gatekeeper、杀毒软件或系统安全策略；
- 不得把“网页打开”当成安装成功；
- 不得把 CPU 回退的重型模型报告为正常 GPU 运行；
- 不得在用户未确认前下载 full 档位的大模型；
- 不得处理真实案件材料作为安装测试。

## Agent 最终验收模板

```text
安装档位：standard
系统：macOS / Apple Silicon / 16GB
后端：在线
HaS：在线
OCR：在线（Mac CPU 兼容模式）
视觉模型：未安装（不影响本档位）
虚构样本识别：通过
假名化 PDF：通过
原文残留搜索：通过
启动命令：...
停止命令：...
```
