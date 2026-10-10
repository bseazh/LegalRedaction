#!/bin/zsh
cd "$(dirname "$0")"
chmod +x scripts/*.sh
./scripts/test-macos.sh
status=$?
print "按回车键关闭窗口。"
read -r
exit $status
