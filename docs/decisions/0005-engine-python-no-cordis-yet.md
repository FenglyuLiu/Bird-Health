# 0005：引擎层用 Python「抽象基类 + 注册表」，暂不引入 Cordis

- 状态：Accepted
- 日期：2026-08-18
- 决策者：项目负责人

## 背景

本项目的架构思想借鉴 DeepSeek Harness（`dsh`）的「一切皆插件」与「capability seam」，但 `dsh` 的实现依赖 [Cordis](https://github.com/cordiverse/cordis)——一个 TypeScript 生态的依赖注入/插件框架（见 `docs/architecture-proposal.md` 第 3 节）。

本项目的引擎核心是 Python/CV（摄像头采集、鸟检测与追踪、行为识别、个体基线），与 Cordis 的语言生态不匹配。因此需要回答：**引擎层用什么技术落地「接缝」？什么时候才值得引入 Cordis/dsh？**

如果盲目 vendor Cordis，会让一个当前只有五个接缝、每接缝一两个 Provider 的项目背上跨语言桥接、TS 工具链与 DI 框架的心智负担；但如果完全手写一套通用插件框架，又会重造轮子、过度设计。正确的做法是：**保留接缝思想，用 Python 最惯用的最小机制落地，并为「何时升级」设定明确触发条件。**

## 决策

**引擎层用 Python 抽象基类（`ABC`）+ 轻量注册表（或 `importlib.metadata` entry points）落地五个能力接缝；暂不 vendor Cordis，也不自建通用插件框架。**

### 落地约定

1. **Definition**：每个接缝用一个 `ABC` 抽象基类声明接口（如 `CaptureProvider`、`Detector`、`BehaviorRecognizer`、`BaselineProvider`、`ExplainProvider`，见 `docs/architecture-proposal.md` 第 6 节草图）。
2. **Provider**：每个实现放在该接缝的 `providers/` 目录，注册到该接缝的注册表；Provider 之间不互相 import。
3. **Consumer**：只 import 抽象基类（对应 ADR-0002 硬规则「扩展依赖 Definition，不依赖具体 Provider」）。
4. **选择 Provider**：通过一份声明式配置（建议 YAML，形如 `dsh` 的 `cordis.yml` 行，但先不做完整 DI）指定每个接缝用哪个 Provider，例如 `capture: rtsp`、`detect: whole-cage`。
5. **依赖注入**：构造时注入或轻量工厂，不引入 DI 容器。

### 「何时引入 Cordis/dsh」的触发条件

满足**任意一条**时，重新评估并另立 ADR 决策是否引入：

1. 需要 ≥3 个 Provider 的**运行时动态组合/热插拔/热更新**（当前只是启动时静态选择）；
2. 需要**多 Agent 编排**（subagent 委派、skill 生态、workflow 引擎）而不仅是单引擎 Pipeline；
3. 编排层（日报调度、通知、订阅、审计、多租户）复杂度上升到需要 dsh 的 profile/bundle 组合能力；
4. 团队希望复用 dsh 生态的现成插件（`dsh-plugin`）或把本项目作为 dsh 插件分发。

在触发之前，**只维护「接缝思想 + 最小机制」**，不预建通用框架。

### 与 Cordis 思想的对应关系（保留，不照搬实现）

| Cordis 概念 | 本项目引擎层的对应物 |
|---|---|
| `Service` / `ctx.<key>` | `ABC` 抽象基类 + 接缝名 |
| Provider 注册到接缝 | `providers/` + 注册表/entry points |
| `inject` 声明依赖 | 构造时注入 / 工厂 |
| `ctx.effect()` 可逆副作用 | （引擎层暂不需要运行时热卸载） |
| profile/bundle 组合 | 声明式 YAML 配置（简化版） |

## 备选方案

### 方案 A：立即 vendor Cordis，全用 TypeScript（未采用）

- 优点：与 `dsh` 完全一致，直接复用其生态。
- 缺点：CV 引擎在 Python 生态成熟得多，跨语言桥接成本高；当前规模用 DI 框架是过度工程。保留为触发条件满足后的备选。

### 方案 B：引入重量级 Python DI 框架（未采用）

- 优点：标准化、功能全。
- 缺点：五个接缝、每接缝一两个 Provider 用不上其功能；增加学习与维护成本。抽象基类 + 注册表已足够。

### 方案 C：自建通用插件框架（未采用）

- 优点：完全可控。
- 缺点：重造轮子、长期维护成本高，且「通用框架」的抽象可能反过来拖慢 MVP。仅在触发条件满足且不选 Cordis 时才重新考虑。

## 影响

**正面：**

- 简单、贴合 Python/CV 生态，MVP 迭代快。
- 接缝边界与「Definition/Provider/Consumer」纪律（ADR-0002）完整保留，日后迁移到 Cordis/dsh 时结构可平移。
- 避免过早绑定框架，降低技术债务。

**代价与风险：**

- 触发条件满足后可能需要一次「从简化注册表迁移到 Cordis/dsh」的改造；缓解方式是把接缝接口设计成与实现解耦（只依赖抽象基类），使迁移只替换装配层，不重写 Provider。
- 声明式 YAML 配置若自由生长，可能演化成半个未文档化的 DI；需在配置规范上保持克制，只做「选 Provider + 传参数」。

**后续工作：**

- 建立五个接缝的 `ABC` 签名与注册表约定（草案见 `docs/architecture-proposal.md` 第 6 节）。
- 确定 Provider 选择配置文件的 schema（建议 YAML，最小字段集）。
- 把本决策的触发条件写入 `docs/architecture.md`（转正后）或独立 checklist，供后续复评。

## 验证

- 最小可运行：在**不引入 Cordis 与任何 DI 框架**的前提下，用 `ABC + 注册表` 跑通 ADR-0002 的最小链路（`capture → detect → behavior → 事件日志`）。
- 可替换：仅改 YAML 配置（如 `detect: whole-cage` → `detect: foot-ring`），不 import 具体 Provider，全链路即可切换实现。
- 无框架依赖：依赖清单中不出现 Cordis/DI 容器；`pip`/`poetry` 依赖仅含 CV、存储与必要工具。
- 迁移面：删除注册表层、改用手写 `cordis.yml`（或触发条件满足后的目标装配），五个 Provider 的 `ABC` 实现本身无需改动即可被重新装配。
