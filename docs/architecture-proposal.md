# 笼养动物健康管理 — 插件化架构提案（已采纳）

> 状态：**Accepted / 已采纳**（经负责人 2026-08-18 确认）。本文借鉴 DeepSeek Harness（`dsh`）的「一切皆插件」思想；核心决策已通过 `docs/decisions/0001-*.md` 至 `0005-*.md` 记录并转正，摘要已并入 `docs/architecture.md`。
> 参考来源：`docs/project-background.md`（愿景讨论）、`docs/architecture.md`（现状）、DeepSeek Harness 仓库 `docs/architecture.md` / `docs/cordis-primer.md` / `docs/capability-seams.md`。

---

## 1. 摘要

本提案把 `project-background.md` 中的五层技术结构（`摄像头采集 → 鸟检测与追踪 → 行为事件识别 → 个体基线 → 大模型解释层`）映射为**五个能力接缝（capability seam）**，并为整个系统确立一条**唯一事实来源**：append-only 的**行为事件日志**。

核心主张有三条：

1. **行为事件日志是唯一事实来源**：日报、个体基线、异常提醒、兽医报告都是从事件流投影出来的「视图」，不是独立存储的状态。
2. **每个算法/模型/数据源都是可替换的 Provider**：换 Provider 不动业务代码，从而支持「脚环识别失败可回退整体笼态」「摄像头无关」「从鹦鹉扩展到其他笼养动物」。
3. **个体基线 = 每只鸟的 scope**：per-bird 基线覆盖（shadow）全局默认基线，实现「和这只鸟自己比」的产品壁垒。

引擎层（Python/CV）用「抽象基类 + 注册表」落地接缝，**暂不引入 Cordis**；编排层复杂度上升后再单独评估。

---

## 2. 背景与目标

### 2.1 现状

- 仓库当前只有协作层文档与 `DSH Mac Client/`，**尚无业务代码、数据模型或正式需求文档**。
- 愿景已沉淀于 `docs/project-background.md`：以牡丹鹦鹉为切入点，做「Oura Ring + 家庭监控管家」式的行为日报与异常提醒工具。
- MVP 范围（讨论稿）：**三项识别（食盆访问、活动量/长时间静止、多鸟互动）+ 一份日报 + 异常视频回看**。

### 2.2 本提案要解决的设计问题

- 如何让「摄像头无关」「个体识别可降级」「行为种类可渐进扩展」这些战略在代码结构上成立，而不是靠临时堆功能。
- 如何满足 `docs/architecture.md` 中的非功能要求：**可追溯、可复核、最小权限、可移植、可验证**。

---

## 3. 从 dsh 到本项目的思想映射

| dsh 的概念 | 本项目对应物 | 收益 |
|---|---|---|
| **capability seam**（Definition / Provider / Consumer 三件套） | 五个管道层各自成为接缝 | 换 Provider 不动 Consumer，支持渐进上线与安全回退 |
| **Session log = 唯一事实来源**（"Model-visible ⟺ logged"） | 行为事件日志 | 可追溯、可重放、可审计 |
| **Provider 注册到 `ctx.<key>`，靠 `inject` 声明依赖** | Python 抽象基类 + 注册表 | 加载顺序由依赖表达，不手写启动顺序 |
| **scope + shadowing**（per-agent 覆盖全局） | per-bird 基线覆盖全局基线 | 实现「和这只鸟自己比」 |
| **approval 接缝 fail-closed** | 健康预警/处置的人工复核接缝，无审批者即拒绝 | 满足「可复核」「最小权限」 |
| **skill 系统** | `agent/skills/` 下的日报/兽医报告/异常回看 SOP | 厂商无关，可被 DSH/Codex/Claude Code 复用 |

> 关键取舍：**学思想，不照搬框架。** Cordis 是 TypeScript 生态的 DI 框架，而引擎核心是 Python/CV。下文第 8 节说明为何引擎层用 Python 惯用法而非 Cordis。

---

## 4. 总体架构

```text
┌─────────────────────────────────────────────────────────────┐
│  编排/产品层（可选，长期再评估是否引入 dsh/Cordis）            │
│  profile 组合 · skill · 通知调度 · 日报调度 · 审计 · 订阅       │
└───────────────────────────┬─────────────────────────────────┘
                            │ 消费「事件日志 + 接缝服务」
┌───────────────────────────▼─────────────────────────────────┐
│  引擎层（Python，核心资产）                                     │
│                                                              │
│   capture ──> detect ──> behavior ──> baseline ──> explain   │
│   (接缝1)      (接缝2)     (接缝3)       (接缝4)      (接缝5)   │
│                                                              │
│   横切接缝：storage · notify · approval · sandbox · skill      │
└───────────────────────────┬─────────────────────────────────┘
                            │ 只追加写入
┌───────────────────────────▼─────────────────────────────────┐
│  行为事件日志（唯一事实来源，append-only，JSONL 起步）           │
│  日报/基线/提醒/兽医报告 = 从事件流投影出来的视图                │
└─────────────────────────────────────────────────────────────┘
```

数据流：

```text
capture 抽帧 → detect 检测/追踪（含功能区语义）→ behavior 产出结构化事件
→ 事件写入日志 → baseline 从日志聚合个体指标并与历史基线对比
→ explain 把结构化指标翻译成人话日报 → 异常时触发 notify（经 approval 复核）
```

---

## 5. 唯一事实来源：行为事件日志

### 5.1 原则

- **append-only**：事件只追加、不改写、不删除；纠正用「补偿事件」而非修改历史。
- **可重放**：换规则或模型后，可从原始事件（必要时从视频引用）重新投影出新的日报/基线。
- **可追溯**：每条事件携带产生它的 `ruleVersion` 与 `modelVersion`，异常可一路追到「哪条事件 + 哪版规则 + 哪版模型」。

### 5.2 事件信封（envelope）

```json
{
  "seq": 12345,
  "ts": "2026-08-18T11:42:03Z",
  "kind": "behavior.food_visit",
  "birdId": "lumi",
  "cageId": "cage-main",
  "sessionId": "2026-08-18",
  "ruleVersion": "food-visit@1.2.0",
  "modelVersion": "detect-yolo@0.9.3",
  "payload": { "...": "见下表" },
  "videoRef": "file:///data/clips/2026-08-18/clip-000123.mp4",
  "source": "engine@1.0"
}
```

字段约定（草案）：

| 字段 | 含义 | 说明 |
|---|---|---|
| `seq` | 单调递增序号 | 便于去重与顺序 |
| `ts` | UTC 时间戳 | ISO 8601 |
| `kind` | 事件类型（点分命名） | 见 5.3 |
| `birdId` | 个体标识 | 未识别个体时可为 `cage`（整体笼态） |
| `sessionId` | 观察会话（建议按「笼+日」分区） | 便于按天投影日报 |
| `ruleVersion` | 产生本事件的规则版本 | 可追溯 |
| `modelVersion` | 产生本事件的模型版本 | 可追溯 |
| `payload` | 事件特有字段 | 见 5.3 |
| `videoRef` | 关联视频片段引用（非原始视频本体） | 用于「异常回看」 |
| `source` | 产出组件版本 | 运维排障 |

### 5.3 事件类型与 payload（MVP 子集）

```text
capture.frame_dropped      抽帧/采集异常（视频流断连、丢帧）
detect.bird                检测到鸟（位置、功能区、置信度）
detect.zone_enter          进入某功能区（food/water/perch/floor/toy…）
detect.zone_exit           离开某功能区
behavior.food_visit        食盆访问（进入食盆区、停留时长、访问次数）
behavior.activity          活动量（区间内运动强度/位移）
behavior.long_stillness    长时间静止（起止、时长、所在功能区）
behavior.social_interaction 多鸟互动（理毛/追逐/争抢/分开休息，类型标签）
behavior.vocalization      鸣叫/声音异常（时间段、强度、疑似异常标记）
baseline.snapshot          个体基线快照（每日聚合指标，供对比）
report.generated           日报/报告生成（引用输入的事件范围与版本）
alert.raised               异常提醒（引用触发事件、偏差、疑似程度）
review.approved            人工复核结论（谁、何时、结论，可空=未复核）
```

`behavior.food_visit` 示例 payload：

```json
{
  "zone": "food",
  "enteredAt": "2026-08-18T11:42:03Z",
  "exitedAt": "2026-08-18T11:42:51Z",
  "durationSeconds": 48,
  "visitIndex": 3,
  "confidence": 0.91
}
```

`alert.raised` 示例 payload（体现「疑似」而非「确定诊断」）：

```json
{
  "triggerEventKind": "behavior.food_visit",
  "deviation": "food_visits_change",
  "value": -35,
  "unit": "percent",
  "severity": "suspected",
  "reviewStatus": "pending"
}
```

> 字段与命名是**草案**，需在 ADR 中定稿；`birdId`/`cageId`/`sessionId` 的取值规则、时区与保留期另行确认。

---

## 6. 五个能力接缝（接口草图）

每个接缝 = **Definition（抽象基类）+ 注册表 + 一个或多个 Provider + Consumer**。接口用 Python `ABC` 示意，命名与最终实现可调整。

### 接缝 1：`capture`（摄像头采集）

```python
class CaptureProvider(ABC):
    name: str
    def open(self, config) -> None: ...
    def next_frame(self) -> Frame | None: ...   # 抽帧；无帧返回 None
    def close(self) -> None: ...
```

Provider：`RTSPSource`（Tapo/Reolink/Dahua/Hikvision）、`OnvifSource`、`PhoneSource`（旧手机）、`LocalFileSource`（用户上传视频）。
Consumer：抽帧器、事件检测器。

### 接缝 2：`detect` / `track`（鸟检测与追踪）

```python
class Detector(ABC):
    name: str
    def detect(self, frame) -> list[Detection]: ...   # 是否有鸟、位置、功能区
    def track(self, frames) -> list[Track]: ...       # 轨迹、进入/离开功能区
```

Provider：`FootRingTracker`（脚环颜色 + 身体位置）、`WholeCageTracker`（**退化版：只分析笼体整体，不区分个体**）、（后续）`SpeciesGenericDetector`。
> 该接缝是「个体识别可降级」的关键：`birdId` 为 `cage` 时即整体笼态。

### 接缝 3：`behavior`（行为事件识别）

```python
class BehaviorRecognizer(ABC):
    name: str
    def recognize(self, tracks, frames) -> list[BehaviorEvent]: ...
```

Provider 按行为拆（**每种行为一个 Provider，渐进扩展**）：`FoodVisitRecognizer`、`ActivityRecognizer`、`LongStillnessRecognizer`、`SocialInteractionRecognizer`、`VocalizationRecognizer`。
Consumer：事件日志写入器、`baseline` 接缝。

### 接缝 4：`baseline`（个体基线）

```python
class BaselineProvider(ABC):
    name: str
    def build(self, events) -> Baseline: ...                        # 7–14 天 → 个体基线
    def compare(self, day_metrics, baseline) -> list[Deviation]: ... # 和「这只鸟自己」比
```

Provider：`StatisticalBaseline`（统计基线，MVP）、（后续）`ModelBaseline`。
> **scope + shadowing**：per-bird 基线（`lumi`）覆盖全局默认基线（`lovebird-default`）；无个体基线时回退全局。

### 接缝 5：`explain`（大模型解释层）

```python
class ExplainProvider(ABC):
    name: str
    def render(self, metrics, deviations) -> ReportText: ...
```

Provider：`DeepSeekProvider`、`LocalLLMProvider`、`TemplateProvider`（**确定性兜底，无 key/离线时可用**）。
Consumer：日报/兽医报告生成。
> **强制边界**：该接缝只把结构化结果翻译成人话，**不负责底层识别**；这是代码层强制的职责边界（测试可断言 `explain` 不接受原始帧）。

---

## 7. 横切能力接缝

| 接缝 | 用途 | Provider 示例 | 备注 |
|---|---|---|---|
| `storage` | 视频/音频/事件/基线存储 | `LocalStorage`、`ObjectStorage` | 按订阅分层；原始视频本地低码率，事件才落库 |
| `notify` | 异常提醒通知 | `Telegram`、`Email`、`AppPush` | 多个 Provider 并存 |
| `approval` | 人工复核（**fail-closed**） | 由前端/通知通道提供「审批者」 | 无审批者即拒绝；健康预警只能「疑似」 |
| `sandbox` | 最小权限执行 | 本地、远程 | 外部 API、模型推理隔离 |
| `skill` | 可复用 SOP | `agent/skills/` | 日报/兽医报告/异常回看，厂商无关 |

`approval` 接缝与 `AGENTS.md` 安全边界一致：**动物疾病、用药、处置属高风险，自动化输出必须保留证据来源并经具备资质者复核，缺省拒绝。**

---

## 8. 技术栈与落地方式

### 8.1 引擎层：Python 惯用法，暂不引入 Cordis

- **Definition**：`ABC` 抽象基类；**Provider**：`providers/` 目录 + 一个简单注册表（或 `importlib.metadata` entry points）。
- 依赖注入用「构造时注入」或轻量工厂，**不自建 DI 框架**；等编排层复杂度真正上升，再评估引入 dsh/Cordis。
- 触发条件（写进 ADR 作为「何时引入」的判断标准）：当出现 ≥3 个需要动态组合/热插拔/热更新的 Provider、或需要多 Agent 编排与 skill 生态时，再引入。

### 8.2 事件日志：JSONL 起步，可换 SQLite

- MVP 用 JSONL（与 dsh 的 `session-persistence-jsonl` 同思路），每天/每笼一个文件，天然可重放、可 `grep`。
- 之后可换 SQLite（dsh 也有 SQLite 后端），接口层不变——这本身就是 `storage` 接缝的价值。

### 8.3 为什么不做二三十种行为

`project-background.md` 已明确「控制 5–7 类」。接缝设计天然支持：**每新增一种行为 = 挂一个新 Provider**，不重构已有代码；但 MVP 只实现三项识别的 Provider。

---

## 9. 目录骨架（草案，在现有仓库上扩展）

```text
.
├── README.md / AGENTS.md / CONTRIBUTING.md   # 已有
├── docs/
│   ├── architecture.md                       # 既定事实（本提案被采纳后再并入）
│   ├── architecture-proposal.md              # 本文件
│   ├── project-background.md                 # 已有
│   └── decisions/                            # ADR（见第 11 节）
├── agent/
│   ├── skills/    # 日报生成、兽医报告、异常回看（厂商无关）
│   ├── policies/  # 健康预警 fail-closed、数据保留、人工复核边界
│   └── workflows/ # 每日日报流程、异常处置流程
├── packages/                                 # 业务代码（映射 dsh 的 packages/）
│   ├── capture/    # definition.py registry.py providers/ tests/
│   ├── detect/     # 同上（含 track）
│   ├── behavior/   # 每种行为一个 Provider
│   ├── baseline/   # 个体基线 + scope/shadow
│   ├── explain/    # LLM 解释层 + 确定性兜底
│   ├── storage/    # 事件/视频/基线存储
│   ├── notify/     # 通知
│   └── approval/   # 人工复核（fail-closed）
└── DSH Mac Client/                            # 已有，不动
```

每个接缝目录统一结构：`README.md`（用途/接口/扩展点/已知限制）、`definition.py`、`registry.py`、`providers/`、`tests/`——这与 dsh 的「每个包 README 覆盖用途/API/扩展点/Model Experience」一致。

---

## 10. 关键不变量与安全边界

1. **事件日志只追加、可重放、带版本号**：任何模型可见/用户可见的结论，都能从日志重建。
2. **explain 不接触原始帧**：LLM 只翻译结构化结果（用类型签名 + 测试强制）。
3. **异常只报「疑似」，不报「诊断」**：`alert.raised` 的 `severity` 用 `suspected`，处置必须走 `approval`。
4. **approval fail-closed**：无审批者即拒绝，不静默放行。
5. **最小权限**：外部系统、模型推理、数据删除经 `sandbox`/`approval` 约束。
6. **个体基线缺失时回退全局基线，并显式标注来源**，不把回退伪装成个体结论。

---

## 11. 落地路线图

1. **先定事件日志 schema**：用一份 ADR 定稿第 5 节的信封与事件类型；写最小链路 `capture → detect → 一条 behavior 事件 → 落日志 → 一句日报文案`，跑通「食盆访问」全流程。
2. **五个接缝落成 Python ABC + 注册表**：每个接缝先只写 1 个最容易的 Provider（如 `WholeCageTracker`）。
3. **引入 baseline 接缝**：实现「7–14 天 → 个体基线 → shadow 全局」的最小统计版。
4. **explain 做成 Consumer**：用测试断言「explain 不接受原始帧」，把职责边界固化。
5. **沉淀 skill**：日报生成、兽医报告、异常回看三个 SOP（`agent/skills/`）。
6. **横切接缝逐步补**：`storage`（本地）→ `notify` → `approval`。
7. **编排层再评估**：达到第 8.1 节触发条件后，再决定是否引入 dsh/Cordis。

---

## 12. 待确认问题（需负责人答复后再定稿）

1. MVP 首版数据来源：RTSP/ONVIF、旧手机、还是「用户上传视频」先验证价值。
2. 个体识别首版：脚环颜色，还是先做「整体笼态」。
3. 事件/视频的存储位置、保留期限与隐私/合规要求（影响 `storage` 接缝与 `videoRef` 设计）。
4. 时区与 `sessionId` 分区粒度（建议「笼+日」）。
5. 通知通道首版用哪个（影响 `notify` Provider 优先级）。
6. 引擎层运行时部署：端侧优先还是云端优先（影响 `sandbox` 与成本模型）。

---

## 13. 建议写入 ADR 的第一批决策

- `0001-behavior-event-log-as-source-of-truth.md` — 事件日志唯一事实来源（最高优先级）。
- `0002-five-capability-seams.md` — 五管道层 = 五接缝，Definition/Provider/Consumer 三件套。
- `0003-individual-baseline-scope-shadowing.md` — 个体基线 = scope + shadowing。
- `0004-llm-explain-is-consumer-only.md` — LLM 只做解释层 Consumer，不进引擎。
- `0005-engine-python-no-cordis-yet.md` — 引擎层用 Python ABC + 注册表，暂不引入 Cordis（含触发条件）。

---

> 本文已由负责人确认（2026-08-18）；核心决策见 `docs/decisions/0001-*.md` 至 `0005-*.md`（Accepted），并已并入 `docs/architecture.md`。
