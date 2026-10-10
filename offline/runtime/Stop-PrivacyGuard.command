#!/bin/zsh
cd "$(dirname "$0")"
chmod +x scripts/*.sh
./scripts/stop-macos.sh
print "按回车键关闭窗口。"
read -r
