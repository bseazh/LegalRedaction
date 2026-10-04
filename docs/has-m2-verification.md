# HaS Text 在当前 M2/16GB 环境的验证记录

日期：2026-10-04

## 已确认

| 项目 | 结果 |
|---|---|
| 当前设备 | Apple M2、16GB、arm64 |
| macOS | 14.8.1 (23J30) |
| HaS FP16 模型 | 约 1.2GB；模型卡标注 MIT；运行内存约 2.4GB |
| HaS Q4_K_M | 约 397MB；模型卡标注 Apache-2.0；运行内存约 1.29GB |
| HaS Q8_0 | 约 639MB；模型卡标注 Apache-2.0；模型卡推荐生产使用 |
| 官方速度数据 | M4 Pro 数据，不可直接当作 M2 实测 |
| 当前可用磁盘 | 约 4.6–5.0GB；不适合同时下载多个权重和编译大型运行时 |
| 模型输出协议 | 官方 prompt 是文本生成，不是原生 JSON NER；必须做 JSON/实体值/offset 校验 |

## 本次实测状态

尚未取得真实 tok/s、首轮加载时长和模型进程 RSS。原因是当前 macOS 14 的 Homebrew 安装 `llama.cpp` 在源码拉取阶段卡住，已停止；不能把官方 M4 Pro benchmark 伪装成 M2 结果。

2026-10-04 已将 FP16 模型下载至本项目 `models/has/HaS_Text_0209_0.6B/`，并完成 SHA-256 校验记录。模型权重不会提交到源码仓库。

## 推荐实测方案

在 `llama-server` 能运行后执行：

```bash
python3 -m service.benchmark_ner \
  --model HaS_Text_0209_0.6B_Q4_K_M \
  --output test-results/has-m2-q4.json
```

同时记录：

- 首次加载时间；
- 连续 5 次请求延迟；
- tokens/s（从 llama-server 日志读取）；
- 模型进程峰值内存；
- MPS/Metal 是否启用；
- 输出 JSON 是否可解析；
- 每个实体 value 是否能在原文唯一定位；
- offset 是否与 Python 半开区间一致；
- 同一实体多次出现时 ID 是否稳定。

## 当前决策

1. 不下载 FP16 权重；当前设备磁盘空间不适合做第一轮验证。
2. 先测试 Q4；若召回率或结构化输出不稳定，再测试 Q8。
3. Q4/Q8 模型卡许可允许作为候选内部试用组件，但正式打包前仍要保留模型卡、上游 base model 条款和版权声明。
4. 模型输出不能直接进入脱敏流程。必须经过 schema 校验、offset 校验、规则交叉验证和人工确认。
5. 即使模型内存约 1.3GB，桌面软件仍需测“模型 + OCR + Tauri + 文档解析”同时运行时的峰值，而不能只看模型单独 RSS。
