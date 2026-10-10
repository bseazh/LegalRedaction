# 环境要求

## 通用要求

- Git、稳定网络和至少 10GB 可用磁盘；
- Node.js 24 LTS（20–24 可用于开发验证）；
- Python 3.11；
- 端口 `3000/8000/8080/8082/8090` 未被不相关程序占用；
- 模型权重不得提交到 Git，用户文件和输出不得上传到公共仓库。

## macOS

- 推荐 Apple Silicon（M1/M2/M3/M4）；
- standard 建议 16GB 内存，full 建议 24GB 以上；
- OCR 使用 Mac CPU 兼容模式；
- HaS 可通过 llama.cpp/Metal 运行；
- LocateAnything 可尝试 MPS，但属于兼容路径，速度和算子支持不等同于 NVIDIA CUDA。

Intel Mac 建议只使用 basic。强制运行重型模型可能非常慢。

## Windows

- Windows 10 22H2 或 Windows 11；
- standard/full 需要 WSL2；
- full 推荐 NVIDIA GPU、16GB 显存和匹配的驱动/CUDA；
- Docker Desktop 可选，但不能代替模型权重和 GPU 驱动检查。

## 许可证要求

安装 Agent 必须先确认使用性质：个人非商用、机构评估或生产使用。若是机构生产、付费交付或商业集成，必须停止自动安装并提示用户核对商业授权。
