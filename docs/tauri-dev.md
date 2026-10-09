# Tauri 原型开发说明

当前已建立 macOS Apple Silicon 原型骨架。开发机还没有 Rust/Cargo，因此暂时只能完成前端和 Python API 静态测试，尚未生成 `.app` 或 `.dmg`。

## 安装一次性依赖

```bash
brew install rustup-init
rustup-init
source "$HOME/.cargo/env"
cd app
npm install
npm install -D @tauri-apps/cli
```

## 启动本地服务和界面

如果 macOS 的 `TMPDIR` 指向无权限的 `/var/folders/...` 路径，先在两个终端都执行：

```bash
mkdir -p /tmp/legalredaction-tmp
chmod 700 /tmp/legalredaction-tmp
export TMPDIR=/tmp/legalredaction-tmp
```

终端 1：

```bash
cd /path/to/PrivacyGuard
. .venv-mlx/bin/activate
python3 -m service.local_api
```

终端 2：

```bash
cd /path/to/PrivacyGuard/app
npm run tauri dev
```

原型支持 TXT、DOCX、有文本层 PDF；模型候选必须点击确认后才会导出。原始文件不会被覆盖。
