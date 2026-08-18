# 贡献指南

## 1. 开始任务

- 明确目标、范围、约束和验收标准。
- 阅读 `AGENTS.md`、当前交接文档及相关架构决策。
- 执行 `make status`，确认工作区中是否已有未提交内容。
- 对较大任务，先将计划和阶段性成果写入 `docs/agent-handoff.md`。

## 2. 分支与提交

推荐为每项独立工作建立分支：

```bash
git switch -c feature/<short-name>
```

提交应聚焦、可解释，推荐格式：

```text
feat: add animal observation records
fix: correct health alert threshold
chore: add portable agent project structure
docs: update architecture decision
```

除非用户明确要求，Agent 不应自行提交或推送。

## 3. 开发约定

- 遵循所在子项目已有风格，不在根目录强行统一不同技术栈。
- 优先补充可复现命令和自动测试，避免仅依靠人工操作说明。
- 新增环境变量时同步更新 `.env.example`，只填写占位符和用途说明。
- 新增通用命令时优先通过 `Makefile` 或子项目脚本暴露稳定入口。
- 重大设计选择使用 ADR 记录，模板见 `docs/decisions/README.md`。

## 4. 验证

提交交付前至少完成：

```bash
make check
```

并根据子项目补充更具体的检查，例如：

- 单元测试和集成测试；
- lint、格式检查、类型检查；
- 构建或打包；
- 对关键用户路径进行最小人工验收。

若某项验证没有运行，必须说明原因，不能默认视为通过。

## 5. 交接

切换到其他 Agent 或暂停工作前，更新 `docs/agent-handoff.md`：

- 项目目标和本轮范围；
- 已完成、进行中和未开始事项；
- 修改文件与关键设计决定；
- 已运行的验证命令和准确结果；
- 已知问题、环境依赖和下一步；
- 当前分支、提交或未提交 diff 的状态。

交接记录用于快速理解，代码、Git 历史和测试结果仍是最终依据。

## 6. 敏感信息与高风险功能

- 本地秘密放入 `.env` 或系统密钥管理器，不提交到 Git。
- 示例配置必须使用虚构值。
- 生产环境写入、外部通知、删除、部署和发布必须经用户明确授权。
- 与动物健康、疾病、用药相关的功能应注明数据来源、置信度和人工复核要求。
