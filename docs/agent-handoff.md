# Agent Handoff

> 最后更新：2026-03-21  
> 状态：已建立跨 Harness 的基础项目结构

## 项目目标

沉淀笼养动物健康管理相关的软件、业务规则和研究资料，并允许 DeepSeek Harness、Codex、Claude Code 及人工开发者在保留事实和进度的前提下接力工作。

当前仓库中可确认的现有子项目为 `DSH Mac Client/`。笼养动物健康管理业务系统的具体需求、技术栈和范围尚未形成可验证的仓库文档。

## 本轮范围

建立厂商无关的项目协作与交接骨架，不修改现有 `DSH Mac Client` 源代码或构建产物。

## 已完成

- 新增根目录项目说明与目录导航。
- 新增跨 Agent 通用规则 `AGENTS.md`。
- 新增 Claude Code 入口适配文件 `CLAUDE.md`。
- 新增贡献、验证和交接规范。
- 新增根目录 `Makefile`，提供安全的状态与脚本语法检查。
- 新增环境变量示例文件。
- 建立架构、ADR、Skills、Policies 和 Workflows 目录及说明。

## 进行中

当前无进行中的实现任务。

## 尚未开始

- 明确笼养动物健康管理业务目标、用户角色和 MVP 边界。
- 选择业务系统技术栈和部署方式。
- 建立业务代码、数据模型及测试体系。
- 将高频操作流程沉淀为实际 Skill。
- 根据需要配置 MCP 服务；密钥不得写入仓库。

## 关键事实与决定

- `DSH Mac Client/` 是目前已有的独立子项目。
- 根目录文档作为跨 Harness 的事实与协作入口。
- 通用规则只在 `AGENTS.md` 维护，厂商专属文件仅做转引或适配。
- 长期架构选择使用 ADR；阶段性状态写入本文件。
- 健康预警、疾病和用药相关功能必须保留人工复核环节。

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
- 未运行完整客户端构建或安装，避免下载依赖及覆盖 `/Applications` 中的应用。

## Git 状态

执行本轮工作时，工作目录未显示为有效 Git 仓库。若后续需要版本化和跨工具接力，建议由用户确认后初始化 Git，并设置适合该项目的 `.gitignore`。

## 下一步建议

1. 与项目负责人确认业务 MVP、使用者和成功指标。
2. 盘点现有业务资料、数据格式和隐私要求。
3. 创建第一份业务架构 ADR。
4. 确认是否初始化 Git；若初始化，先检查 `DSH Mac Client/dist/` 与 `.cache/` 等大型生成物的跟踪策略。

## 给下一位 Agent 的接手提示

```text
请先不要修改文件。阅读 README.md、AGENTS.md、CONTRIBUTING.md、
docs/agent-handoff.md、docs/architecture.md 和 docs/decisions/README.md，
然后执行 make status 与 make check。核对交接记录和实际工作区是否一致，
再提出下一阶段计划；未经确认不要初始化 Git、提交、部署或运行安装脚本。
```
