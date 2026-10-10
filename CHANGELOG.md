# Changelog

## v0.1.1

- Release 资产改为不可变版本，不再覆盖 v0.1.0 文件；
- Windows 与 macOS 双击安装入口强制执行系统、架构、内存、磁盘、依赖、包完整性、SHA-256 和目录写入检查；
- Windows 停止器在结束进程前核对 PID、可执行文件路径、命令行标记和启动时间，避免 PID 复用导致误杀；
- Windows 与 macOS 启动失败时自动清理本次启动的 PrivacyGuard 服务，同时保留诊断日志；
- 安装日志写入 `logs/install.log`，服务检测结果写入 `logs/last-check.json`；
- FAQ 增加预检失败、版本混用、PID 身份不一致、启动失败清理和日志排查说明。

## v0.1.0

- 首个 standard 离线发行；
- 提供 macOS Apple Silicon 与 Windows x64 CPU 兼容运行包；
- 包含 HaS、PaddleOCR、Python 3.11 安装器和离线 wheels；
- 提供双击启动、服务健康检查和端口冲突自动切换。
