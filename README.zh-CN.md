# flutter_cockpit

[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)
[![flutter_cockpit on pub.dev](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=flutter_cockpit)](https://pub.dev/packages/flutter_cockpit)
[![flutter_cockpit_devtools on pub.dev](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=flutter_cockpit_devtools)](https://pub.dev/packages/flutter_cockpit_devtools)

[English](README.md)

`flutter_cockpit` 是一套面向生产环境的 Flutter AI 控制与验证基础设施。

它给 AI 提供一条完整闭环：

- 启动或复用应用
- 读取 route、UI、网络、日志、运行时错误和诊断信息
- 执行单条命令或批量命令
- 在开发期热重载或热重启
- 采集截图和录屏
- 写出并验证交付 bundle
- 通过 CLI 与 MCP 暴露同一套能力

## 安装包

```yaml
dependencies:
  flutter_cockpit: any

dev_dependencies:
  flutter_cockpit_devtools: any
```

包地址：

- [`flutter_cockpit` on pub.dev](https://pub.dev/packages/flutter_cockpit)
- [`flutter_cockpit_devtools` on pub.dev](https://pub.dev/packages/flutter_cockpit_devtools)

## 包结构

- [`packages/flutter_cockpit`](packages/flutter_cockpit)：应用内运行时、远程会话服务、命令执行、快照、截图、录屏
- [`packages/flutter_cockpit_devtools`](packages/flutter_cockpit_devtools)：宿主侧 CLI、MCP、编排、bundle 写入、验证、workspace tooling

## 推荐闭环

开发与调试优先走这条路径：

1. `list-targets`
2. `launch-app --app-json /tmp/app.json`
3. `read-app --app-json /tmp/app.json --profile minimal`
4. `run-command`、`run-batch`、`inspect-ui`、`read-network`、`wait-idle`、`read-errors`、`read-logs`
5. `hot-reload` 或 `hot-restart`
6. 循环直到应用正确

交付阶段：

1. 已有运行中应用时用 `run-script`
2. 需要工具全权负责启动、基线、执行和分类时用 `run-task`
3. 做最终完成声明时用 `validate-task`

公共面是 app-first，而不是 session-handle-first。把 `app.json` 持久化下来并跨步骤复用。CLI 和 MCP 输出使用 lower camel case keys。
只要请求体不再是几行以内，就优先使用 `--command-file`、`--commands-file`、`--config-json`。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
代码侧问题优先走 `analyze-files`、`lsp`、`grep-package-uris`、`read-package-uris`、`pub`，再升级到全仓级命令。

Locator 是多信号模型。先用 `text`、`tooltip`、`semanticId`；只有应用本身已经出于产品原因暴露了稳定 `key` 时才使用 `key`。仍然不够准时，再补 `route`、`type`、`path`、嵌套 `ancestor` 或短 `fallbacks`。`path` 是 fuzzy 匹配，会忽略 `body`、`slivers`、数字索引这类噪声段。

## 快速开始

把 cockpit 启动入口放到 `cockpit/main.dart`，不要改动正常生产入口：

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

把 `package:your_app/app_shell.dart` 替换成你现有应用根组件或 bootstrap 的真实 import。`launch-app` 会注入 `FLUTTER_PILOT_REMOTE_*` 这组 dart-define，所以 `resolveFromEnvironment(...)` 可以在不接管生产入口的前提下启用远程控制面。
如果现有应用内部已经自己持有 `MaterialApp`，就用 `FlutterCockpitApp` 包住那层 app shell，并把 `FlutterCockpit.navigatorObserver` 接到原来的 navigator 上，不要再嵌一层新的 `MaterialApp`。

运行 example：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir examples/cockpit_demo \
  --platform macos \
  --device-id macos \
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
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

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
- 应用接入参考：[`skills/flutter-cockpit/examples/flutter-app-setup.md`](skills/flutter-cockpit/examples/flutter-app-setup.md)
- CLI 示例：[`skills/flutter-cockpit/examples/cli-command-reference.md`](skills/flutter-cockpit/examples/cli-command-reference.md)
- Skill 契约：[`docs/contracts/flutter-cockpit-skill-contract.md`](docs/contracts/flutter-cockpit-skill-contract.md)
- Bundle 契约：[`docs/contracts/task-run-bundle.md`](docs/contracts/task-run-bundle.md)

更底层的 development-session 和 remote-session building block 仍然保留在 Dart API 中，供特殊宿主使用，但它们已经不是推荐的公开主工作流。

`list_apps` 故意只在 MCP 中暴露。CLI 是无状态进程，推荐把 `app.json` 落盘并跨步骤复用，而不是依赖主机侧 app registry。
应用交互命令使用 `timeoutMs`；workspace 工具使用 `timeoutSeconds`。
对代码侧问题，CLI 和 MCP 暴露的是同一套 workspace intelligence；在 shell agent 里，CLI 配合 `--output-json` 和 `jq` 往往是最低成本路径。
