#!/bin/zsh
cd "$(dirname "$0")"
chmod +x scripts/*.sh
./scripts/start-macos.sh
launch_status=$?
(( launch_status == 0 )) || print -u2 "启动未完成，请双击 Test-PrivacyGuard.command 查看状态。"
print "按回车键关闭窗口。"
read -r
exit $launch_status
