# 常见问题（FAQ）

## 页面一直显示“正在连接本地服务”或“离线”

这通常不是前端样式问题，而是 `127.0.0.1:8766` 的本地 Python 服务没有启动、启动后崩溃，或端口被占用。先访问 `http://127.0.0.1:8766/health`，再查看 `logs/legalredaction.log`。

## macOS 提示无法导入 `mlx` 或 `mlx_lm`

确认使用 Apple Silicon，并从 `.venv-mlx` 启动：

```bash
source .venv-mlx/bin/activate
python -c "import mlx, mlx_lm; print('OK')"
```

Intel Mac 和 Windows 不能使用 MLX，请改用规则模式：`PRIVACYGUARD_NER_BACKEND=rules`。

## 为什么 Windows 识别不到人名或公司名

Windows 当前默认是规则模式，只识别格式稳定的敏感信息。跨平台语义模型后端仍需增加，不能把 MLX 权重直接搬到 Windows 运行。

## PDF 上传成功，但不能导出假名化 PDF

常见原因是 PDF 为扫描图片、字体编码导致搜索文本与提取文本不同，或确认的实体已经被人工修改。系统会拒绝部分成功的输出。扫描件需等待 OCR 坐标版补丁。

## 为什么只导出 TXT，没有保留 PDF 排版

请选择 PDF 文件、完成全部复核、选择“语义假名”或“自然假名”，再点击“导出假名化 PDF”。技术 Token 模式只用于文本和映射，不用于 PDF 原位回写。

## 假名化以后能否恢复

脱敏 PDF 本身不能恢复原文。需要同时保存导出的 AES-256-GCM 加密映射，并妥善备份原始文件。映射加密密钥目前保存在当前应用的本地存储中；清理应用数据前必须先设计密钥备份流程。

## 模型下载很慢或中断

重新运行 `python scripts/download_model.py` 会复用 Hugging Face 缓存。企业网络可设置 `HF_ENDPOINT` 使用可信镜像，但不要关闭 TLS 校验。

## 模型为什么不直接放进 Git

Git 不适合保存数 GB 权重。当前模型约 3.2GB；GitHub Release 单个资产也有大小限制，需要拆成约 1.9GB 的分片。推荐优先使用 Hugging Face，Release 仅作为版本化镜像。

## 可以把 7GB 权重放到 GitHub Release 吗

可以，但必须拆分。执行 `scripts/package_model_release.sh /模型目录` 生成分片和 `SHA256SUMS`，然后用 `gh release upload` 上传。下载端必须合并并校验 SHA-256。更推荐发布到专门的模型仓库。

## `pdftotext` 不存在

macOS 执行 `brew install poppler`；Windows 执行 `winget install oschwartz10612.Poppler`，然后重新打开终端。

## macOS 打包时报找不到 `cargo` 或 `rustc`

执行 `brew install rustup-init && rustup-init -y`，重新打开终端，确认 `cargo --version` 可用。
