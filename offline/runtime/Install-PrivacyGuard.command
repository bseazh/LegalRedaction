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
python_ready() {
  [[ -x /Library/Frameworks/Python.framework/Versions/3.11/bin/python3.11 ]] || \
    [[ -x /opt/homebrew/bin/python3.11 ]] || command -v python3.11 >/dev/null 2>&1
}
if ! python_ready; then
  python_installer="$PWD/prerequisites/python-3.11.9-macos11.pkg"
  if [[ ! -f "$python_installer" ]]; then
    print -u2 "缺少包内 Python 3.11 安装器：$python_installer"
    exit 1
  fi
  print "未检测到 Python 3.11，正在打开包内官方安装器。请按安装器提示完成授权。"
  /usr/bin/open -W "$python_installer"
  if ! python_ready; then
    print -u2 "Python 3.11 仍未安装，已停止后续步骤。完成安装后可重新双击本文件。"
    exit 1
  fi
  print "Python 3.11 安装完成，继续离线安装。"
fi
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
