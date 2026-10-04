# AI 辅助标注操作方式

## 一键生成候选

```bash
cd /Users/Apple/Documents/Project/Ryan/Law/002-Anonymize/LegalRedaction
python3 -m service.assist_annotation
```

输出：`test-results/real-annotation-assisted.jsonl`。

## 字段含义

- `sources=["rules","fp16_ner"]`：两个识别器完全重合，属于高置信候选，但仍不是 gold；
- `sources=["fp16_ner"]`：模型独有候选，必须人工检查；
- `sources=["rules"]`：规则独有候选，检查是否为真实敏感实体；
- `human_status=pending`：尚未确认；
- `gold_entities`：最终人工确认后的实体集合。

## 人工最小工作量

优先检查：

1. 只有 FP16 NER 识别出的姓名、组织、地址；
2. 规则与模型边界不一致的号码、案号、合同编号；
3. 会改变主体、金额、日期或法律事实的候选；
4. 模型完全没有识别、但人工阅读后发现的实体。

确认后把实体写入 `gold_entities`，并将文件的 `review_status` 改为 `confirmed`。如果拒绝候选，不要放入 `gold_entities`，在 `review_notes` 说明原因。

## AI 模拟报告

```bash
python3 -m service.evaluate_simulated
```

该报告只统计候选覆盖和规则/模型分歧，不能作为 precision、recall 或 F1。只有人工确认至少 100 个实体后，才运行 `service.evaluate_real` 生成真实指标。

