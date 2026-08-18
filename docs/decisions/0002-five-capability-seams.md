# 0002：五个管道层建模为五个能力接缝

- 状态：Accepted
- 日期：2026-08-18
- 决策者：项目负责人

## 背景

`docs/project-background.md` 把系统定义为五层技术结构：

```text
摄像头采集 → 鸟检测与追踪 → 行为事件识别 → 个体基线 → 大模型解释层
```

这五层需要支撑三条产品战略（均为讨论稿，落地前需确认）：

1. **摄像头无关**：兼容 RTSP/ONVIF 的通用 IP 摄像头（Tapo/Reolink/Dahua/Hikvision），甚至旧手机当摄像头。
2. **个体识别可降级**：脚环颜色识别是难点，首版可能需要退化为「只分析笼体整体，不区分个体」。
3. **从鹦鹉扩展到其他笼养动物**：复用「长期视频 → 行为基线 → 异常 → 报告」整条 Pipeline（约 70%），只有行为识别模型需要换/重训。

如果把这五层写成一条「大而全」的流水线函数，那么换摄像头、降级识别、换行为模型都会变成改核心代码，风险高、不可回退、难测试。DeepSeek Harness（`dsh`）的做法是把可替换能力建模为 **capability seam**：一个接缝由三个角色组成——**Service Definition（接口）+ Service Provider（实现）+ Consumer（使用者）**，换 Provider 不动 Consumer。

## 决策

**把五个管道层各自建模为一个能力接缝，每个接缝遵循「Definition / Provider / Consumer」三件套；引擎层用 Python 抽象基类 + 注册表落地，暂不引入 Cordis。**

### 五个接缝

| 管道层 | 接缝（Definition 职责） | Provider（可替换实现，示例） | Consumer（使用者） |
|---|---|---|---|
| 摄像头采集 | `capture`：产出帧序列，管理视频流生命周期 | `RTSPSource`、`OnvifSource`、`PhoneSource`、`LocalFileSource` | 抽帧器、`detect` |
| 鸟检测与追踪 | `detect`/`track`：从帧产出检测与轨迹，含功能区语义 | `FootRingTracker`（脚环颜色）、`WholeCageTracker`（整体笼态，退化版）、（后续）`SpeciesGenericDetector` | `behavior` |
| 行为事件识别 | `behavior`：从轨迹/帧产出结构化行为事件 | `FoodVisitRecognizer`、`ActivityRecognizer`、`LongStillnessRecognizer`、`SocialInteractionRecognizer`、`VocalizationRecognizer`（每种行为一个 Provider） | 事件日志、`baseline` |
| 个体基线 | `baseline`：聚合个体指标并与历史基线对比 | `StatisticalBaseline`（MVP）、（后续）`ModelBaseline` | `explain`、异常提醒 |
| 大模型解释层 | `explain`：把结构化指标翻译成人话报告 | `DeepSeekProvider`、`LocalLLMProvider`、`TemplateProvider`（确定性兜底） | 日报/兽医报告生成 |

接口草图见 `docs/architecture-proposal.md` 第 6 节。

### 三条硬规则

1. **一个角色不是接缝**：定义接缝时必须同时设计 Definition、至少一个 Provider、至少一个 Consumer；三者缺一则回到「先定义接口」。
2. **扩展依赖 Definition，不依赖具体 Provider**：Consumer 只依赖抽象基类（`CaptureProvider` / `Detector` / …），绝不 `import` 某个具体 Provider；否则就失去「换 Provider 不动 Consumer」的意义。这对应 dsh 的「Extension plugins depend on Service Definitions, never concrete providers」。
3. **Provider 可并行注册、按需选择**：同一接缝可存在多个 Provider，通过配置/注册表选择使用哪个（如 `capture: rtsp` 或 `detect: whole-cage`），不必改代码。

### 关键设计点

- **`detect` 接缝承载「可降级」**：个体身份未识别时，`birdId` 取 `cage`（整体笼态），由 `WholeCageTracker` 产出；脚环版就绪后切到 `FootRingTracker`，同一接缝、同一 Consumer，无痛切换。
- **`behavior` 接缝承载「渐进扩展」**：每新增一种行为 = 挂一个新 Provider，不重构已有代码；MVP 只实现三项识别（食盆访问、活动量/静止、多鸟互动）。
- **`baseline` 接缝承载「个体基线 = scope + shadowing」**：per-bird 基线（如 `lumi`）覆盖全局默认基线（如 `lovebird-default`），无个体基线时回退全局（对应 ADR-0003，另立）。
- **`explain` 接缝承载「LLM 只翻译、不识别」**：用类型签名 + 测试强制该接缝不接受原始帧，只接受结构化指标。

### 技术落地方式（本次一并决策）

- 引擎层（Python/CV）用 **`ABC` 抽象基类 + 轻量注册表**（或 `importlib.metadata` entry points）实现接缝，**不自建 DI 框架、暂不 vendor Cordis**。
- 触发引入 Cordis/dsh 的条件：当出现 ≥3 个需要动态组合/热插拔/热更新的 Provider，或需要多 Agent 编排与 skill 生态时，再评估（详见 `docs/architecture-proposal.md` 第 8.1 节）。

## 备选方案

### 方案 A：单一流水线函数（未采用）

`run_pipeline(video) -> report`，内部顺序调用采集/检测/识别/基线/解释。

- 优点：实现最直接、初期最快。
- 缺点：换摄像头、降级识别、换行为模型都要改核心函数；无法并行注册 Provider；难测试、难回退；与「摄像头无关」「可降级」「跨物种扩展」三条战略直接冲突。

### 方案 B：直接 vendor Cordis，全用 TypeScript（未采用）

照搬 dsh 的 Cordis 框架与 `ctx.*` 服务。

- 优点：与 dsh 完全一致，生态对齐。
- 缺点：Cordis 是 TypeScript 生态 DI 框架，而引擎核心是 Python/CV；对当前规模是过度工程，且引入跨语言桥接成本。保留为「编排层复杂度上升后的备选」。

### 方案 C：引入重量级 Python DI 框架（未采用）

如依赖注入容器库来管理 Provider。

- 优点：标准化。
- 缺点：当前只有五个接缝、每接缝一两个 Provider，额外依赖与学习成本不成比例；抽象基类 + 注册表已足够，日后需要再演进。

## 影响

**正面：**

- 直接支撑「摄像头无关」「可降级」「跨物种扩展」三条战略，换 Provider 不动 Consumer。
- 每接缝可独立测试：给 `behavior` 接缝喂固定轨迹即可断言事件输出，无需真摄像头。
- 渐进上线与安全回退：脚环版失败可切回整体笼态版，不改业务代码。
- 职责边界清晰：`explain` 只翻译不识别，由接缝边界 + 测试强制。

**代价与风险：**

- 需要在 MVP 早期就定义好五个抽象基类的接口签名，若签名定错，后续迁移有成本（这正是要用 ADR 提前固定、并在 ADR-0001 的事件日志上先跑通最小链路的原因）。
- 注册表与 Provider 选择机制需要少量样板代码。
- 过度拆分的风险：若某个接缝长期只有一个 Provider 且从不替换，拆接缝是多余开销。缓解方式：MVP 每个接缝只写 1 个 Provider，等真正出现第二个实现时再确认接缝边界是否合理。

**后续工作：**

- 定义五个接缝的抽象基类签名与注册表约定（详见 `docs/architecture-proposal.md` 第 6 节草案）。
- 确定 Provider 选择配置（如 `cordis.yml` 式的配置文件，或 Python 配置文件），先不引入 YAML 解析外的复杂机制。
- 建立每个接缝的单元测试约定（用确定性输入回放事件输出）。

## 验证

- 用最小链路验证「接缝可替换」：同一份输入帧，分别用 `WholeCageTracker` 与（桩）`FootRingTracker` 走通 `detect → behavior → 事件日志`，断言事件日志结构一致、仅 `birdId` 等字段随 Provider 变化。
- 验证「Consumer 不依赖具体 Provider」：静态检查（或测试）断言 `explain`/`behavior` 只 import 抽象基类，不 import 具体 Provider。
- 验证「可降级」：关闭 `FootRingTracker`、启用 `WholeCageTracker` 后，全链路仍可运行，且 `birdId=cage`。
- 验证「explain 不接触原始帧」：类型签名不接受 `Frame`，只接受结构化指标；用测试断言传入原始帧会失败。
