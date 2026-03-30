# flutter_cockpit_devtools

[English](/Users/iota9star/Development/workspace/flutter/flutter_pilot/packages/flutter_cockpit_devtools/README.md)

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

## 推荐 CLI

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-app --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools read-app --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-command --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-batch --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-script --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
```

推荐 app-first 闭环：

1. `launch-app --app-json /tmp/app.json`
2. `read-app --app-json /tmp/app.json --profile minimal`
3. `run-command` 或 `run-batch`
4. 需要时再用 `inspect-ui`、`read-errors`、`read-logs`、`wait-idle`
5. `hot-reload` 或 `hot-restart`
6. 交付时用 `run-script`、`run-task` 或 `validate-task`

CLI JSON 输出统一为 `snake_case`。

已验证可直接运行的 `run-command` 形状：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-command \
  --app-json /tmp/app.json \
  --command-json '{"command_id":"assert-inbox","command_type":"assert_text","parameters":{"text":"Inbox"}}'
```

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
- `read_package_uris`
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
- 用 `minimal`、`standard`、`inspect`、`evidence` 控制 token 与信息量。
- 更底层的 session service 仍保留在 Dart API 中，但推荐公开主工作流已经切到 app-first。
