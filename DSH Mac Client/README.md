# DeepSeek Harness macOS 独立客户端

这是 DeepSeek Harness Web GUI 的原生 macOS 客户端。它使用系统 WebKit，并将 Node.js 与完整 DSH 依赖树打包在 `.app` 内，不依赖 Homebrew Node、全局 npm 或构建时的 `npx` 缓存路径。

## 功能

- 不打开终端，双击 `.app` 即可进入对话
- 如果 `127.0.0.1:3080` 已有 DSH 服务则直接连接
- 如果服务未运行，则使用应用内置 Node.js 和 DSH 在后台启动
- 保留 `~/.dsh` 中的设置、凭据和会话数据
- 支持文件选择、刷新、页面缩放和外部链接
- 使用自定义“金水相生”图标

## 构建

```bash
cd "/Users/liufenglyu/Downloads/09 创业实践/01 笼养动物健康管理/DSH Mac Client"
./build.sh
```

首次构建会下载官方 Node.js 22.22.0 arm64 运行时并缓存到 `.cache`。构建时仍需要现有 DSH 安装作为打包源，但构建完成的 `.app` 不再依赖该源路径。

输出：

```text
dist/DeepSeek Harness.app
```

## 安装

```bash
./install.sh
```

或把 `dist/DeepSeek Harness.app` 拖入“应用程序”文件夹。

## 数据与日志

应用运行环境位于 `.app/Contents/Resources/runtime`，用户数据仍保存在标准位置：

```text
~/.dsh
```

服务日志：

```text
~/Library/Logs/DeepSeek Harness/server.log
```

## 当前配置

- Web 地址：`http://127.0.0.1:3080`
- 默认工作目录：`/Users/liufenglyu/Downloads/09 创业实践/01 笼养动物健康管理`
- 内置 Node.js：22.22.0（macOS arm64）
- 内置 DSH：0.1.0-rc.7

当前构建面向 Apple Silicon Mac。应用不依赖原来的 `/Users/liufenglyu/.npm/_npx/...` 路径运行；以后即使 npm 清理该缓存，已安装应用仍能启动。
