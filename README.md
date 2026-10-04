# LegalRedaction

律师本地脱敏桌面软件的独立工作目录。

## 当前目标

第一版做成 macOS / Windows 可下载安装、开箱即用的本地脱敏工作台：

- 原始文件和映射表默认不离开本机；
- 支持 DOCX、可复制文字的 PDF、TXT，随后加入图片和扫描 PDF；
- 规则识别与本地语义识别结合；
- 支持人工确认、Token 化和安全版本导出；
- 不要求用户安装 Python、CUDA、模型或命令行工具。

## 上游参考

参考资料位于：

`../000-Assets/DataInfra-RedactionEverything-main`

该仓库仅作为架构、流程和测试样例参考。未确认商业许可前，不复制其受限制的源码、模型或视觉链路。

## 初始目录

```text
LegalRedaction/
├── README.md
├── docs/                 # 产品和技术决策
├── app/                  # Tauri 桌面应用（后续建立）
├── service/              # 本地 Python 服务（后续建立）
├── models/               # 仅存放已确认可再分发的模型
├── rules/                # 法律场景规则与 schema
├── test-data/            # 脱敏后的测试材料，不放真实案件文件
└── packaging/            # macOS / Windows 打包配置
```

## 当前许可证风险

- 上游 RedactionEverything：Personal Use License，不可默认用于律所生产或商业集成。
- LocateAnything-3B：上游标注为 NVIDIA non-commercial，不纳入商业版候选方案。
- PyMuPDF：AGPL-3.0；商业分发前需购买 Artifex 商业许可，或改用已确认许可的 PDF 方案。
- HaS Text、PaddleOCR 等仍需逐项核对当前模型卡、依赖版本和再分发条款。

## 第一阶段不做

- 系统级 HTTPS 代理；
- LocateAnything-3B 等重型视觉模型；
- 企业多用户、云端管理后台；
- 要求律师手动下载模型或配置运行环境。

