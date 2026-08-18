# Agent Handoff

> 最后更新：2026-08-18  
> 状态：插件化架构提案与五份 ADR 已获负责人通过（Accepted，2026-08-18）并并入 `docs/architecture.md`；DSH Mac Client 独立版已修复；项目背景已整理入长期记忆

## 项目目标

沉淀笼养动物健康管理相关的软件、业务规则和研究资料，并允许 DeepSeek Harness、Codex、Claude Code 及人工开发者在保留事实和进度的前提下接力工作。

当前仓库中可确认的现有子项目为 `DSH Mac Client/`。笼养动物健康管理业务系统的具体需求、技术栈和范围尚未形成可验证的仓库文档；但项目背景与愿景已整理到 `docs/project-background.md`（属于讨论记录，未经验证不得作为既定事实）。

## 本轮范围

研究 DeepSeek Harness 仓库的「一切皆插件」架构，将其映射到笼养动物健康管理项目，产出插件化架构提案与五份 ADR，并经负责人确认转正（Accepted）。

## 已完成

- 新增根目录项目说明与目录导航。
- 新增跨 Agent 通用规则 `AGENTS.md`。
- 新增 Claude Code 入口适配文件 `CLAUDE.md`。
- 新增贡献、验证和交接规范。
- 新增根目录 `Makefile`，提供安全的状态与脚本语法检查。
- 新增环境变量示例文件。
- 建立架构、ADR、Skills、Policies 和 Workflows 目录及说明。
- 确认损坏应用缺少 `Contents/MacOS/DeepSeekHarness`，且没有有效签名；源构建产物完整。
- 将 `DSH Mac Client/install.sh` 改为“源包验证 → 临时目录复制 → 临时副本验证 → 原子替换 → 安装后复验”，失败时恢复旧应用。
- 经用户明确确认，重新安装并启动 `/Applications/DeepSeek Harness.app`。
- 将创始人与 ChatGPT 的项目讨论整理为 `docs/project-background.md`，沉淀项目背景、MVP 方向、战略方向与市场/商业模式讨论记录。
- 研究 DeepSeek Harness 仓库（clone 至 `/tmp/deepseek-harness-study`，版本 `dsh-0.1.0-rc.7`），梳理「一切皆插件」「capability seam」「唯一事件日志」「scope/shadowing」「approval fail-closed」等核心思想。
- 新增 `docs/architecture-proposal.md`：将五层技术结构映射为五个能力接缝，给出事件日志 schema、接口草图、目录骨架、关键不变量与路线图（Accepted）。
- 新增 `docs/decisions/0001-behavior-event-log-as-source-of-truth.md`：行为事件日志作为唯一事实来源（Accepted）。
- 新增 `docs/decisions/0002-five-capability-seams.md`：五个管道层建模为五个能力接缝（Definition/Provider/Consumer）（Accepted）。
- 新增 `docs/decisions/0003-individual-baseline-scope-shadowing.md`：个体基线采用 scope + shadowing 三级模型（Accepted）。
- 新增 `docs/decisions/0004-llm-explain-is-consumer-only.md`：大模型只作解释层 Consumer，不进识别引擎（Accepted）。
- 新增 `docs/decisions/0005-engine-python-no-cordis-yet.md`：引擎层用 Python ABC + 注册表，暂不引入 Cordis（Accepted）。
- 经负责人确认，将上述提案与 ADR 转正（Accepted）并把摘要并入 `docs/architecture.md`。

## 进行中

当前无进行中的实现任务。

## 尚未开始

- 明确笼养动物健康管理业务目标、用户角色和 MVP 边界（项目背景与愿景已记录于 `docs/project-background.md`，仍需与负责人确认后转为正式需求文档）。
- 选择业务系统技术栈和部署方式。
- 建立业务代码、数据模型及测试体系。
- 将高频操作流程沉淀为实际 Skill。
- 根据需要配置 MCP 服务；密钥不得写入仓库。

## 关键事实与决定

- `docs/project-background.md` 是项目背景与愿景的长期记忆文件（来自创始人与 ChatGPT 的讨论，未经验证不得作为既定事实）。
- `DSH Mac Client/` 是目前已有的独立子项目。
- 根目录文档作为跨 Harness 的事实与协作入口。
- 通用规则只在 `AGENTS.md` 维护，厂商专属文件仅做转引或适配。
- 长期架构选择使用 ADR；阶段性状态写入本文件。
- 健康预警、疾病和用药相关功能必须保留人工复核环节。
- `docs/architecture-proposal.md` 与 `docs/decisions/0001-*.md` 至 `0005-*.md` 已获负责人通过（Accepted，2026-08-18），核心摘要已并入 `docs/architecture.md`。

## 验证记录

已运行：

```bash
make status
make check
```

结果：

- `make status` 成功，确认当前目录尚未初始化为 Git 仓库；
- `make check` 成功；
- `DSH Mac Client/build.sh` 与 `DSH Mac Client/install.sh` 均通过 Bash 语法检查；
- `dist/DeepSeek Harness.app` 的 Info.plist、主可执行文件、内置 Node 和严格代码签名验证通过；
- 源构建产物通过 `open` 启动并检测到客户端进程；
- 经用户确认运行 `./install.sh`，输出 `Installed and verified`；
- 已安装应用的 Info.plist、主可执行文件、内置 Node 22.22.0、426 MB 完整体积及严格签名验证通过；
- 已安装应用通过 `open` 启动并检测到 `INSTALLED_APP_PROCESS_RUNNING`。
- 本轮（架构映射与转正）：`make status` 成功（当前为 Git 仓库 `main...origin/main`）；`make check` 成功；新增提案与五份 ADR 均经负责人通过（Accepted），未改动既有代码与脚本。

## Git 状态

当前为有效 Git 仓库（`main`，远程 `origin`）。未提交内容（`git status --short`）：`DSH Mac Client/README.md`、`README.md`、`docs/agent-handoff.md`、`docs/architecture.md` 已修改；`docs/architecture-proposal.md`、`docs/project-background.md` 及 `docs/decisions/0001-*.md` 至 `0005-*.md` 未跟踪。尚未提交或推送（需用户明确授权）。

## 下一步建议

1. 阅读 `docs/project-background.md`，与负责人确认业务 MVP、使用者、成功指标及提案第 12 节「待确认问题」。
2. 盘点现有业务资料、数据格式和隐私要求，定稿事件日志 schema 与五个接缝的接口签名（实现前再经评审）。
3. 建立首个可运行的最小链路：`capture → detect → 一条 behavior 事件 → 落日志 → 日报文案`，验证 ADR-0001/0002 的验收标准。
4. 将高频操作流程沉淀为实际 Skill。
5. Git 已初始化；提交/推送前先确认 `DSH Mac Client/dist/`、`.cache/` 等生成物与 `.gitignore` 策略，并取得用户授权。

## 给下一位 Agent 的接手提示

```text
请先不要修改文件。阅读 README.md、AGENTS.md、CONTRIBUTING.md、
docs/agent-handoff.md、docs/architecture.md 和 docs/decisions/README.md，
然后执行 make status 与 make check。核对交接记录和实际工作区是否一致，
再提出下一阶段计划；未经确认不要初始化 Git、提交、部署或运行安装脚本。
```
