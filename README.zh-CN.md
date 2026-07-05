# flutter_cockpit

[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)
[![flutter_cockpit on pub.dev](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=flutter_cockpit)](https://pub.dev/packages/flutter_cockpit)
[![cockpit on pub.dev](https://img.shields.io/pub/v/cockpit?logo=dart&label=cockpit)](https://pub.dev/packages/cockpit)

[English](README.md)

`flutter_cockpit` 是一套面向生产环境的 Flutter AI 控制与验证基础设施。

它给 AI 提供一条完整闭环：

- 启动或复用应用
- 当目标并不只是 Flutter UI 时，也可以直接启动或复用 target
- 读取 route、UI、网络、日志、运行时错误和诊断信息
- 执行单条命令或批量命令
- 在 Flutter 语义面、原生 UI 面、系统面、宿主面之间按真实能力切换
- 在开发期热重载或热重启
- 采集截图和录屏
- 写出并验证交付 bundle
- 通过 CLI 与 MCP 暴露同一套能力

## 安装包

最低工具链要求：Flutter 3.32.0 或更高版本，也就是 Dart 3.8.0 或更高版本。
这个下限可以让 `flutter_test`、`dart_mcp` 和宿主侧 AI 工具链处在同一套可解析依赖图中，
不需要通过 `dependency_overrides` 覆盖 Flutter SDK 的 pin。

```yaml
dependencies:
  flutter_cockpit: ^1.1.4

dev_dependencies:
  cockpit: ^1.1.4
```

如果只有 `cockpit/main.dart` import runtime，优先把 `flutter_cockpit`
放到 `dev_dependencies`。只有宿主明确选择共享入口，或需要把 runtime
作为正式发布集成的一部分时，才放到生产 `dependencies`。

包地址：

- [`flutter_cockpit` on pub.dev](https://pub.dev/packages/flutter_cockpit)
- [`cockpit` on pub.dev](https://pub.dev/packages/cockpit)

维护者发布顺序：先发布 `packages/flutter_cockpit`，再发布 `packages/cockpit`。
宿主侧 `cockpit` 包会从 pub.dev 解析 runtime 包，因此 `cockpit` 的 dry-run
和正式发布都必须先看到匹配版本的 `flutter_cockpit` 已经在线可用。

安装 Dart 包本身，并不会自动安装 AI skill，也不会自动提供全局可调用的 MCP 启动命令。这两件事都属于宿主侧额外配置。

## 安装 Skill

仓库内维护的 skill 位于 [`skills/flutter-cockpit`](skills/flutter-cockpit)。

优先让当前 AI host 自己帮你安装。下面这段提示词可以直接复制给 AI：

```text
Install the flutter-cockpit skill for the current AI host by following https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md
```

完整宿主侧说明见 [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)。

## Agent 接入

仓库已内置主流 Agent 的本地接入资产：

- Codex marketplace: [`.agents/plugins/marketplace.json`](.agents/plugins/marketplace.json)
- Codex plugin: [`plugins/codex/flutter-cockpit`](plugins/codex/flutter-cockpit)
- Claude Code skill: [`.claude/skills/flutter-cockpit`](.claude/skills/flutter-cockpit)
- Claude Code plugin: [`plugins/claude-code/flutter-cockpit`](plugins/claude-code/flutter-cockpit)
- Cursor rule: [`.cursor/rules/flutter-cockpit.mdc`](.cursor/rules/flutter-cockpit.mdc)
- Cursor skill/MCP: [`.cursor/skills/flutter-cockpit`](.cursor/skills/flutter-cockpit), [`.cursor/mcp.json`](.cursor/mcp.json)
- Kiro steering: [`.kiro/steering/flutter-cockpit.md`](.kiro/steering/flutter-cockpit.md)
- Kiro Power/MCP: [`plugins/kiro/flutter-cockpit`](plugins/kiro/flutter-cockpit), [`.kiro/settings/mcp.json`](.kiro/settings/mcp.json)
- OpenCode/OMP skill: [`.opencode/skills/flutter-cockpit`](.opencode/skills/flutter-cockpit), [`.pi/skills/flutter-cockpit`](.pi/skills/flutter-cockpit), [`.agents/skills/flutter-cockpit`](.agents/skills/flutter-cockpit)
- OpenCode config: [`opencode.json`](opencode.json)

插件、规则、steering、skill 和 MCP 配置见 [`docs/agent-integrations.md`](docs/agent-integrations.md)。

## 安装 MCP

`flutter_cockpit` 没有单独拆出一个 MCP 包。MCP server 由 `cockpit` 提供。

一次性启动：

```bash
dart run cockpit serve-mcp
```

如果宿主需要全局命令，先全局安装 cockpit：

```bash
dart pub global activate cockpit
cockpit_mcp
```

## 主流 Agent 的 MCP 配置

本地 MCP server 的典型启动命令是：

```bash
dart run cockpit serve-mcp
```

如果你已经把 `cockpit` 全局安装好了，下面这些示例里的 `dart run ... serve-mcp` 也都可以直接替换成 `cockpit_mcp`。

### Codex

添加本地 stdio server：

```bash
codex mcp add flutterCockpit -- dart run cockpit serve-mcp
```

验证：

```bash
codex mcp list
```

### Claude Code

添加本地 stdio server：

```bash
claude mcp add --transport stdio flutter-cockpit -- dart run cockpit serve-mcp
```

可以在 Claude Code 里用 `/mcp` 查看，也可以直接在终端验证：

```bash
claude mcp list
```

### Cursor

在 `~/.cursor/mcp.json` 里加入全局配置：

```json
{
  "mcpServers": {
    "flutter-cockpit": {
      "type": "stdio",
      "command": "dart",
      "args": [
        "run",
        "cockpit",
        "serve-mcp"
      ]
    }
  }
}
```

如果想做 repo-local 配置，也可以使用项目内的 `.cursor/mcp.json`。

### VS Code

可以在仓库里添加 `.vscode/mcp.json`，也可以把同样的 server 配置写到用户 profile 的 `mcp.json`：

```json
{
  "servers": {
    "flutterCockpit": {
      "type": "stdio",
      "command": "dart",
      "args": [
        "run",
        "cockpit",
        "serve-mcp"
      ]
    }
  }
}
```

也可以直接通过 Command Palette 里的 `MCP: Add Server` 添加。

### OpenCode

可以在 `~/.config/opencode/opencode.json` 里加全局配置，也可以把同样的块写进项目根目录的 `opencode.json`：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "mcp": {
    "flutterCockpit": {
      "type": "local",
      "command": [
        "dart",
        "run",
        "cockpit",
        "serve-mcp"
      ],
      "enabled": true
    }
  }
}
```

这些宿主的命令和配置入口后续可能会调整。如果你本机看到的 UI 或命令不同，优先以宿主自己的最新 MCP 文档为准：

- Codex：优先看本机 `codex mcp --help`
- Claude Code：[Connect Claude Code to tools via MCP](https://docs.anthropic.com/en/docs/claude-code/mcp)
- Cursor：[Cursor MCP docs](https://docs.cursor.com/context/model-context-protocol)
- VS Code：[VS Code MCP configuration reference](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration)
- OpenCode：[OpenCode MCP servers](https://opencode.ai/docs/mcp-servers)

## 包结构

- [`packages/flutter_cockpit`](packages/flutter_cockpit)：应用内运行时、远程会话服务、命令执行、快照、截图、录屏
- [`packages/cockpit`](packages/cockpit)：宿主侧 CLI、MCP、编排、bundle 写入、验证、workspace tooling

## 推荐闭环

开发与调试优先走这条路径：

1. `list-targets`
2. `launch-app`
3. `read-app --profile minimal`
4. `run-command`、`run-batch`、`inspect-ui`、`read-network`、`wait-idle`、`read-errors`、`read-logs`
5. `hot-reload` 或 `hot-restart`
6. 循环直到应用正确

交付阶段：

1. 已有运行中应用时用 `run-script`
2. 需要工具全权负责启动、基线、执行和分类时用 `run-task`
3. 做最终完成声明时用 `validate-task`

协议入口见 [`docs/contracts/flutter-cockpit-protocol.md`](docs/contracts/flutter-cockpit-protocol.md)。完整 AI 开发闭环契约见 [`docs/contracts/ai-development-protocol.md`](docs/contracts/ai-development-protocol.md)。工作流脚本协议见 [`docs/contracts/control-workflow-protocol.md`](docs/contracts/control-workflow-protocol.md)，机器 schema 见 [`docs/contracts/control-workflow.schema.json`](docs/contracts/control-workflow.schema.json)。

长流程或交付结果不直观时，可以把本地看板指向 `run-script`、`run-task`
或 `validate-task` 使用的同一个 output root：

```bash
dart run cockpit devtools --history-root /tmp/flutter_cockpit/out
```

CLI 和 MCP 摘要仍是低 token 默认入口；看板用于人工查看完整状态、timeline、
截图、录屏和 bundle 文件。历史模型是 `sessionId` 表示一个隔离开发或验证任务，
`taskId` 表示当前目标，`runId` 表示一次执行尝试。默认看板会打开当前最新
workflow `sessionId` scope 并把 URL 固定到具体 scope，避免同一个 history root
里的无关任务混在一起；只有需要跨 session 审计时才切到 `all runs`。传
`--scope latest` 时看板会继续跟随最新任务。Timeline 是 scope 级别的，同一
`sessionId` 的重试会按执行顺序一起展示；run detail 和 bundle 面板仍跟随当前选中
run。截图、录屏、诊断和错误都会关联到所属 run 与事件序号。看板也可以解析粘贴的
workflow YAML/JSON，并以后台 job 方式提交 `runScript` / `validateTask`。从看板提交
真实运行时需要保留 CLI 通常会提供的可执行 envelope，例如 `sessionHandle`、
`baseUrl`、`outputRoot` 和平台 id；在 JSON/YAML 间切换时不要只保留内部 workflow。
提交中的 job 在 live history 文件写入前也会显示；完成后的提交 job 只要 bundle 仍在
同一个 history root 下，也会通过同一套 run API 暴露 bundle summary 和 artifact。
长期 history root 会分页展示 run list，同时保留 scope 总数。过大或部分写入的 bundle
JSON 会显示到 `summaryFileIssues`，不会导致整个看板不可用。run detail 面板还提供
`download bundle`，对应 `GET /api/runs/<runId>/bundle-download`。下载会以受
token 保护的 tar 流式输出，不会把大型视频读入内存；内容包含
`download_manifest.json`、`run_metadata.json`、`bundle/**` 和 `live/**`，
不可用的根目录会记录在 `missingRoots`。

target-first 或非 Flutter / 系统直控场景：

1. `launch-target`
2. `read-target --profile minimal`
3. 需要时使用 `inspect-surface`、`run-shell`，或者在目标解析成 Flutter 应用后继续走现有 app/batch 命令
4. 在最终声明前，用 CLI `read-task-bundle-summary`、MCP `read_task_bundle_summary` 或 `validate-task` 读取 `targetKind`、`primaryExecutionPlane`、`planesUsed`、`surfaceKindsUsed`、`fallbackCount` 和 fallback gates

target-first 流程现在会按平台真实能力工作，而不是假装所有目标都是同一种 Flutter app：

- `launch-target` 会写出标准化的 `target.json`，并把桌面 Flutter 启动结果归一化成 `desktopApp`，而不是一律记成移动端 `flutterApp`。
- `read-target` 继续坚持 summary-first。Flutter 和桌面 Flutter 目标可以复用远端 Flutter 摘要；浏览器或直接系统目标在没有 live semantic plane 时会退回 capability-only 摘要。
- `inspect-surface` 会优先观察目标当前真正的前台表面。Flutter 目标优先 inspect semantic plane；桌面 Flutter 目标会先尝试远端语义 inspect，只有这条语义链不可用时才回落到原生窗口/截图证据链；直接系统目标则保持 capability/capture-first。
- `run-shell` 已经支持 target-aware。可以用 `--scope target --target-json /tmp/target.json` 绑定标准化 target，用 `--scope android --device-id <id>` 走 `adb shell`，用 `--scope ios --device-id <simulator-udid>` 走 `xcrun simctl spawn`（非绝对路径命令会通过 `/bin/sh -lc` 在模拟器内执行）；桌面 scope 则在平台真实暴露 shell 能力时走宿主侧执行。
- `run-shell` 默认是有界、可强杀的。快速探测保持默认超时即可，只有明确知道命令很慢时才传 `--timeout-seconds <n>`。

公共面是 app-first，而不是 session-handle-first。如果省略 `--app-json`，`launch-app` 会把最新 handle 写到当前工作目录下的 `.dart_tool/flutter_cockpit/latest_app.json`，后续 app 命令会自动复用它。CLI 和 MCP 输出使用 lower camel case keys。
`launch-app` 被设计成短命令：等应用就绪、写出可复用 handle 后立即退出。development 模式下由后台 supervisor 持续维护 `flutter run --machine`、日志、reload、restart 和 stop 控制。AI 代理不应该把 `launch-app` 挂到 shell 后台，而应拿返回的 handle 继续调用后续命令。
如果命令同时支持 `--app-json` 和 `--base-url`，`--app-json` 提供应用身份、平台和录制元数据，显式 `--base-url` 只覆盖实时连接地址；省略 `--app-json` 时，显式 `--base-url` 优先于当前工作目录里的隐式 latest app handle。
只要请求体不再是几行以内，就优先使用 `--command-file`、`--commands-file`、`--config`。手写 task/workflow 配置优先用 YAML，生成配置优先用 JSON。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
代码侧问题优先走 `analyze-files`、`lsp`、`grep-package-uris`、`read-package-uris`、`pub`，再升级到全仓级命令。
先做变更，再做观察，按顺序执行。不要把 `run-command` 和依赖它副作用的 `read-app`、`inspect-ui`、`read-network` 并行。
如果后续几步已经明确，而且流程会跨路由，比如列表 -> 编辑 -> 列表，优先把它们收成一次有序的 `run-batch`，不要拆成多次 `run-command` 往返。这样更省 token，也更能避开路由切换窗口期的状态抖动。
会切换路由的 `tap` 应附带 `parameters.expectedRouteName`；在 CI、录屏、模拟器等延迟可预期的验收流程中再加 `parameters.routeTimeoutMs`。`timeoutMs` 是命令的硬上限，不是默认路由等待。关键路由切换后，再补一个针对 `parameters.routeName` 的 `waitFor`。需要等待 loading、弹窗或路由消失时，使用带 `parameters.absent: true` 的 `waitFor`。
`read-app` 和 snapshot 会暴露 focus 状态。看到 `uiSummary.focus.isTextInputFocus` 为 true，或者软件键盘挡住下方控件时，先执行不需要 locator 的 `dismissKeyboard`，再继续滚动或点击。
如果 app summary 已经暴露了有界的工作流计数或状态字段，优先先读这些 bounded summary，再决定是否打开更重的 inspect 载荷。

Locator 是多信号模型。先用 `text`、`tooltip`、`semanticId`；只有应用本身已经出于产品原因暴露了稳定 `key` 时才使用 `key`。仍然不够准时，再补 `route`、`type`、`path`、嵌套 `ancestor` 或短 `fallbacks`。不要只用 `Open`、`Edit`、`Save` 这类高频短动作词做唯一信号；优先使用 `read-app` / `inspect-ui` 暴露的完整可访问标签，并配合 `route` 或 `ancestor`。`path` 是 fuzzy 匹配，会忽略 `body`、`slivers`、数字索引这类噪声段。

## 快速开始

把 cockpit 启动入口放到 `cockpit/main.dart`，不要改动正常生产入口，也不要把 `flutter_cockpit` import 加到生产 `lib/` 代码里：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'package:your_app/app_shell.dart';

Future<void> main() async {
  runApp(buildCockpitDevelopmentApp());
}

Widget buildCockpitDevelopmentApp() {
  return FlutterCockpitApp(
    config: FlutterCockpitConfig.production(
      remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
        fallback: const CockpitRemoteSessionConfiguration(
          enabled: true,
          host: '127.0.0.1',
          port: 47331,
        ),
      ),
    ),
    child: MaterialApp(
      navigatorObservers: <NavigatorObserver>[
        FlutterCockpit.navigatorObserver,
      ],
      home: const AppShell(),
    ),
  );
}
```

把 `package:your_app/app_shell.dart` 替换成你现有应用根组件或 bootstrap 的真实 import。`launch-app` 会注入 `FLUTTER_COCKPIT_REMOTE_*` 这组 dart-define，所以 `resolveFromEnvironment(...)` 可以在不接管生产入口的前提下启用远程控制面。
只有 cockpit 入口自己创建 navigator，或者宿主明确接受共享入口时，才把 `FlutterCockpit.navigatorObserver` 接进去。如果生产应用已经自己持有 `MaterialApp`、`GoRouter` 或其他 router，就在 `cockpit/main.dart` 里用 `FlutterCockpitApp` 包住现有根组件，并把 route 同步留在 cockpit 层，例如监听 app router 后调用 `FlutterCockpit.setCurrentRouteName(...)`。

运行最小 app 闭环：

```bash
dart run cockpit \
  launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run cockpit \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

```bash
dart run cockpit \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

web 使用 `list-targets` 返回的真实浏览器设备 ID 运行同一闭环：

```bash
dart run cockpit \
  launch-app \
  --project-dir <project-dir> \
  --platform web \
  --device-id <browser-device-id> \
  --app-json /tmp/flutter_cockpit/web_app.json
```

```bash
dart run cockpit \
  read-app \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --profile minimal
```

如果 browser-backed 会话报告了真实路由但 `visibleTargetCount: 0`，先重跑 `read-app --profile standard`，不要直接断定应用坏了。当页面看起来被后台化、被节流或仍在重连时，结果会给出 `recommendedNextStep: "recoverBrowserVisibility"`。

```bash
dart run cockpit \
  run-command \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

对于 web，宿主机会保持公开 HTTP 会话面不变，并在 `127.0.0.1` 上运行一个 bridge，让浏览器应用通过 WebSocket 回连。浏览器 DOM 检查、截图、`hot-reload` 和 `hot-restart` 在日常开发验证中应保持严格判定。browser-host 录屏是独立的宿主环境 gate：它依赖 macOS/桌面对终端、Dart、ffmpeg 和浏览器宿主应用授予屏幕采集权限，并且当 ffmpeg 无法证明启动或产物证据时，应在录制启动阶段就失败。

AI-first 项目验证建议分两层：

- 快速 verifier 用于日常 edit -> reload -> assert 闭环：启动应用、驱动一个代表性的生产流程、hot reload、验证变更后的状态、必要时采集一张截图、读取运行时错误、停止应用。失败 JSON 应保持紧凑，优先包含已完成阶段、失败命令元数据、最终路由或状态预览、有界 runtime error 预览和 artifact 引用。
- 发布 verifier 用于昂贵表面：增加录屏、hot restart、网络与日志读取、target-first inspect、多平台覆盖，以及 acceptance/delivery gate。

录屏链路应由 capability 驱动，而不是写死平台假设：桌面和真实设备可能走 remote 或 host adapter，web 可能走 browser-host，iOS 模拟器通常走 simulator-native tooling，Android 模拟器通常走 device tooling。如果宿主权限挡住录屏但 app control 仍然通过，应把它报告为结构化环境 warning，并附上 recorder 失败原因，而不是掩盖应用验证结果。
只有当 stop 结果包含非空 bytes 或非空 source/output 文件支撑的 artifact 时，completed 录屏才算证据；artifact 内容为空或缺失就是失败的证据结果，不能当作视频证明。
命令同时接受 `app.json` 和 `baseUrl` 时，只要 handle 可用就继续传 handle：handle 携带平台、设备、进程和 remote-session 元数据，`baseUrl` 只覆盖实时 HTTP 连接。在没有 app handle 的情况下做 iOS 录屏时，传 `iosDeviceId` / `--ios-device-id`，让宿主侧的模拟器或设备 adapter 选对录制器。

## CLI 公共面

推荐命令：

- `list-targets`
- `launch-app`
- `read-app`
- `inspect-ui`
- `run-command`
- `run-batch`
- `read-system-capabilities`
- `run-system-action`
- `read-network`
- `wait-idle`
- `hot-reload`
- `hot-restart`
- `start-recording`
- `stop-recording`
- `read-logs`
- `read-errors`
- `stop-app`
- `run-script`
- `run-task`
- `validate-task`
- `serve-mcp`

用 `--profile minimal|standard|inspect|evidence` 控制 token 成本。默认先取最小结果，只在需要时升高层级。
`run-script` 和 `run-remote-control-script` 写出的 bundle 只要状态是 `failed`，命令就会非零退出。
依赖和源码问题优先走 `analyze-files`、`lsp`、`grep-package-uris`、`read-package-uris`、`pub`，再考虑更重的 workspace 级检查。
当默认 app-first 路径不是最小真实表面时，可以使用高级公共命令：

- 使用 `launch-target`、`read-target`、`inspect-surface` 和 `run-shell` 处理 target-first、非 Flutter 表面、系统 shell 或宿主窗口探测
- 使用 `launch-remote-session`、`query-remote-session`、`read-remote-status`、`read-remote-snapshot`、`execute-remote-command` 和 `execute-remote-command-batch` 处理直接的 remote-session 闭环
- 使用 `launch-development-session`、`reload-development-session`、`collect-development-probe`、`compare-development-probe` 和 `stop-development-session` 处理常驻的 edit-reload-probe 闭环
- 使用 `read-system-capabilities` 后再调用 `run-system-action`，处理原生 UI、系统弹窗、宿主窗口、模拟器状态、设备定位、外观、内容字号、旋转、emulator 网络速度/延迟、status bar、应用安装/卸载/清数据、权限授权/撤销/重置、文件/媒体准备、截图、录屏、进程/窗口/设备/通知读取、有界原生 UI tree 读取，以及 `resolveBlockers`、`preparePermissions`、`recoverToApp`、`tapNotification`、`readFocusState`、`stabilizeForScreenshot` 等场景宏命令
- 使用 `start-remote-recording` 和 `stop-remote-recording` 只应发生在直接操作 remote session，而不是 app handle 时

面向模拟器优先的开发，system plane 会按真实能力暴露。Android Emulator 走 `adb`：原生坐标、按键、Back/Home、音量键、应用安装/卸载/启动/终止/清数据、权限授权/撤销/重置、应用设置、外观、字号、定位、旋转、emulator 网络条件、通知栏、快捷设置、SystemUI demo-mode status bar 覆盖（`setStatusBar`/`clearStatusBar`）、文件 push/pull、媒体导入、截图、录屏、UI tree、进程/窗口/设备/系统状态读取、通知状态读取、logcat 读取（`readSystemLogs`）、电量模拟（`setBattery`）、连接开关（`setConnectivity`）、shell，以及 UIAutomator 辅助的 `dismissSystemDialog --decision accept|dismiss`，并支持阻塞处理、权限准备、通知点击、应用恢复、focus 读取和截图稳定化等宏命令。iOS Simulator 走 `simctl`：应用生命周期、隐私权限授权/撤销/重置、URL、Settings、外观、内容字号、locale 切换（`setLocale`）、定位、status bar 覆盖、剪贴板、模拟 APNS push、应用安装/卸载/清数据、app container 文件传输、媒体导入、截图、录屏、进程/设备/状态读取、统一日志读取（`readSystemLogs`），以及 `simctl spawn` shell。iOS 原生 UI 和系统弹窗控制在 WebDriverAgent 可达时启用；iOS 宏命令会按能力声明组合 simctl 和 WDA，不可达的 WDA 步骤会明确 skipped 或 blocked，不会伪装成可用。iOS 模拟器的 `activateWindow` 只把 app 拉到前台，不会终止现有 Flutter 调试或 hot reload 会话；需要重启时应显式使用 `terminateApp`。没有稳定公开 API 的模拟器能力，例如 iOS 模拟器音量键和清空全部通知，会报告为 `unsupported` 或 `blocked`；展开通知中心和展开控制中心在 WebDriverAgent 可达时通过 WDA 执行。JSON capability 输出还会暴露 `actionGroups`，调用方可以不写死平台列表，也能发现权限、通知、文件、媒体、证据、设备状态和检查类动作。
桌面宿主（macOS/Windows/Linux）通过内置工具暴露 host-plane 能力：URL/系统设置入口、宿主外观、剪贴板、宿主文件 push/pull 与媒体复制、应用激活/恢复/终止、focus 与设备/系统状态读取、进程/窗口列表、通知、macOS `tccutil` 权限重置、窗口定向输入、原生 UI tree 读取（macOS/Windows）、窗口截图与录屏。Web 目标在浏览器 driver 或 bridge 就绪前 DOM 层输入保持 blocked；已知浏览器 app id 或 process id 后，截图和录屏走宿主窗口 adapter。

CLI 命令非零退出时，先看 stderr 上的 `errorJson: {...}`。对于非用法类失败，`code`、`message` 和可选的 `details` 字段是面向 AI 代理的机器可读恢复面；`Error:` 文本行只是给人看的摘要。
远端 endpoint 失败会尽量保留原始错误码，例如 `bridgeUnavailable`、`artifactNotFound`、`recordingStartFailed`、`invalidPayload`，恢复动作可以直接对准 bridge、artifact 传输、录制前置条件或 payload 问题，而不是盲目重试。
大体量 forensic snapshot 在正常 app/命令读取中保持 summary-first。如果结果包含 `artifactDownloads`，把这些路径当作延迟证据，只有当摘要不足以支撑下一步修复或验收判断时才去拉取完整 diagnostics artifact。
对 `collect-remote-snapshot`，`--emit-artifact-when-large` 让应用把超大 diagnostics 外置成 artifact，`--download-diagnostics-artifacts` 才会把延迟 artifact 显式拉进命令输出。除非这一步真的需要完整 forensic payload，否则保持下载开关关闭。

## MCP 公共面

通过 stdio 启动：

```bash
dart run cockpit serve-mcp
```

推荐 app/target 工具：

- `list_targets`
- `launch_app`
- `launch_target`
- `list_apps`
- `read_app`
- `read_target`
- `inspect_ui`
- `inspect_surface`
- `run_command`
- `run_batch`
- `capture_screenshot`
- `read_system_capabilities`
- `run_system_action`
- `run_shell`
- `wait_idle`
- `hot_reload`
- `hot_restart`
- `start_recording`
- `stop_recording`
- `read_network`
- `read_logs`
- `read_errors`
- `stop_app`
- `run_script`
- `read_task_bundle_summary`
- `run_task`
- `validate_task`

高级 remote-session 工具：

- `list_active_sessions`
- `launch_remote_session`
- `query_remote_session`
- `read_remote_status`
- `read_remote_snapshot`
- `collect_remote_snapshot`
- `execute_remote_command`
- `execute_remote_command_batch`
- `wait_remote_ui_idle`
- `start_remote_recording`
- `stop_remote_recording`

development-session 工具：

- `launch_development_session`
- `query_development_session`
- `reload_development_session`
- `collect_development_probe`
- `compare_development_probe`
- `read_session_logs`
- `stop_development_session`

workspace/roots 工具：

- `add_roots`
- `remove_roots`
- `pub_dev_search`
- `pub`
- `grep_package_uris`
- `read_package_uris`
- `lsp`
- `analyze_files`
- `create_project`
- `analyze_workspace`
- `format_workspace`
- `run_tests`
- `apply_fixes`

资源：

- `cockpit://workspace/protocol`
- `cockpit://workspace/ai-development-protocol`
- `cockpit://workspace/skill-contract`
- `cockpit://workspace/task-bundle-contract`
- `cockpit://workspace/control-workflow-protocol`
- `cockpit://workspace/control-workflow-schema`
- `cockpit://workspace/roots`
- `cockpit://workspace/capabilities`
- `cockpit://app/list`
- `cockpit://app/details{?appId}`
- `cockpit://task/latest`
- `cockpit://task/summary{?bundleDir}`
- `cockpit://package/read{?workspaceRoot,uri}`

Prompts：

- `run_closed_loop_task`
- `inspect_before_claiming_done`
- `recover_from_failed_validation`
- `prepare_acceptance_delivery`
- `create_project_with_validation`

## 示例与文档

- 示例应用：[`examples/cockpit_demo`](examples/cockpit_demo)
- 运行时 README：[`packages/flutter_cockpit/README.md`](packages/flutter_cockpit/README.md)
- 宿主 CLI README：[`packages/cockpit/README.md`](packages/cockpit/README.md)
- Skill：[`skills/flutter-cockpit/SKILL.md`](skills/flutter-cockpit/SKILL.md)
- Skill 安装：[`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)
- 应用接入参考：[`skills/flutter-cockpit/examples/flutter-app-setup.md`](skills/flutter-cockpit/examples/flutter-app-setup.md)
- CLI 示例：[`skills/flutter-cockpit/examples/cli-command-reference.md`](skills/flutter-cockpit/examples/cli-command-reference.md)
- 协议入口：[`docs/contracts/flutter-cockpit-protocol.md`](docs/contracts/flutter-cockpit-protocol.md)
- AI 开发协议：[`docs/contracts/ai-development-protocol.md`](docs/contracts/ai-development-protocol.md)
- Skill 契约：[`docs/contracts/flutter-cockpit-skill-contract.md`](docs/contracts/flutter-cockpit-skill-contract.md)
- Bundle 契约：[`docs/contracts/task-run-bundle.md`](docs/contracts/task-run-bundle.md)
- 工作流协议：[`docs/contracts/control-workflow-protocol.md`](docs/contracts/control-workflow-protocol.md)
- 工作流 schema：[`docs/contracts/control-workflow.schema.json`](docs/contracts/control-workflow.schema.json)

## 致谢

感谢 Dart 团队官方的 [Dart Tooling MCP Server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server)，为 Dart 和 Flutter 工作流提供了很强的 MCP tooling 基础。
`flutter_cockpit` 在这套基础之上，进一步针对 AI 独立开发应用的使用场景做了方法级优化，包括 app-first 句柄、低 token 默认路径、有界结果形状，以及完整闭环的交付工作流。

更底层的 development-session 和 remote-session building block 仍然保留在 Dart API 中，供特殊宿主使用，但它们已经不是推荐的公开主工作流。

`list_apps` 故意只在 MCP 中暴露。CLI 是无状态进程，推荐把 `app.json` 落盘并跨步骤复用，而不是依赖主机侧 app registry。
应用交互命令使用 `timeoutMs`；workspace 工具使用 `timeoutSeconds`。
对代码侧问题，CLI 和 MCP 暴露的是同一套 workspace intelligence；在 shell agent 里，CLI 默认 stdout 是完整 AI 语义渲染。需要 `jq` 管道时加 `--stdout-format json`，后续步骤必须从磁盘重新打开结构化结果时使用 `--output <path> --output-format json`。
