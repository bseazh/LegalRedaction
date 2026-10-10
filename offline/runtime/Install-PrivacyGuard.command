#!/bin/zsh
cd "$(dirname "$0")"
chmod +x install-offline-macos.sh scripts/*.sh ./*.command
./install-offline-macos.sh
status=$?
if (( status == 0 )); then
  print "安装成功。现在可以双击 Launch-PrivacyGuard.command 启动。"
else
  print -u2 "安装失败。请保留本窗口内容并交给安装 Agent 排查。"
fi
print "按回车键关闭窗口。"
read -r
exit $status
