# flutter_cockpit_devtools

[English](README.md)

`flutter_cockpit_devtools` 是 `flutter_cockpit` 的 host 侧配套包。

它把应用内运行时 instrumentation 变成 AI 可消费的工作流：

- 用于 launch、query、run、snapshot collection、task orchestration 和 validation 的 CLI 命令
- 用于 AI 原生接入同一套工作流的 MCP tools
- task-run bundle 写入与 summary 读取
- 面向 Android emulator、iOS Simulator 以及本地 macOS、Windows、Linux desktop 运行的 host 侧截图和录屏 adapter
- artifact validation，包括截图、视频和关键帧覆盖率校验

## 安装

把它加到 host 侧 Dart 包的 `dev_dependencies`。

从 pub：

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
```

或者直接从 Git：

```yaml
dev_dependencies:
  flutter_cockpit_devtools:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit_devtools
```

## CLI 入口

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_mcp
```

## 当前包含内容

- CLI 与 MCP 共用的 shared application services
- task orchestration 与 delivery validation
- 面向 AI 消费的 bundle summary shaping，包括 acceptance-facing semantic evidence，使后续 AI 可以直接比较最终 UI 状态
- host 侧 capture 与 recording strategy resolution
- remote session client 与 bootstrap launcher

应用内运行时层在配套包 `flutter_cockpit` 中。

完整工作流与当前支持平台请看仓库根目录 README。
