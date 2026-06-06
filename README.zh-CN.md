# flutter_cockpit

[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)
[![flutter_cockpit on pub.dev](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=flutter_cockpit)](https://pub.dev/packages/flutter_cockpit)
[![flutter_cockpit_devtools on pub.dev](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=flutter_cockpit_devtools)](https://pub.dev/packages/flutter_cockpit_devtools)

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
  flutter_cockpit: ^1.0.0

dev_dependencies:
  flutter_cockpit_devtools: ^1.0.0
```

如果只有 `cockpit/main.dart` import runtime，优先把 `flutter_cockpit`
放到 `dev_dependencies`。只有宿主明确选择共享入口，或需要把 runtime
作为正式发布集成的一部分时，才放到生产 `dependencies`。

包地址：

- [`flutter_cockpit` on pub.dev](https://pub.dev/packages/flutter_cockpit)
- [`flutter_cockpit_devtools` on pub.dev](https://pub.dev/packages/flutter_cockpit_devtools)

安装 Dart 包本身，并不会自动安装 AI skill，也不会自动提供全局可调用的 MCP 启动命令。这两件事都属于宿主侧额外配置。

## 安装 Skill

仓库内维护的 skill 位于 [`skills/flutter-cockpit`](skills/flutter-cockpit)。

优先让当前 AI host 自己帮你安装。下面这段提示词可以直接复制给 AI：

```text
Install the flutter-cockpit skill for the current AI host by following https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md
```

完整宿主侧说明见 [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)。

## 安装 MCP

`flutter_cockpit` 没有单独拆出一个 MCP 包。MCP server 由 `flutter_cockpit_devtools` 提供。

一次性启动：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

如果宿主需要全局命令，先全局安装 devtools：

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_mcp
```

## 主流 Agent 的 MCP 配置

本地 MCP server 的典型启动命令是：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

如果你已经把 `flutter_cockpit_devtools` 全局安装好了，下面这些示例里的 `dart run ... serve-mcp` 也都可以直接替换成 `flutter_cockpit_mcp`。

### Codex

添加本地 stdio server：

```bash
codex mcp add flutterCockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

验证：

```bash
codex mcp list
```

### Claude Code

添加本地 stdio server：

```bash
claude mcp add --transport stdio flutter-cockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
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
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
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
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
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
  "mcp": {
    "flutterCockpit": {
      "type": "local",
      "command": [
        "dart",
        "run",
        "flutter_cockpit_devtools:flutter_cockpit_devtools",
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
- [`packages/flutter_cockpit_devtools`](packages/flutter_cockpit_devtools)：宿主侧 CLI、MCP、编排、bundle 写入、验证、workspace tooling

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

target-first 或非 Flutter / 系统直控场景：

1. `launch-target`
2. `read-target --profile minimal`
3. 需要时使用 `inspect-surface`、`run-shell`，或者在目标解析成 Flutter 应用后继续走现有 app/batch 命令
4. 在最终声明前，用 CLI `read-task-bundle-summary`、MCP `read_task_bundle_summary` 或 `validate-task` 读取 `targetKind`、`primaryExecutionPlane`、`planesUsed`、`surfaceKindsUsed`、`fallbackCount` 和 fallback gates

target-first 流程现在会按平台真实能力工作，而不是假装所有目标都是同一种 Flutter app：

- `launch-target` 会写出标准化的 `target.json`，并把桌面 Flutter 启动结果归一化成 `desktopApp`，而不是一律记成移动端 `flutterApp`。
- `read-target` 继续坚持 summary-first。Flutter 和桌面 Flutter 目标可以复用远端 Flutter 摘要；浏览器或直接系统目标在没有 live semantic plane 时会退回 capability-only 摘要。
- `inspect-surface` 会优先观察目标当前真正的前台表面。Flutter 目标优先 inspect semantic plane；桌面 Flutter 目标会先尝试远端语义 inspect，只有这条语义链不可用时才回落到原生窗口/截图证据链；直接系统目标则保持 capability/capture-first。
- `run-shell` 已经支持 target-aware。可以用 `--scope target --target-json /tmp/target.json` 绑定标准化 target，用 `--scope android --device-id <id>` 走 `adb shell`，用 `--scope ios --device-id <simulator-udid>` 走 `xcrun simctl spawn`；桌面 scope 则在平台真实暴露 shell 能力时走宿主侧执行。

公共面是 app-first，而不是 session-handle-first。如果省略 `--app-json`，`launch-app` 会把最新 handle 写到当前工作目录下的 `.dart_tool/flutter_cockpit/latest_app.json`，后续 app 命令会自动复用它。CLI 和 MCP 输出使用 lower camel case keys。
如果命令同时支持 `--app-json` 和 `--base-url`，优先级是：显式 `--app-json`，然后显式 `--base-url`，最后才是当前工作目录里的隐式 latest app handle。
只要请求体不再是几行以内，就优先使用 `--command-file`、`--commands-file`、`--config-json`。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
代码侧问题优先走 `analyze-files`、`lsp`、`grep-package-uris`、`read-package-uris`、`pub`，再升级到全仓级命令。
如果后续几步已经明确，而且流程会跨路由，比如列表 -> 编辑 -> 列表，优先把它们收成一次有序的 `run-batch`，不要拆成多次 `run-command` 往返。这样更省 token，也更能避开路由切换窗口期的状态抖动。
如果 app summary 已经暴露了有界的工作流计数或状态字段，优先先读这些 bounded summary，再决定是否打开更重的 inspect 载荷。

Locator 是多信号模型。先用 `text`、`tooltip`、`semanticId`；只有应用本身已经出于产品原因暴露了稳定 `key` 时才使用 `key`。仍然不够准时，再补 `route`、`type`、`path`、嵌套 `ancestor` 或短 `fallbacks`。`path` 是 fuzzy 匹配，会忽略 `body`、`slivers`、数字索引这类噪声段。

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
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform <platform> \
  --device-id <device-id> \
  --app-json /tmp/flutter_cockpit/app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/app.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

web 使用 `list-targets` 返回的真实浏览器设备 ID 运行同一闭环：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform web \
  --device-id <browser-device-id> \
  --app-json /tmp/flutter_cockpit/web_app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --profile minimal
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

对于 web，宿主机会保持原有 HTTP 会话面不变，并在 `localhost` 上运行一个 bridge，让浏览器应用通过 WebSocket 回连。
`hot-reload` 和 `hot-restart` 继续走 development supervisor；浏览器录屏则仍然由宿主侧驱动，并依赖本机桌面系统授予屏幕采集权限。

AI-first 项目验证建议分两层：

- 快速 verifier 用于日常 edit -> reload -> assert 闭环：启动应用、驱动一个代表性的生产流程、hot reload、验证变更后的状态、必要时采集一张截图、读取运行时错误、停止应用。失败 JSON 应保持紧凑，优先包含已完成阶段、失败命令元数据、最终路由或状态预览、有界 runtime error 预览和 artifact 引用。
- 发布 verifier 用于昂贵表面：增加录屏、hot restart、网络与日志读取、target-first inspect、多平台覆盖，以及 acceptance/delivery gate。

录屏链路应由 capability 驱动，而不是写死平台假设：桌面和真实设备可能走 remote 或 host adapter，web 可能走 browser-host，iOS 模拟器通常走 simulator-native tooling，Android 模拟器通常走 device tooling。如果宿主权限挡住录屏但 app control 仍然通过，应把它报告为结构化环境 warning，而不是掩盖应用验证结果。

## CLI 公共面

推荐命令：

- `list-targets`
- `launch-app`
- `read-app`
- `inspect-ui`
- `run-command`
- `run-batch`
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
`run-script` 写出的 bundle 只要状态是 `failed`，命令就会非零退出。
依赖和源码问题优先走 `analyze-files`、`lsp`、`grep-package-uris`、`read-package-uris`、`pub`，再考虑更重的 workspace 级检查。

## MCP 公共面

通过 stdio 启动：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

核心工具：

- `list_targets`
- `launch_app`
- `list_apps`
- `read_app`
- `inspect_ui`
- `run_command`
- `run_batch`
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

workspace 工具：

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

- `cockpit://workspace/skill-contract`
- `cockpit://workspace/task-bundle-contract`
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
- Devtools README：[`packages/flutter_cockpit_devtools/README.md`](packages/flutter_cockpit_devtools/README.md)
- Skill：[`skills/flutter-cockpit/SKILL.md`](skills/flutter-cockpit/SKILL.md)
- Skill 安装：[`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)
- 应用接入参考：[`skills/flutter-cockpit/examples/flutter-app-setup.md`](skills/flutter-cockpit/examples/flutter-app-setup.md)
- CLI 示例：[`skills/flutter-cockpit/examples/cli-command-reference.md`](skills/flutter-cockpit/examples/cli-command-reference.md)
- Skill 契约：[`docs/contracts/flutter-cockpit-skill-contract.md`](docs/contracts/flutter-cockpit-skill-contract.md)
- Bundle 契约：[`docs/contracts/task-run-bundle.md`](docs/contracts/task-run-bundle.md)

## 致谢

感谢 Dart 团队官方的 [Dart Tooling MCP Server](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server)，为 Dart 和 Flutter 工作流提供了很强的 MCP tooling 基础。
`flutter_cockpit` 在这套基础之上，进一步针对 AI 独立开发应用的使用场景做了方法级优化，包括 app-first 句柄、低 token 默认路径、有界结果形状，以及完整闭环的交付工作流。

更底层的 development-session 和 remote-session building block 仍然保留在 Dart API 中，供特殊宿主使用，但它们已经不是推荐的公开主工作流。

`list_apps` 故意只在 MCP 中暴露。CLI 是无状态进程，推荐把 `app.json` 落盘并跨步骤复用，而不是依赖主机侧 app registry。
应用交互命令使用 `timeoutMs`；workspace 工具使用 `timeoutSeconds`。
对代码侧问题，CLI 和 MCP 暴露的是同一套 workspace intelligence；在 shell agent 里，CLI 默认 stdout 是完整 AI 语义渲染。需要 `jq` 管道时加 `--stdout-format json`，后续步骤必须从磁盘重新打开结构化结果时使用 `--output <path> --output-format json`。
