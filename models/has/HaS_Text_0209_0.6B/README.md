---
license: mit
language:
  - zh
  - en
  - pt
  - fr
  - es
  - de
  - ko
  - ja
tags:
  - privacy
  - anonymization
  - ner
  - pii
  - hide-and-seek
  - on-device
  - qwen3
base_model: Qwen/Qwen3-0.6B-Base
pipeline_tag: text-generation
---

# HaS Text Model (Full Precision)

**HaS (Hide and Seek)** is an on-device privacy model providing a complete pipeline from entity recognition to anonymization and restoration.

- 📦 **0.6B parameters**, full precision (FP16), 1.2 GB
- 🔒 **Data never leaves device** — local inference, no network required
- 🌍 **8 languages natively supported**: Chinese, English, Portuguese, French, Spanish, German, Korean, Japanese
- ⚡ **Apple M4 Pro benchmark**: prefill ~4,900 tok/s (llama.cpp), decode ~156 tok/s (mlx_lm)

> This is the **full-precision base model** for fine-tuning and research. For production deployment, use the quantized versions: [Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8) (recommended) or [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4).

## 1. Core Capabilities

Traditional anonymization (regex, Presidio, etc.) only does pattern matching. HaS is an **on-device Agentic privacy pipeline** — a set of composable atomic capabilities that solve multi-turn consistency, reversible restoration, and post-anonymization data usability.

| Capability | Description |
|------------|-------------|
| **3-Level Semantic Tags** | Instead of `[REDACTED]`, produces tags like `<Amount[1].ContractAmount.NumberSymbol>` — LLMs understand "this is a contract amount", preserving data usability |
| **Coreference Resolution** | "CloudGenius Inc.", "CloudGenius", "云创智能" → all unified as `<Organization[1].Company.Name>`. Different forms, same ID |
| **Multi-turn Consistency** | Carries historical mapping dictionaries for incremental anonymization. Entity IDs stay consistent across turns. Same mechanism supports recursive chunking for long documents |
| **Reversible Restoration** | Anonymized text can be processed by cloud LLMs (translation, rewriting, etc.), then Seek restores the tags back to original values |
| **Open-set Entity Types** | Trained on ~70,000 entity types. Users can freely specify any type name without being limited to predefined categories |
| **Public/Private Distinction** | "Industrial and Commercial Bank of China" preserved, "Li Hong 138-xxxx" anonymized — only redacts what should be redacted |

## 2. Six Atomic Capabilities

| # | Capability | Description |
|---|------------|-------------|
| 1 | **NER** | Recognize named entities of specified types |
| 2 | **Hide_with** | Anonymize using an existing mapping dictionary (maintains cross-text consistency) |
| 3 | **Hide_without** | First-time anonymization (no mapping, model generates tags autonomously) |
| 4 | **Pair** | Extract mapping relationships from original and anonymized text pairs |
| 5 | **Split** | Split composite tags into atomic single-entity mappings |
| 6 | **Seek** | Restore tagged text using a mapping dictionary |

## 3. Structured Semantic Tags & Coreference Resolution

### 3-Level Semantic Tags

Tags use a `<EntityType[ID].Category.Attribute>` three-level structure:

```
<Address[1].City.CityName>             ← identifies this as a city name
<Address[2].StreetAddress.FullAddress>  ← identifies this as a detailed address
<Amount[1].ContractAmount.NumberSymbol> ← identifies this as a contract amount
<Phone[1].Mobile.FullNumber>           ← identifies this as a mobile number
```

Comparison with traditional approaches:

| Traditional | HaS 3-Level Tag |
|-------------|-----------------|
| `[ADDRESS]` | `<Address[1].City.CityName>` |
| `[ADDRESS]` | `<Address[2].StreetAddress.FullAddress>` |
| `[MONEY]` | `<Amount[1].ContractAmount.NumberSymbol>` |

### Coreference Resolution

The same entity often appears in multiple forms. HaS automatically recognizes they refer to the same object and unifies them under one ID:

```
Original forms               Unified tag
───────────────────           ───────────────────────
CloudGenius Inc.          →   <Organization[1].Company.Name>
CloudGenius               →   <Organization[1].Company.Name>
云创智能                   →   <Organization[1].Company.Name>
CG                        →   <Organization[1].Company.Name>
```

This ensures anonymized text remains logically coherent — LLMs seeing multiple `<Organization[1]>` know it's the same company. Critical for multi-turn conversations and long document chunking: entity IDs remain globally consistent across turns and chunks.

## 4. Quick Start

Recommended deployment with llama.cpp:

```bash
llama-server -m has_text_model.gguf -ngl 999 -c 8192 -np 1 -fa on
```

- Listens on `http://127.0.0.1:8080/v1` by default
- OpenAI Chat Completions compatible API
- ~**2.4 GB** total memory with default settings

## 5. Usage Scenarios

The 6 atomic capabilities can be composed into various privacy pipelines:

| Scenario | Description | Capabilities Used |
|----------|-------------|-------------------|
| **Redacted Sharing** | Auto-anonymize files, emails, code before sending; retain mapping for restoration | Hide → Pair |
| **Privacy Scanning** | Scan files/directories, list all sensitive entities, assess exposure risk | NER |
| **Privacy Knowledge Base** | Anonymize documents before ingestion; restore query results via mapping | Hide → Pair (write), Seek (read) |
| **Log Redaction** | Batch-anonymize ops logs before handing to support teams | Hide → Pair |
| **Secure Cloud Chat** | Anonymize text before sending to cloud LLM; restore LLM responses | NER → Hide → Pair → Seek |
| **AI Memory Privacy** | Store Agent long-term memory in anonymized form; restore on demand | Hide → Pair (store), Seek (recall) |

## 6. Prompt Templates

> ⚠️ **Templates must match character-for-character** — the model was trained on these exact templates. Any deviation may degrade output quality.

### NER

```
Recognize the following entity types in the text.
Specified types:{types_json_array}
<text>{text}</text>
```

### Hide_with (with mapping)

**Turn 1**: Same as NER template

**Turn 2**:
```
Replace the above-mentioned entity types in the text according to the existing mapping pairs:{mapping_json}
```

### Hide_without (without mapping)

**Turn 1**: Same as NER template

**Turn 2** (fixed text, no variables):
```
Replace the above-mentioned entity types in the text.
```

### Pair

```
<original>{original_text}</original>
<anonymized>{anonymized_text}</anonymized>
Extract the mapping from anonymized entities to original entities.
```

### Split

```
Split each composite anonymized key into atomic keys.
Composite mapping:
{composite_mapping_json_array}
```

### Seek

```
The mapping from anonymized entities to original entities:
{mapping_json}
Restore the original text based on the above mapping:
{text_with_tags}
```

## 7. Speed Benchmarks

Test platform: Apple M4 Pro (48 GB RAM)

| Metric | llama.cpp | mlx_lm | mlc_llm |
|--------|:---------:|:------:|:-------:|
| **FP16 model size** | 1.2 GB | 1.2 GB | 1.2 GB |
| **FP16 prefill (tok/s)** | **4,904** | 4,272 | 1,818 |
| **FP16 decode (tok/s)** | 128 | **156** | 118 |
| **Q4 model size** | 0.4 GB | 0.4 GB | 0.4 GB |
| **Q4 prefill (tok/s)** | **4,828** | 3,183 | 2,236 |
| **Q4 decode (tok/s)** | 238 | **345** | 172 |

> All performance figures are rounded. **Bold** indicates best in class.

## 8. Quantization Versions

| Version | Quantization | File Size | Runtime Memory | Notes |
|---------|:---:|:---:|:---:|-------|
| **Full Precision** | FP16 | 1.2 GB | ~2.4 GB | Base model for fine-tuning and research |
| [Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8) | 8.50 BPW | 639 MB | ~1.56 GB | **Recommended for production**, best output quality |
| [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4) | 5.24 BPW | 397 MB | ~1.29 GB | Faster inference, lower memory, for resource-constrained environments |

---

<details>
<summary><b>中文版</b></summary>

# HaS Text Model（全量模型）

**HaS（Hide and Seek）** 是一个端侧部署的隐私模型，提供从实体识别到脱敏还原的完整管线。

- 📦 **0.6B 参数**，全精度（FP16），1.2 GB
- 🔒 **数据不出设备**，本地推理，无需联网
- 🌍 **8 语言原生支持**：中、英、葡、法、西、德、韩、日
- ⚡ **Apple M4 Pro 实测**：prefill ~4,900 tok/s（llama.cpp），decode ~156 tok/s（mlx_lm）

> 这是**全精度基座模型**，适用于微调和研究。生产部署请使用量化版本：[Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8)（推荐）或 [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4)。

## 一、核心能力

传统脱敏方案（正则、Presidio 等）只做模式匹配。HaS 的定位是**端侧 Agentic 隐私管线**——用一组可组合的原子能力解决多轮一致、可逆还原和脱敏后数据可用性的问题。

| 能力 | 说明 |
|------|------|
| **三级语义标签** | 脱敏后不是 `[REDACTED]`，而是 `<金额[1].合同金额.数字符号>` 这样携带语义的标签——LLM 一看就知道"这是一笔合同金额"，保持脱敏后数据可用性 |
| **指代消解** | "云创智能有限公司"、"云创智能"、"CloudGenius"→ 全部归为 `<组织[1].企业.名称>`。不同写法，同一编号 |
| **多轮一致** | 携带历史映射字典做增量脱敏，跨轮次实体编号一致。同一机制支持递归分块处理超长文档 |
| **可逆还原** | 脱敏后的文本可先交给云端 LLM 处理（翻译、改写等），Seek 能对处理后文本中的标签进行还原 |
| **开集指定** | 训练覆盖约 7 万种实体类型，用户可自由指定任意类型名称，不受预定义类别限制 |
| **公私区分** | "中国工商银行"保留，"李红 138-xxxx"脱敏——只脱该脱的，不过度脱敏 |

## 二、6 个原子能力

| # | 能力 | 说明 |
|---|------|------|
| 1 | **NER** | 识别指定类型的命名实体 |
| 2 | **Hide_with** | 使用已有映射字典脱敏（保持跨文本一致） |
| 3 | **Hide_without** | 首次脱敏（无映射，模型自主生成标签） |
| 4 | **Pair** | 从原文和脱敏文本对中提取映射关系 |
| 5 | **Split** | 拆分复合标签为原子单实体映射 |
| 6 | **Seek** | 根据映射字典还原含标签的文本 |

## 三、结构化语义标签与指代消解

### 三级语义标签

脱敏后的标签采用 `<实体类型[编号].分类.属性>` 三级结构：

```
<地址[1].城市.市名>          ← 知道这是一个城市名
<地址[2].街道门牌.完整地址>   ← 知道这是一个详细地址
<金额[1].合同金额.数字符号>   ← 知道这是一笔合同金额，不只是普通数字
<电话[1].手机号.完整号码>     ← 知道这是手机号，不是座机或传真
```

对比传统脱敏方案：

| 传统方案 | HaS 三级标签 |
|---------|-------------|
| `[ADDRESS]` | `<地址[1].城市.市名>` |
| `[ADDRESS]` | `<地址[2].街道门牌.完整地址>` |
| `[MONEY]` | `<金额[1].合同金额.数字符号>` |

### 指代消解

同一实体在文本中往往以多种形式出现。HaS 会自动识别它们指向同一对象，统一归为同一编号：

```
原文中的写法              脱敏后统一为
───────────────────       ───────────────────────
云创智能科技有限公司   →   <组织[1].企业.名称>
云创智能              →   <组织[1].企业.名称>
CloudGenius           →   <组织[1].企业.名称>
云创                  →   <组织[1].企业.名称>
```

这确保了脱敏后的文本逻辑自洽——LLM 看到多处 `<组织[1]>` 就知道是同一家公司，而不会误以为是不同实体。在多轮对话和长文档分块中尤为关键：跨轮次、跨分块的实体编号全局一致。

## 四、快速开始

推荐使用 llama.cpp 推理框架：

```bash
llama-server -m has_text_model.gguf -ngl 999 -c 8192 -np 1 -fa on
```

- 默认监听 `http://127.0.0.1:8080/v1`
- API 兼容 OpenAI Chat Completions 格式
- 默认配置下总内存约 **2.4 GB**

## 五、使用场景

6 个原子能力可以组合成多种隐私管线：

| 场景 | 说明 | 使用能力 |
|------|------|----------|
| **脱敏分享** | 文件、邮件、代码在外发前自动脱敏，保留映射表可随时还原 | Hide → Pair |
| **全量隐私扫描** | 扫描文件或目录，列出所有敏感实体，评估泄露风险 | NER |
| **隐私知识库** | 文档先脱敏再入库，查询结果通过映射表还原原文 | Hide → Pair（写入）、Seek（读取） |
| **日志脱敏** | 运维日志在交给支持团队前批量脱敏 | Hide → Pair |
| **安全云端对话** | 脱敏后文本发给云端 LLM 处理，LLM 返回结果再还原 | NER → Hide → Pair → Seek |
| **AI 记忆隐私** | Agent 的长期记忆以脱敏形式存储，使用时按需还原 | Hide → Pair（存储）、Seek（召回） |

## 六、提示词模板

> ⚠️ **模板必须逐字符精确匹配**，模型基于这些模板训练。任何偏差（空格、换行、标点）都可能降低输出质量。

### NER

```
Recognize the following entity types in the text.
Specified types:{types_json_array}
<text>{text}</text>
```

### Hide_with（带映射脱敏）

**第 1 轮**：与 NER 模板相同

**第 2 轮**：

```
Replace the above-mentioned entity types in the text according to the existing mapping pairs:{mapping_json}
```

### Hide_without（无映射脱敏）

**第 1 轮**：与 NER 模板相同

**第 2 轮**（固定文本，无变量）：

```
Replace the above-mentioned entity types in the text.
```

### Pair（提取映射）

```
<original>{original_text}</original>
<anonymized>{anonymized_text}</anonymized>
Extract the mapping from anonymized entities to original entities.
```

### Split（拆分复合标签）

```
Split each composite anonymized key into atomic keys.
Composite mapping:
{composite_mapping_json_array}
```

### Seek（还原）

```
The mapping from anonymized entities to original entities:
{mapping_json}
Restore the original text based on the above mapping:
{text_with_tags}
```

## 7. Speed Benchmarks

Test platform: Apple M4 Pro (48 GB RAM)

| Metric | llama.cpp | mlx_lm | mlc_llm |
|--------|:---------:|:------:|:-------:|
| **FP16 model size** | 1.2 GB | 1.2 GB | 1.2 GB |
| **FP16 prefill (tok/s)** | **4,904** | 4,272 | 1,818 |
| **FP16 decode (tok/s)** | 128 | **156** | 118 |
| **Q4 model size** | 0.4 GB | 0.4 GB | 0.4 GB |
| **Q4 prefill (tok/s)** | **4,828** | 3,183 | 2,236 |
| **Q4 decode (tok/s)** | 238 | **345** | 172 |

> All performance figures are rounded. **Bold** indicates best in class.

## 8. Quantization Versions

| Version | Quantization | File Size | Runtime Memory | Notes |
|---------|:---:|:---:|:---:|-------|
| **Full Precision** | FP16 | 1.2 GB | ~2.4 GB | Base model for fine-tuning and research |
| [Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8) | 8.50 BPW | 639 MB | ~1.56 GB | **Recommended for production**, best output quality |
| [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4) | 5.24 BPW | 397 MB | ~1.29 GB | Faster inference, lower memory, for resource-constrained environments |

---

<details>
<summary><b>中文版</b></summary>

# HaS Text Model（全量模型）

**HaS（Hide and Seek）** 是一个端侧部署的隐私模型，提供从实体识别到脱敏还原的完整管线。

- 📦 **0.6B 参数**，全精度（FP16），1.2 GB
- 🔒 **数据不出设备**，本地推理，无需联网
- 🌍 **8 语言原生支持**：中、英、葡、法、西、德、韩、日
- ⚡ **Apple M4 Pro 实测**：prefill ~4,900 tok/s（llama.cpp），decode ~156 tok/s（mlx_lm）

> 这是**全精度基座模型**，适用于微调和研究。生产部署请使用量化版本：[Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8)（推荐）或 [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4)。

## 一、核心能力

传统脱敏方案（正则、Presidio 等）只做模式匹配。HaS 的定位是**端侧 Agentic 隐私管线**——用一组可组合的原子能力解决多轮一致、可逆还原和脱敏后数据可用性的问题。

| 能力 | 说明 |
|------|------|
| **三级语义标签** | 脱敏后不是 `[REDACTED]`，而是 `<金额[1].合同金额.数字符号>` 这样携带语义的标签——LLM 一看就知道"这是一笔合同金额"，保持脱敏后数据可用性 |
| **指代消解** | "云创智能有限公司"、"云创智能"、"CloudGenius"→ 全部归为 `<组织[1].企业.名称>`。不同写法，同一编号 |
| **多轮一致** | 携带历史映射字典做增量脱敏，跨轮次实体编号一致。同一机制支持递归分块处理超长文档 |
| **可逆还原** | 脱敏后的文本可先交给云端 LLM 处理（翻译、改写等），Seek 能对处理后文本中的标签进行还原 |
| **开集指定** | 训练覆盖约 7 万种实体类型，用户可自由指定任意类型名称，不受预定义类别限制 |
| **公私区分** | "中国工商银行"保留，"李红 138-xxxx"脱敏——只脱该脱的，不过度脱敏 |

## 二、6 个原子能力

| # | 能力 | 说明 |
|---|------|------|
| 1 | **NER** | 识别指定类型的命名实体 |
| 2 | **Hide_with** | 使用已有映射字典脱敏（保持跨文本一致） |
| 3 | **Hide_without** | 首次脱敏（无映射，模型自主生成标签） |
| 4 | **Pair** | 从原文和脱敏文本对中提取映射关系 |
| 5 | **Split** | 拆分复合标签为原子单实体映射 |
| 6 | **Seek** | 根据映射字典还原含标签的文本 |

## 三、结构化语义标签与指代消解

### 三级语义标签

脱敏后的标签采用 `<实体类型[编号].分类.属性>` 三级结构：

```
<地址[1].城市.市名>          ← 知道这是一个城市名
<地址[2].街道门牌.完整地址>   ← 知道这是一个详细地址
<金额[1].合同金额.数字符号>   ← 知道这是一笔合同金额，不只是普通数字
<电话[1].手机号.完整号码>     ← 知道这是手机号，不是座机或传真
```

对比传统脱敏方案：

| 传统方案 | HaS 三级标签 |
|---------|-------------|
| `[ADDRESS]` | `<地址[1].城市.市名>` |
| `[ADDRESS]` | `<地址[2].街道门牌.完整地址>` |
| `[MONEY]` | `<金额[1].合同金额.数字符号>` |

### 指代消解

同一实体在文本中往往以多种形式出现。HaS 会自动识别它们指向同一对象，统一归为同一编号：

```
原文中的写法              脱敏后统一为
───────────────────       ───────────────────────
云创智能科技有限公司   →   <组织[1].企业.名称>
云创智能              →   <组织[1].企业.名称>
CloudGenius           →   <组织[1].企业.名称>
云创                  →   <组织[1].企业.名称>
```

这确保了脱敏后的文本逻辑自洽——LLM 看到多处 `<组织[1]>` 就知道是同一家公司，而不会误以为是不同实体。

## 四、快速开始

推荐使用 llama.cpp 推理框架：

```bash
llama-server -m has_text_model.gguf -ngl 999 -c 8192 -np 1 -fa on
```

- 默认监听 `http://127.0.0.1:8080/v1`
- API 兼容 OpenAI Chat Completions 格式
- 默认配置下总内存约 **2.4 GB**

## 五、使用场景

6 个原子能力可以组合成多种隐私管线：

| 场景 | 说明 | 使用能力 |
|------|------|----------|
| **脱敏分享** | 文件、邮件、代码在外发前自动脱敏，保留映射表可随时还原 | Hide → Pair |
| **全量隐私扫描** | 扫描文件或目录，列出所有敏感实体，评估泄露风险 | NER |
| **隐私知识库** | 文档先脱敏再入库，查询结果通过映射表还原原文 | Hide → Pair（写入）、Seek（读取） |
| **日志脱敏** | 运维日志在交给支持团队前批量脱敏 | Hide → Pair |
| **安全云端对话** | 脱敏后文本发给云端 LLM 处理，LLM 返回结果再还原 | NER → Hide → Pair → Seek |
| **AI 记忆隐私** | Agent 的长期记忆以脱敏形式存储，使用时按需还原 | Hide → Pair（存储）、Seek（召回） |

## 六、提示词模板

> ⚠️ **模板必须逐字符精确匹配**，模型基于这些模板训练。任何偏差（空格、换行、标点）都可能降低输出质量。

### NER

```
Recognize the following entity types in the text.
Specified types:{types_json_array}
<text>{text}</text>
```

### Hide_with（带映射脱敏）

**第 1 轮**：与 NER 模板相同

**第 2 轮**：

```
Replace the above-mentioned entity types in the text according to the existing mapping pairs:{mapping_json}
```

### Hide_without（无映射脱敏）

**第 1 轮**：与 NER 模板相同

**第 2 轮**（固定文本，无变量）：

```
Replace the above-mentioned entity types in the text.
```

### Pair（提取映射）

```
<original>{original_text}</original>
<anonymized>{anonymized_text}</anonymized>
Extract the mapping from anonymized entities to original entities.
```

### Split（拆分复合标签）

```
Split each composite anonymized key into atomic keys.
Composite mapping:
{composite_mapping_json_array}
```

### Seek（还原）

```
The mapping from anonymized entities to original entities:
{mapping_json}
Restore the original text based on the above mapping:
{text_with_tags}
```

## 七、速度评估

测试平台：Apple M4 Pro（48 GB 内存）

| 指标 | llama.cpp | mlx_lm | mlc_llm |
|------|:---------:|:------:|:-------:|
| **FP16 模型大小** | 1.2 GB | 1.2 GB | 1.2 GB |
| **FP16 prefill（tok/s）** | **4,904** | 4,272 | 1,818 |
| **FP16 decode（tok/s）** | 128 | **156** | 118 |
| **Q4 模型大小** | 0.4 GB | 0.4 GB | 0.4 GB |
| **Q4 prefill（tok/s）** | **4,828** | 3,183 | 2,236 |
| **Q4 decode（tok/s）** | 238 | **345** | 172 |

> 所有性能数据均已取整。**粗体**表示该项最佳表现。

## 八、量化版本

| 版本 | 量化 | 文件大小 | 运行内存 | 说明 |
|------|:---:|:---:|:---:|------|
| **全量模型** | FP16 | 1.2 GB | ~2.4 GB | 基座模型，适用于微调和研究 |
| [Q8_0](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q8) | 8.50 BPW | 639 MB | ~1.56 GB | **推荐生产使用**，输出质量最佳 |
| [Q4_K_M](https://huggingface.co/xuanwulab/HaS_Text_0209_0.6B_Q4) | 5.24 BPW | 397 MB | ~1.29 GB | 推理更快，内存更省，适合资源受限场景 |

</details>
