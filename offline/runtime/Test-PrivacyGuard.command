#!/bin/zsh
cd "$(dirname "$0")"
chmod +x scripts/*.sh
./scripts/test-macos.sh
test_status=$?
print "按回车键关闭窗口。"
read -r
exit $test_status
