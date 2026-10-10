#!/bin/zsh
set -u

for label in \
  com.bigapple.redaction.app \
  com.bigapple.redaction.has \
  com.bigapple.redaction.ocr \
  com.bigapple.redaction.locate \
  com.bigapple.redaction.locatemps
do
  launchctl remove "$label" >/dev/null 2>&1 || true
done
print "PrivacyGuard 已停止。其他软件的进程不会被结束。"
