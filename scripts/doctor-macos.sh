#!/bin/zsh
set -u

PROFILE="${1:-standard}"
case "$PROFILE" in
  basic|standard|full) ;;
  *) print -u2 "用法：$0 [basic|standard|full]"; exit 64 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FAILURES=0
WARNINGS=0

ok() { print "✅ $1"; }
warn() { WARNINGS=$((WARNINGS + 1)); print "⚠️  $1"; }
fail() { FAILURES=$((FAILURES + 1)); print "❌ $1"; }
has_command() { command -v "$1" >/dev/null 2>&1; }

print "PrivacyGuard macOS 安装检查"
print "档位：$PROFILE"
print "----------------------------------------"

if [[ "$(uname -s)" == "Darwin" ]]; then ok "系统：macOS $(sw_vers -productVersion 2>/dev/null || print unknown)"; else fail "当前系统不是 macOS"; fi
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then ok "架构：Apple Silicon ($ARCH)"; elif [[ "$PROFILE" == "basic" ]]; then warn "架构：Intel Mac；建议仅使用 basic"; else fail "standard/full 推荐 Apple Silicon，当前为 $ARCH"; fi

RAM_BYTES="$(sysctl -n hw.memsize 2>/dev/null || print 0)"
RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
MIN_RAM=8; [[ "$PROFILE" == "standard" ]] && MIN_RAM=16; [[ "$PROFILE" == "full" ]] && MIN_RAM=24
if (( RAM_GB >= MIN_RAM )); then ok "内存：${RAM_GB}GB（要求 ${MIN_RAM}GB）"; else fail "内存：${RAM_GB}GB，$PROFILE 建议至少 ${MIN_RAM}GB"; fi

FREE_KB="$(df -Pk "$ROOT_DIR" | awk 'NR==2 {print $4}')"
FREE_GB=$((FREE_KB / 1024 / 1024))
MIN_DISK=10; [[ "$PROFILE" == "standard" ]] && MIN_DISK=20; [[ "$PROFILE" == "full" ]] && MIN_DISK=35
if (( FREE_GB >= MIN_DISK )); then ok "可用磁盘：${FREE_GB}GB（要求 ${MIN_DISK}GB）"; else fail "可用磁盘：${FREE_GB}GB，$PROFILE 至少需要 ${MIN_DISK}GB"; fi

for cmd in git curl; do has_command "$cmd" && ok "$cmd：$(${cmd} --version 2>/dev/null | head -1)" || fail "缺少 $cmd"; done
if has_command node; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || print 0)"
  (( NODE_MAJOR >= 20 && NODE_MAJOR <= 24 )) && ok "Node.js：$(node --version)" || warn "Node.js：$(node --version)，推荐 24 LTS"
else fail "缺少 Node.js"; fi
has_command npm && ok "npm：$(npm --version)" || fail "缺少 npm"

PYTHON_BIN=""
for candidate in python3.11 python3; do has_command "$candidate" && PYTHON_BIN="$(command -v "$candidate")" && break; done
if [[ -n "$PYTHON_BIN" ]]; then
  PYVER="$($PYTHON_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:2])))' 2>/dev/null)"
  [[ "$PYVER" == "3.11" ]] && ok "Python：$PYVER ($PYTHON_BIN)" || warn "Python：$PYVER；项目推荐 3.11"
else fail "缺少 Python 3.11"; fi
has_command brew && ok "Homebrew：$(brew --version | head -1)" || warn "未安装 Homebrew；自动准备依赖时会需要"

print "----------------------------------------"
[[ -x "$BACKEND_DIR/.venv-mac/bin/python" ]] && ok "应用虚拟环境已存在" || warn "应用虚拟环境尚未安装"
if [[ "$PROFILE" != "basic" ]]; then
  [[ -x "$BACKEND_DIR/.venv-ocr-mac/bin/python" ]] && ok "OCR 虚拟环境已存在" || warn "OCR 虚拟环境尚未安装"
  [[ -f "$BACKEND_DIR/models/has/has_4.0_0.6B.gguf" ]] && ok "HaS GGUF 权重已存在" || warn "HaS GGUF 权重不存在"
fi
if [[ "$PROFILE" == "full" ]]; then
  [[ -x "$BACKEND_DIR/.venv-locate-mac/bin/python" ]] && ok "视觉虚拟环境已存在" || warn "视觉虚拟环境尚未安装"
  [[ -f "$BACKEND_DIR/models/locateanything/LocateAnything-3B-HF/model.safetensors.index.json" ]] && ok "LocateAnything 权重已存在" || warn "LocateAnything 权重不完整或不存在"
fi

for port in 3000 8000 8080 8082 8090; do
  owner="$(lsof -nP -iTCP:$port -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1" (PID "$2")"}')"
  [[ -n "$owner" ]] && warn "端口 $port 已监听：$owner（若为本项目服务可忽略）" || ok "端口 $port 可用"
done

print "----------------------------------------"
print "结果：失败 $FAILURES 项，提醒 $WARNINGS 项"
if (( FAILURES > 0 )); then
  print "结论：当前不满足 $PROFILE 的硬性要求。请先处理 ❌ 项。"
  exit 2
fi
print "结论：硬件和基础工具满足 $PROFILE；⚠️ 项属于待安装/待确认内容。"
print "下一步：阅读 docs/installation/macos.md"
