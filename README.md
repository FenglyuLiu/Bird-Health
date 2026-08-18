# 笼养动物健康管理

本仓库用于沉淀“笼养动物健康管理”项目的代码、研究资料、业务规则和 Agent 协作记录。

当前已存在的子项目：

- `DSH Mac Client/`：DeepSeek Harness Web GUI 的 macOS 独立客户端。

后续业务模块尚未在本文件中确认。新增模块时，请同步更新本文件以及 `docs/architecture.md`。

## 项目协作入口

无论使用 DeepSeek Harness、Codex、Claude Code，还是人工开发者，开始工作前都应阅读：

1. `AGENTS.md`：Agent 的通用工作规则；
2. `CONTRIBUTING.md`：开发、验证与提交规范；
3. `docs/agent-handoff.md`：当前进度和下一步；
4. `docs/architecture.md`：系统边界和架构现状；
5. `docs/decisions/`：已经确认的长期设计决策。

## 快速检查

```bash
make help
make status
make check
```

目前仓库根目录只提供通用检查入口。各子项目可以在自己的目录中维护更具体的构建和测试命令。

## 目录结构

```text
.
├── README.md
├── CONTRIBUTING.md
├── AGENTS.md
├── CLAUDE.md
├── Makefile
├── .env.example
├── docs/
│   ├── agent-handoff.md
│   ├── architecture.md
│   └── decisions/
├── agent/
│   ├── README.md
│   ├── skills/
│   ├── policies/
│   └── workflows/
└── DSH Mac Client/
```

## 安全提醒

- 不要将真实密钥、令牌、个人数据或生产数据库地址提交到仓库。
- 动物疾病识别、用药和处置属于高风险业务；自动化输出必须保留证据来源，并在实际执行前由具备资质的人员复核。
- 对生产环境、外部消息发送、数据删除及不可逆操作，必须取得明确授权。
