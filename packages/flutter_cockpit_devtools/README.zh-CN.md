# flutter_cockpit_devtools

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

CLI JSON 输出统一为 `snake_case`。
`launch-app` 会先自动探测 `cockpit/main.dart`，找不到再退回 `lib/main.dart`。
`run-script` 写出的 bundle 只要状态是 `failed`，命令就会非零退出。

已验证可直接运行的 `run-command` 形状：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"command_id":"assert-inbox","command_type":"assert_text","parameters":{"text":"Inbox"}}'
```

Locator 规则：

- 先用 `key`、`text`、`semantic_id`。
- 只有还不够准时，才继续补 `route`、`type`、`path`、嵌套 `ancestor`。
- `path` 是 fuzzy 匹配：`body`、`slivers`、数字索引这类噪声段会被忽略，所以 `scaffold.body/custom_scroll_view.slivers/0/...` 这类形状也能命中同一目标。
- 需要兜底时用 `fallbacks`，不要把所有条件都塞进一个超长 locator。

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

同时还会暴露 goals、contracts、task summary、roots、package read 与闭环提示词相关的 resources/prompts。

## 说明

- 把 `app.json` 持久化下来并跨步骤复用，这是推荐的 app 引用方式。
- `list_apps` 只在 MCP 中暴露，因为 CLI 每次调用都是无状态进程，不保留内存中的 app registry。
- `read_logs` 会优先读取 app-centric 的 runtime 日志；如果 `available=true` 但 `lines` 为空，通常表示应用这次没有产生日志，不代表异常。
- `pub` 默认返回裁剪后的依赖操作结果，而不是整段 `pub` 日志。
- `analyze_files` 适合低 token 的定点诊断；只有在问题是全仓级别时才用 `analyze_workspace`。
- `lsp` 使用相对路径和从 1 开始的行列号，AI 不需要手写 file URI 或做 0 基换算。
- 用 `minimal`、`standard`、`inspect`、`evidence` 控制 token 与信息量。
- 应用交互命令使用 `timeout_ms`；workspace 工具使用 `timeout_seconds`。除非明确知道任务会很慢，否则先用默认值。
- `pub_dev_search` 走有界网络请求；宿主机直连 TLS 不稳定时，会退回本地 Python fetch。
- 更底层的 session service 仍保留在 Dart API 中，但推荐公开主工作流已经切到 app-first。

## 验证

发布级 MCP 验证：

```bash
dart run tool/verify_mcp_surface.dart
```
