# Architecture Decision Records

本目录保存影响长期开发的架构决策。阶段进度和临时待办不要放在这里，应更新 `docs/agent-handoff.md`。

## 命名

```text
NNNN-short-title.md
```

例如：

```text
0001-select-application-architecture.md
```

## 状态

- Proposed：待讨论；
- Accepted：已接受；
- Superseded：已被新决策替代；
- Rejected：已拒绝但保留理由。

## 模板

```markdown
# NNNN：决策标题

- 状态：Proposed
- 日期：YYYY-MM-DD
- 决策者：

## 背景

为什么需要做出这个决定？有哪些约束？

## 决策

选择什么方案？

## 备选方案

考虑过哪些其他方案？

## 影响

正面影响、代价、风险和后续工作是什么？

## 验证

如何证明该决定满足需求？
```
