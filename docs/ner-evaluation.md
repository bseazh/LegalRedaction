# NER 阶段实现说明

## 标注格式

`test-data/ner-gold.jsonl` 每行一个样本，包含 `text` 和实体数组。实体使用 Python 半开区间 `[start, end)`，这样评估可以严格检查值和位置。

## 运行规则基线

```bash
python3 -m service.evaluate test-data/ner-gold.jsonl
```

当前脚本会同时输出 `rules`、`ner`、`hybrid` 三个栏位；其中 `ner` 和 `hybrid` 暂时为空/等同规则基线，直到配置实际 NER 后端。这样不会把规则结果误报成模型结果。

## 模型接入顺序

1. 先用本地 OpenAI-compatible HaS 服务接入 `OpenAICompatibleBackend`，验证 HaS 的输出格式和中文实体效果。
2. 再评估 M2 上的 Transformers/ONNX 后端，作为无需独立 vLLM 服务的桌面打包方案。
3. 最后才决定是否把模型权重直接放进 macOS 安装包。

评估必须按实体类型统计，并记录 exact span 的 precision、recall、F1、处理时延和内存；不能只看模型返回了多少实体。

