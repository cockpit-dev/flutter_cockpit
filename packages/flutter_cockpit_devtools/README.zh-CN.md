# flutter_cockpit_devtools

[![pub package](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit_devtools)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/LICENSE)

[English](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/README.md)

`flutter_cockpit_devtools` 是 `flutter_cockpit` 的宿主侧工具包。

它提供：

- 面向 AI 的 CLI 命令
- 暴露同一套工作流的 MCP server
- 面向非 Flutter、原生和宿主直控场景的 target-first 入口
- task bundle 写入与验证
- workspace tooling：依赖搜索、包源码读取、工程创建、analyze、format、test、fix

## 安装

需要 Dart 3.8.0 或更高版本。如果在 Flutter workspace 中运行，使用 Flutter 3.32.0+
对应的 SDK。

```yaml
dev_dependencies:
  flutter_cockpit_devtools: ^1.0.0
```

可选的全局安装方式：

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_devtools --help
flutter_cockpit_mcp
```

`flutter_cockpit_mcp` 就是这个包暴露出来的全局 MCP 启动命令。如果不需要全局命令，也可以直接这样启动：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

工具链解析规则：

- 显式可执行文件变量优先：`DART`、`DART_BIN`、`FLUTTER`、`FLUTTER_BIN`。
- 其次支持 SDK 根目录变量：`DART_ROOT`、`DART_SDK`、`FLUTTER_ROOT`、`FLUTTER_SDK`。
- 如果只设置了 `FLUTTER_ROOT` 或 `FLUTTER_SDK`，Dart 命令会使用 Flutter 内置的 Dart SDK。
- 如果都没有设置，Dart 命令会先使用当前 Dart SDK 的可执行文件，再回退到 `PATH` 上的 `dart`；Flutter 命令会先尝试当前内置 Dart 所在的 Flutter SDK，再回退到 `PATH` 上的 `flutter`。

常见宿主配置方式：

- Codex：
  `codex mcp add flutterCockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp`
- Claude Code：
  `claude mcp add --transport stdio flutter-cockpit -- dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp`
- Cursor：
  在 `~/.cursor/mcp.json` 或项目内 `.cursor/mcp.json` 里添加 `flutter-cockpit` 这个 stdio server
- VS Code：
  在 `.vscode/mcp.json` 或用户 profile 的 `mcp.json` 里，用 `"servers"` 添加一个 stdio server
- OpenCode：
  在 `~/.config/opencode/opencode.json` 或项目根 `opencode.json` 里，用 `"mcp"` 添加一个 local server

更完整的宿主侧配置说明，见仓库根 README：

- [主流 Agent 的 MCP 配置](https://github.com/cockpit-dev/flutter_cockpit/blob/main/README.zh-CN.md#主流-agent-的-mcp-配置)

包内也包含一份可直接复制的通用 MCP 配置：
[`example/mcp_config.json`](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/example/mcp_config.json)。

## CLI

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
```

推荐 app-first 闭环：

1. `launch-app`
2. `read-app --profile minimal`
3. `run-command` 或 `run-batch`
4. 需要时再用 `inspect-ui`、`read-network`、`read-errors`、`read-logs`、`wait-idle`
5. `hot-reload` 或 `hot-restart`
6. 交付时用 `run-script`、`run-task` 或 `validate-task`

target-first 闭环：

1. `launch-target`
2. `read-target --profile minimal`
3. `inspect-surface`，或者在目标平台真实暴露 shell 能力时再用 `run-shell`
4. 使用 `read-task-bundle-summary` 或 `validate-task` 做 bundle 交付审查

Flutter 语义无法控制原生 UI、系统弹窗、设备 shell、桌面窗口或非 Flutter
surface 时，使用 Native/System Control Plane：

1. `read-system-capabilities --platform <platform> ...`
2. 只对返回为 `available` 的 action 调用 `run-system-action`
3. 按返回的 `parameters` 合约传参，不要猜 payload key
4. 常见设置优先用直接参数：`--appearance`、`--content-size`、`--font-scale`、`--latitude/--longitude`、`--orientation`、`--network-speed`、`--network-delay`、status-bar 参数和 `--max-depth/--max-nodes`；应用/包与文件/媒体准备使用 `--app-path`、`--grant-permissions`、`--keep-data`、`--source-path` 和 `--destination-path`；系统截图/录屏使用 `--name`、`--purpose`、`--mode`、`--layer` 和 `--output-path`
5. 操作后读取 app、target 或 system state，再判断结果

当当前工作区存在 `.dart_tool/flutter_cockpit/latest_app.json` 时，system 命令会复用其中的 platform、device id、process id 和 platform app id。iOS 模拟器权限优先使用 `grantPermission`，它走稳定的 `simctl privacy grant`。如果 Flutter 语义和 `simctl` 都无法控制 iOS 模拟器原生 UI 或系统弹窗，可以单独启动 WebDriverAgent。iOS 模拟器会默认探测 `http://127.0.0.1:8100`；只有使用自定义 endpoint 时才需要传 `--wda-url` 或设置 `FLUTTER_COCKPIT_IOS_WDA_URL`。endpoint 不可达时原生动作仍保持 blocked；endpoint 可达时，`tap`、`longPress`、`drag`、`typeText`、`pressKey`、`dismissSystemDialog`、`setOrientation` 和 `readUiTree` 可以返回为 `available` 并通过 `run-system-action` 执行。

模拟器支持坚持按真实能力暴露：

- Android Emulator 通过 `adb` 支持原生 tap/drag/text/key、Back/Home、音量键、应用安装/卸载/启动/终止/清数据、权限授权/撤销/重置、URL/系统设置入口、外观、字号、定位、旋转、emulator 网络速度/延迟、通知栏、快捷设置、收起系统 UI、shell 通知、文件 push/pull、媒体导入并触发扫描、截图、录屏、UI tree、进程/窗口/系统状态读取、设备信息读取、通知状态读取和有界 shell 命令。`dismissSystemDialog --decision accept|dismiss` 会先用 UIAutomator 匹配常见 Android 权限/系统弹窗按钮；`dismiss` 找不到时可以回退 Back。
- iOS Simulator 通过 `simctl` 支持应用安装/卸载/启动/终止/清数据、隐私权限授权/撤销/重置、URL 和 Settings 入口、外观、内容字号、定位、status bar 覆盖、剪贴板、模拟 APNS push、app container push/pull、媒体导入、截图、录屏、进程读取、模拟器/设备信息读取和有界 `simctl spawn` 命令。
- iOS Simulator 原生 UI 动作需要可达的 WebDriverAgent endpoint：tap、long press、drag、文本/按键输入、Home、关闭键盘、系统弹窗 accept/dismiss、旋转和原生 UI tree 读取。
- iOS Simulator 音量键、展开通知中心、展开控制中心、清空全部通知没有稳定公开的 `simctl`/XCTest 模拟器 API。因此这些动作会保持 `unsupported` 或 `blocked`，不会伪装成可自动化。需要时按返回的 fallback、已知几何坐标的 WDA 手势或应用内断言处理。

默认 AI-readable 能力行会包含紧凑参数信息，例如
`parameters=[x*:integer | wifiBars:integer[0..3] | appearance*:string(light|dark)]`。
JSON 输出会用结构化 `parameters` 条目暴露同一合约，包括 `required`、`valueType`、
`allowedValues`、`minimum` 和 `maximum`。
JSON 还会包含 `actionGroups`，方便 agent 不写死平台动作名，也能发现权限、通知、文件、媒体、证据、设备状态和检查类能力。

推荐代码侧闭环：

1. `analyze-files --path ...`
2. `lsp --command ...`
3. `grep-package-uris` 或 `read-package-uris`
4. `pub-dev-search` 或 `pub`
5. 只有问题已经不再是局部修改时，才升级到 `run-tests` 或 `analyze-workspace`

CLI JSON 输出使用 lower camel case keys。
如果 `launch-app` 省略 `--app-json`，它会把当前 app handle 写到工作目录里的 `.dart_tool/flutter_cockpit/latest_app.json`，后续 app 命令会自动复用。
`launch-app` 按短命令设计：等待应用 ready、写出 handle，然后退出。development 模式下后台 supervisor 会继续维护 `flutter run --machine`、日志、hot reload、hot restart 和 `stop-app` 控制，所以 agent 不需要也不应该用 shell 后台方式运行 `launch-app`。
`run-shell` 默认有超时并会杀掉超时进程。快速探测保持默认值；只有明确知道 host、adb 或 simctl 命令较慢时才传 `--timeout-seconds <n>`。
如果命令同时支持 `--app-json` 和 `--base-url`，优先级是：显式 `--app-json`，然后显式 `--base-url`，最后才是当前工作目录里的隐式 `.dart_tool/flutter_cockpit/latest_app.json`。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
`run-script` 写出的 bundle 只要状态是 `failed`，命令就会非零退出。
workspace 命令默认把 `--workspace-root` 或 `--parent-directory` 视为当前目录。
当后续几步已经明确，而且流程会跨路由，比如列表 -> 编辑 -> 列表，优先用一次有序的 `run-batch`，不要拆成多次 `run-command` 往返。这样更省 token，也更能避开路由切换窗口期的状态抖动。
`read-app` 和 snapshot 会暴露 focus 状态。看到 `uiSummary.focus.isTextInputFocus` 为 true，或者软件键盘挡住下一个目标时，先执行不需要 locator 的 `dismissKeyboard`，再继续滚动或点击。
`run-command`、`run-batch` 和 `run-script` 会默认给关键变更命令附加
best-effort 的 action 后截图，并挂到对应 command step 上。tap、文本输入、
滚动、拖拽、返回导航等操作不需要额外写截图 JSON 就能留下关键帧证据。
最终验收截图或必须命名的严格证明，使用 `capture-screenshot`。

AI-first 开发时，建议把项目自己的快速 verifier 收敛成同一个小闭环：启动应用、驱动一个代表性流程、hot reload、验证变更后的状态、必要时采集一张截图、读取 runtime errors、停止应用。失败 JSON 应该小到 AI 能先读完再决定是否打开完整 snapshot 或重跑昂贵验证。建议字段包括已完成阶段、失败命令元数据、最终路由或状态预览、有界 runtime error 预览和 artifact 引用。

已验证可直接运行的 `run-command` 形状：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}'
```

已验证的 web 开发闭环：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-app \
  --project-dir <project-dir> \
  --platform web \
  --device-id chrome \
  --app-json /tmp/flutter_cockpit/web_app.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/flutter_cockpit/web_app.json \
  --profile minimal
```

如果浏览器页已经给出了明确路由，但 `visibleTargetCount: 0`，先再跑一次
`read-app --profile standard`，不要立刻把它当成应用坏掉。现在结果里会在
页面疑似处于后台、被节流或仍在重连时返回
`recommendedNextStep: "recoverBrowserVisibility"`。

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  hot-restart \
  --app-json /tmp/flutter_cockpit/web_app.json
```

在 web 上，`launch-app` 现在会先在宿主机 `127.0.0.1` 拉起 bridge，再让浏览器应用通过 WebSocket 回连，同时对 agent 保持原来的 HTTP app surface（`/health`、`/snapshot`、`/commands/execute`、`/recording/*`）不变。
浏览器录屏仍然依赖宿主桌面系统给浏览器和采集链授予屏幕采集权限；如果宿主权限或设备策略阻止采集，`stop-recording` 会返回结构化失败结果，而不是把整个 session 卡死。
项目自有 web 验证应继续严格覆盖 app control、截图和 reload。只有当应用控制链路已经通过，且 browser-host 录屏仅被桌面屏幕采集权限阻止时，才把录屏前置条件降级成结构化环境 warning。

Locator 规则：

- 先用 `text`、`tooltip`、`semanticId`。
- 只有应用本身已经出于产品原因暴露了稳定 `key` 时才使用 `key`，不要为了自动化额外往业务代码里加 key。
- 只有还不够准时，才继续补 `route`、`type`、`path`、嵌套 `ancestor`。
- `path` 是 fuzzy 匹配：`body`、`slivers`、数字索引这类噪声段会被忽略，所以 `scaffold.body/custom_scroll_view.slivers/0/...` 这类形状也能命中同一目标。
- 需要兜底时用 `fallbacks`，不要把所有条件都塞进一个超长 locator。
- `scrollUntilVisible` 现在会在内部滚动分段之间做探测，所以 AI 应该先提升 locator 质量、再调小 `viewportFraction`，不要先写一串盲滚命令。

## 省 Token 的 Shell 用法

当宿主是 shell agent 时，优先使用 CLI，再配合小范围 `jq` 投影：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-app \
  --app-json /tmp/app.json \
  --profile minimal --stdout-format json | jq '{currentRouteName,state}'
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/validate_task.json --stdout-format json | jq '{classification,recommendedNextStep,validationFailures}'

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/validate_task.json \
  --output /tmp/validate_task_result.json \
  --output-format json
```

读取已有 task-run bundle 时，不需要先打开大型原始 artifact：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  read-task-bundle-summary \
  --bundle-dir /tmp/flutter_cockpit/out/20260530T060304005006Z_session-1
```

默认 stdout 是完整 AI 语义渲染；需要立刻接 `jq` 时加 `--stdout-format json`。只有后续步骤要重新打开整份结果时，才使用 `--output <path>` 写入文件；需要结构化 JSON 文件时再加 `--output-format json`。只要请求体不再是几行以内，就优先使用 `--command-file`、`--commands-file`、`--config-json`，不要把长 JSON 直接内联进命令。

## MCP

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
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

同时还会暴露 contracts、capabilities、task summary、roots、package read 与闭环提示词相关的 resources/prompts。

## 说明

- 需要跨目录或跨会话复用时，再把 `app.json` 持久化下来作为 app 引用。
- 如果一直在同一个仓库里工作，默认的 `.dart_tool/flutter_cockpit/latest_app.json` handle 是最低摩擦的路径，通常不需要每一步都重复传 `--app-json`。
- 对已经接入 Cockpit 的应用，优先走 `cockpit/main.dart` 这类 Cockpit 开发入口；网络观测和远程控制面是在这里启用的。
- 如果应用会真的发 HTTP 请求，平台权限也要和行为保持一致：Android 需要 `INTERNET`，Apple 目标需要 outbound client entitlement，并对 loopback HTTP 打开本地网络 ATS 许可。
- `list_apps` 只在 MCP 中暴露，因为 CLI 每次调用都是无状态进程，不保留内存中的 app registry。
- `read_logs` 会优先读取 app-centric 的 runtime 日志；如果 `available=true` 但 `lines` 为空，通常表示应用这次没有产生日志，不代表异常。
- `read_network` 是低 token 的网络排查入口，适合看 endpoint summary、最近失败请求，以及按需返回的有界请求明细；如果问题只和网络有关，优先走 `run_command` -> `wait_idle` -> `read_network`，不要一开始就读大 snapshot。
- 长页面优先先露出稳定的 section 或 card；如果深层控件总是被 sticky header/footer 压住，先把 `viewportFraction` 调到更小，再考虑升级到 `inspect_ui`。
- `pub` 默认返回裁剪后的依赖操作结果，而不是整段 `pub` 日志。
- 对 shell agent，CLI 通常是最低 token 成本的公共入口；对 tool-calling host，则可以直接走同能力的 MCP tool，而不是把大段命令输出重新塞回模型上下文。
- `analyze_files` 适合低 token 的定点诊断；只有在问题是全仓级别时才用 `analyze_workspace`。
- `lsp` 使用相对路径和从 1 开始的行列号，AI 不需要手写 file URI 或做 0 基换算。
- 用 `minimal`、`standard`、`inspect`、`evidence` 控制 token 与信息量。
- 应用交互命令使用 `timeoutMs`；workspace 工具使用 `timeoutSeconds`。除非明确知道任务会很慢，否则先用默认值。
- `pub_dev_search` 走有界网络请求；宿主机直连 TLS 不稳定时，会退回本地 Python fetch。
- 更底层的 session service 仍保留在 Dart API 中，但推荐公开主工作流已经切到 app-first。
- CLI `read-task-bundle-summary`、MCP `read_task_bundle_summary` 与 `validate-task` 会暴露 plane-aware 交付状态，包括 `targetKind`、`primaryExecutionPlane`、`planesUsed`、`surfaceKindsUsed`、`fallbackCount` 和 fallback gates。

## 验证

源码仓库内的 MCP 发布级验证：

```bash
cd packages/flutter_cockpit_devtools
dart run tool/verify_mcp_surface.dart
```

这条 verifier 会把真实的 `serve-mcp` stdio 面、workspace tooling、target-first 命令和交付工具链一起做端到端验证。
仓库内的 `runtime-loop` workflow 会在 macOS 上执行它，把 MCP 和 target-first 能力作为发布闸门的一部分。

包地址：[pub.dev/packages/flutter_cockpit_devtools](https://pub.dev/packages/flutter_cockpit_devtools)
