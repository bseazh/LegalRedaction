# macOS 安装

## standard 离线安装入口

- [macOS Apple Silicon 专用下载页](https://privacyguard.snorlaxden.fun/offline-standard-v0.1.0/macos.html)
- [GitHub Release 备用源](https://github.com/bseazh/PrivacyGuard/releases/tag/offline-standard-v0.1.0)

专用页只列出 macOS 所需的运行包、HaS、PaddleOCR 和 `SHA256SUMS`。当前离线运行包仅适用于 Apple Silicon，不适用于 Intel Mac。

## 1. 检查机器

```bash
./scripts/doctor-macos.sh standard
```

重点确认：Apple Silicon、内存、磁盘、Python 3.11、Node.js、Homebrew，以及模型目录状态。

## 2. 安装基础工具

```bash
xcode-select --install
brew install git python@3.11 node@24 cmake pkg-config
```

## 3. 安装前端

```bash
npm --prefix frontend ci
```

## 4. Python 环境

macOS 运行版使用三个隔离环境：

- `backend/.venv-mac`：FastAPI 与 HaS/llama.cpp；
- `backend/.venv-ocr-mac`：PaddleOCR CPU；
- `backend/.venv-locate-mac`：LocateAnything/MPS，仅 full 需要。

依赖体积大且模型许可不同，建议由 Agent 按 [agent-guide.md](./agent-guide.md) 执行，并在每一步后运行导入测试。不要把三个环境合并，否则 Paddle、Torch 和模型依赖容易冲突。

## 5. 模型

按 [models.md](./models.md) 放置权重。standard 至少需要 HaS GGUF；full 还需要 LocateAnything。

## 6. 启动与停止

```bash
./scripts/start-macos.sh
./scripts/stop-macos.sh
```

启动后访问：

- 应用/API：`http://127.0.0.1:8000`
- 服务状态：`http://127.0.0.1:8000/health/services`

视觉服务显示离线不一定阻塞 basic/standard，但必须与用户选择的档位一致。
