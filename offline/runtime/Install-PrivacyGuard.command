#!/bin/zsh
cd "$(dirname "$0")"
chmod +x install-offline-macos.sh scripts/*.sh ./*.command
mkdir -p logs
exec > >(tee -a logs/install.log) 2>&1
print "[1/2] 正在执行安装前强制检查..."
PRIVACYGUARD_INSTALL_GATE=1 PRIVACYGUARD_PACKAGE_DIR="$(cd .. && pwd)" ./check-offline-macos.sh "$PWD"
preflight_status=$?
if (( preflight_status != 0 )); then
  print -u2 "安装前检查未通过，已停止安装。请根据 FAIL 项处理，FAQ 位于 docs/installation/faq.md。"
  print "按回车键关闭窗口。"
  read -r
  exit $preflight_status
fi
print "[2/2] 预检通过，开始离线安装。"
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
