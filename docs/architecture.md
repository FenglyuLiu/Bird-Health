# 项目架构现状

## 目的

本文描述当前仓库可确认的系统边界。它不是未来业务系统的最终设计；未经验证的信息不得在此写成既定事实。

> 已采纳的插件化架构见 `architecture-proposal.md`（Accepted）与 `decisions/0001-*.md` 至 `0005-*.md`；本文件「业务系统」一节据此更新。

## 当前仓库组成

### 1. 根目录协作层

根目录负责跨开发者、跨 Agent 和跨 Harness 的共享上下文：

- `README.md`：项目入口和结构说明；
- `AGENTS.md`：通用 Agent 规则；
- `CONTRIBUTING.md`：开发和交付规范；
- `docs/agent-handoff.md`：阶段状态；
- `docs/decisions/`：长期决策；
- `agent/`：可移植的 Skills、Policies 和 Workflows；
- `Makefile`：稳定的仓库级命令入口。

### 2. `DSH Mac Client/`

现有 macOS 原生壳应用，用系统 WebKit 加载本机 DeepSeek Harness Web GUI，并可在服务未启动时使用应用内置 Node.js 和 DSH 运行时启动服务。

已知构建入口：

```bash
make check-shell
cd "DSH Mac Client" && ./build.sh
```

完整构建可能下载 Node.js，且依赖本机 DSH 打包源，因此不属于默认的无副作用检查。

### 3. 笼养动物健康管理业务系统

尚未发现可确认的业务代码或正式需求文档；但**架构方向已通过 ADR 确定**（五个能力接缝 + 行为事件日志，见「已采纳的架构边界」）。以下业务细节仍待确认：

- 目标动物种类和养殖场景；
- 用户角色与权限；
- 健康观察、环境监测、预警和处置流程；
- 数据来源、保留期限和隐私规范；
- 部署环境（端侧 vs 云端）；
- 人工复核与责任边界。

> 项目的背景、愿景、MVP 方向与市场/商业模式讨论记录见 `docs/project-background.md`（未经验证，不得作为既定架构事实）。

## 已采纳的架构边界（ADR-0001 至 0005）

经负责人确认（2026-08-18），以下为已采纳的架构决策；详见 `docs/architecture-proposal.md` 与 `docs/decisions/`。

```text
capture → detect → behavior → baseline → explain
     └──────────── 行为事件日志（唯一事实来源）────────────┘
```

- **唯一事实来源**：append-only 行为事件日志，日报/基线/提醒/兽医报告均为其投影（ADR-0001）。
- **五个能力接缝**：`capture → detect → behavior → baseline → explain`，每接缝为 Definition/Provider/Consumer 三件套，换 Provider 不动 Consumer（ADR-0002）。
- **个体基线**：`bird → cage → species` 三级 scope + shadowing，最具体者胜并显式标注来源（ADR-0003）。
- **LLM 边界**：大模型只作 `explain` 接缝 Consumer，不接受原始帧/音频，有确定性模板兜底（ADR-0004）。
- **落地方式**：引擎层 Python ABC + 注册表 + YAML 选 Provider，暂不引入 Cordis，附升级触发条件（ADR-0005）。

潜在领域模块（实现阶段再细化）：

- 动物与笼舍档案；
- 日常观察和健康记录；
- 环境传感器数据；
- 健康风险预警；
- 复核、处置与追踪；
- 审计与报表。

## 关键非功能要求

- 可追溯：预警必须能追溯到输入数据、规则或模型版本。
- 可复核：高风险结论和现实处置必须有人参与。
- 最小权限：外部系统和生产数据访问遵循最小权限。
- 可移植：核心业务知识、测试和命令不依赖单一 Agent 产品。
- 可验证：功能完成由自动测试和明确验收标准证明。
