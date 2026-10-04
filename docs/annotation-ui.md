# 本地标注界面

## 启动

先生成 AI 辅助候选：

```bash
cd /Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/LegalRedaction
python3 -m service.assist_annotation
python3 -m service.annotation_ui
```

然后在本机浏览器打开：

`http://127.0.0.1:8765`

## 支持操作

- 按文件切换；
- 查看原文和候选实体；
- 确认候选进入 `gold_entities`；
- 忽略误报；
- 修改类型、值和 span；
- 手动补充模型漏掉的实体；
- 每次操作自动保存到 `test-results/real-annotation-assisted.jsonl`。

服务只绑定 `127.0.0.1`，不监听局域网，不提供外部访问接口。

## 完成标注

确认所有文件后运行：

```bash
python3 -m service.evaluate_real
```

只有 `review_status=confirmed` 且至少存在一个经过校验的 gold 实体时，才会生成真实评估指标。样本量较小时，报告会明确标注为内部方向性结果。
