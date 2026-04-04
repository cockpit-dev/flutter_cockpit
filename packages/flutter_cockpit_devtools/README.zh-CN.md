# flutter_cockpit_devtools

[![pub package](https://img.shields.io/pub/v/flutter_cockpit_devtools?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit_devtools)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit_devtools?logo=dart)](https://pub.dev/packages/flutter_cockpit_devtools/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/LICENSE)

[English](README.md)

`flutter_cockpit_devtools` 是 `flutter_cockpit` 的宿主侧工具包。

它提供：

- 面向 AI 的 CLI 命令
- 暴露同一套工作流的 MCP server
- task bundle 写入与验证
- workspace tooling：依赖搜索、包源码读取、工程创建、analyze、format、test、fix

## 安装

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
```

可选的全局安装方式：

```bash
dart pub global activate flutter_cockpit_devtools
flutter_cockpit_devtools --help
flutter_cockpit_mcp
```

## CLI

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
```

推荐 app-first 闭环：

1. `launch-app --app-json /tmp/app.json`
2. `read-app --app-json /tmp/app.json --profile minimal`
3. `run-command` 或 `run-batch`
4. 需要时再用 `inspect-ui`、`read-errors`、`read-logs`、`wait-idle`
5. `hot-reload` 或 `hot-restart`
6. 交付时用 `run-script`、`run-task` 或 `validate-task`

推荐代码侧闭环：

1. `analyze-files --path ...`
2. `lsp --command ...`
3. `pub-dev-search`、`pub` 或 `read-package-uris`
4. 只有问题已经不再是局部修改时，才升级到 `run-tests` 或 `analyze-workspace`

CLI JSON 输出使用 lower camel case keys。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
`run-script` 写出的 bundle 只要状态是 `failed`，命令就会非零退出。
workspace 命令默认把 `--workspace-root` 或 `--parent-directory` 视为当前目录。

已验证可直接运行的 `run-command` 形状：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"commandId":"assert-inbox","commandType":"assertText","parameters":{"text":"Inbox"}}'
```

Locator 规则：

- 先用 `key`、`text`、`semanticId`。
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
  --profile minimal | jq '{currentRouteName,state}'
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json /tmp/validate_task.json \
  --output-json /tmp/validate_task_result.json

jq '{classification,recommendedNextStep,validationFailures}' \
  /tmp/validate_task_result.json
```

较大的结构化结果优先落到 `--output-json` 文件里，再按需读取；只要请求体不再是几行以内，就优先使用 `--command-file`、`--commands-file`、`--config-json`，不要把长 JSON 直接内联进命令。

## MCP

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

- 把 `app.json` 持久化下来并跨步骤复用，这是推荐的 app 引用方式。
- 对 example 或集成调试工程，优先走 `cockpit/main.dart` 这类 Cockpit 开发入口；网络观测和远程控制面是在这里启用的。
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

## 验证

发布级 MCP 验证：

```bash
dart run tool/verify_mcp_surface.dart
```

包地址：[pub.dev/packages/flutter_cockpit_devtools](https://pub.dev/packages/flutter_cockpit_devtools)
