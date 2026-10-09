# PrivacyGuard

PrivacyGuard 是面向中文法律材料的本地敏感信息识别、人工复核和假名化工具。原始文件、识别结果和映射默认只在本机处理。

当前支持：

- TXT、Markdown、EML、DOCX 和有文本层的 PDF；
- 手机号、身份证、邮箱、银行卡等规则识别；
- Apple Silicon 上通过 Qwen3 + MLX 识别人名、机构、地址和法律角色；
- 候选高亮、逐项确认、重叠检查和导出前复核；
- Token、语义假名（人员A/机构A）和自然假名（李明/星河科技）三种替换方式；
- 有文本层 PDF 的安全删除和原位假名写入；
- AES-256-GCM 加密映射导出。

## 快速安装

### macOS（M1/M2/M3/M4，推荐）

```bash
git clone https://github.com/bseazh/PrivacyGuard.git
cd PrivacyGuard
chmod +x scripts/*.sh
./scripts/bootstrap_macos.sh
./scripts/start_macos.sh
```

### Windows 10/11

```powershell
winget install Python.Python.3.12
winget install OpenJS.NodeJS.LTS
winget install oschwartz10612.Poppler
git clone https://github.com/bseazh/PrivacyGuard.git
cd PrivacyGuard
powershell -ExecutionPolicy Bypass -File scripts\bootstrap_windows.ps1
powershell -ExecutionPolicy Bypass -File scripts\start_windows.ps1
```

Windows 当前使用规则引擎；MLX 仅支持 Apple Silicon，所以人名、机构和地址等语义识别能力暂不与 macOS 完全相同。

详细步骤见 [INSTALL.md](INSTALL.md)，常见问题见 [FAQ.md](FAQ.md)。让编码 Agent 自动安装时，把 [AGENT_INSTALL.md](AGENT_INSTALL.md) 交给 Agent。

## PDF 假名化如何工作

确认候选并选择替换方式后，PDF 导出会：

1. 在 PDF 文本层中精确定位原敏感文字；
2. 使用 redaction annotation 删除底层原文字，而不是只盖白框；
3. 在原位置写入稳定假名，同一实体全文保持一致；
4. 重新打开输出文件，检查原敏感文字是否仍可搜索；
5. 任一实体无法定位或安全检查失败时拒绝导出。

扫描 PDF 当前尚未接入 OCR 坐标回写。系统会拒绝将无法定位的扫描件报告为安全脱敏成功。

## 本地开发和测试

```bash
source .venv-mlx/bin/activate
python -m unittest discover -s tests
npm --prefix app test
npm --prefix app run build
```

本地服务监听 `127.0.0.1:8766`，健康检查地址为 `http://127.0.0.1:8766/health`。

## 模型权重

macOS 语义识别使用 `mlx-community/Qwen3-1.7B-bf16`，完整目录约 3.2GB，不提交到 Git：

```bash
source .venv-mlx/bin/activate
python scripts/download_model.py
```

若使用 GitHub Release 承载 3GB/7GB 权重，应拆成小于 2GB 的分片并发布 SHA-256 校验文件：

```bash
./scripts/package_model_release.sh /path/to/model
```

模型托管优先推荐 Hugging Face；Release 更适合作为固定版本镜像。

## 安全与许可证提示

- 假名化 PDF 不能从输出文件本身复原；授权恢复需要原始文件和单独保存的加密映射。
- 浏览器本地存储中的映射密钥尚未实现跨设备备份，清理应用数据前请谨慎处理。
- PyMuPDF 为 AGPL/商业双许可证。闭源商业分发前需要购买 Artifex 商业许可，或替换为许可证兼容的 PDF 引擎。
- 上游 `RedactionEverything` 仅作架构参考，未确认商业许可前不复制其受限制代码、模型或视觉链路。
- 模型和依赖的再分发许可应在每次发布前重新核对。
