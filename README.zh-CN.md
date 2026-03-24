# flutter_cockpit

[English](README.md)

`flutter_cockpit` 是一个面向生产环境的 AI 驱动 Flutter 开发基础设施。这个仓库正在朝着完整的 AI 开发闭环演进：控制应用、观察状态、采集证据、写出标准任务产物目录，并把结果交给后续工具链或用户验收流程。

当前这条主线已经证明了这些关键证据路径：

- 低侵入、根级别的应用集成，供 AI 获取运行时访问能力
- 应用内生成的原生验收截图，在原生截图不可用时自动回退到 Flutter 视图截图
- Android 与 iOS 的应用内原生验收录屏，并将视频写入标准 task-run bundle
- 远程 session bridge，使 host 侧工具能够通过 HTTP 检查和控制运行中的应用
- 远程录屏工作流，使 host 侧工具可以启动录屏、执行命令、停止录屏，并把视频持久化到同一个 task-run bundle
- 远程运行时的 host 侧录屏兜底，使 Android 模拟器、iOS Simulator 以及本地 macOS、Windows、Linux 运行在不适合应用内录屏时仍能产出验收视频
- 自举式 bootstrap 工作流，使 host 侧工具能够在 Android、iOS Simulator 以及本地 macOS、Windows、Linux 上自行启动应用、输出可复用的 remote-session handle，并在后续命令里复用，不需要人工预启动

仓库当前还没有覆盖所有平台能力，但协议面和 bundle 格式已经为后续 host 自动化与远程编排预留了稳定边界。

## 工作区结构

- `packages/flutter_cockpit`
  - 共享的控制、采集、session、运行时与 bundle 领域模型
  - 纯 Dart 入口：`package:flutter_cockpit/flutter_cockpit.dart`
  - Flutter 专用入口：`package:flutter_cockpit/flutter_cockpit_flutter.dart`
- `packages/flutter_cockpit_devtools`
  - host 侧 bundle 写入、控制执行器、共享 application services、CLI 与 MCP server
- `examples/cockpit_demo`
  - 一个已接入的 Flutter 示例应用，用来证明应用内控制闭环
- `skills/flutter-cockpit`
  - 面向 AI 的工作流 skill、pressure scenarios 与示例
- `docs/`
  - bundle contract、设计文档与实现计划

对大多数应用，推荐采用低心智负担的双入口模式：保留你现有的生产入口不动，只把 cockpit 专用 bootstrap 放到 `cockpit/main.dart`。当前 example 就是按这个模式组织的：

- `examples/cockpit_demo/cockpit/main.dart`
  - 供 AI 控制、热重载、probe/diff 和验收流程使用的 cockpit 开发入口

## 安装仓库自带 Skill

仓库自带了一个 AI 工作流 skill，路径是 `skills/flutter-cockpit/`。这个目录只是仓库里的源码资产；仅仅克隆仓库并不会让你的宿主 AI 自动启用这个 skill。

如果你想在 AI 宿主里使用它，需要把这个目录安装或链接到“当前宿主实际扫描的 skill 目录”，或者让宿主直接按路径加载这个目录。

具体安装方式是宿主相关的，因此正式说明统一放在：

- [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)

这份安装说明是按“宿主优先”写的：当前 agent 应先识别自己所在的 host，再确认该 host 扫描哪个本地 skill 目录，然后把 `skills/flutter-cockpit/` 安装进去。Codex 和 Claude Code 只是常见示例，不是唯一目标。

可直接复制的提示词：

```text
参照 https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md 安装 flutter-cockpit skill，并根据当前 AI 宿主自动选择正确的 skill 目录。
```

需要明确的边界是：

- 仓库负责维护 `skills/flutter-cockpit/` 这份 skill 源码
- 你的 AI 宿主负责发现、安装与激活
- 仅仅克隆仓库并不等于 skill 已安装

## 当前能力切片

当前仓库已经验证了：

- 基于 `melos` 的 workspace bootstrap
- 控制协议模型的 JSON 往返序列化
- 结构化 locator resolution 与 command results
- 应用内执行这些命令：`tap`、`enterText`、`longPress`、`doubleTap`、`drag`、`fling`、`swipe`、`pinchZoom`、`rotate`、`panZoom`、`multiTouch`、`scrollUntilVisible`、`waitForNetworkIdle`、`waitForUiIdle`、`assertVisible`、`assertText`、`waitFor`、`captureScreenshot`、`collectSnapshot`
- 严格 hit-test miss 策略（`ignore`、`warn`、`fail`），让 AI 可以在探索和 fail-closed 验证之间切换
- 更完整的文本输入请求，包括 focus、selection、`inputAction`
- 显式键盘事件命令：`sendKeyEvent`、`sendKeyDownEvent`、`sendKeyUpEvent`
- 语义动作驱动的可访问性控件操作：`showOnScreen`、`increase`、`decrease`、`dismiss`
- 手势采样 profile（`fast`、`userLike`、`precise`），以及可选的 `sampleHz`、`frameIntervalMs`、`initialHoldMs`
- 低侵入运行时 bootstrap：`FlutterCockpit.runApp`、`FlutterCockpit.ensureInitialized`、`FlutterCockpitApp`、`FlutterCockpitConfig`、`FlutterCockpit.navigatorObserver`
- 共享运行时 ownership 默认策略，使 `FlutterCockpitApp` / `FlutterCockpitHost` 不会在卸载时主动 tear down binding，除非显式指定 `ownsRuntime: true`
- 带命令元数据、capture routing 元数据、失败摘要和截图引用的 session recording
- 标准目录结构的 task-run bundle 写入
- 面向交付的 `delivery.json`
- host 侧 `run-control-script` CLI
- host 侧 `query-remote-session` 与 `run-remote-control-script` CLI
- host 侧 `collect-remote-snapshot` CLI，可在不写完整 task bundle 的情况下抓定向诊断与网络证据
- host 侧 `launch-remote-session` CLI，可在 Android、iOS Simulator 以及 macOS、Windows、Linux 上完成 build/install/launch，并等待 remote session 可达
- 共享 application services，使 CLI 与 MCP 复用同一套 launch/query/run/bundle-summary 工作流
- 一个 `stdio` MCP server，同时暴露：
  - 快速开发闭环：`launch_development_session`、`reload_development_session`、`collect_development_probe`、`compare_development_probe`
  - 重证据/重验证闭环：`launch_remote_session`、`query_remote_session`、`collect_remote_snapshot`、`run_remote_control_script`、`read_task_bundle_summary`、`run_task`、`validate_task`
- 高层 `run-task` 编排工作流：`bootstrap -> baseline -> execute -> observe -> judge -> deliver`
- 分层 runtime snapshot：AI 可保持 `live` 轻量健康检查，按需升级到 `baseline` 或 `investigate`，并把重量级 `forensic` 诊断外置到 bundle artifact 或远程 artifact 下载
- 有界 accessibility-order snapshot summary，供 AI 在 `investigate` / `forensic` 路径下分析可达语义顺序
- interaction pacing 默认策略，使 AI 的点击、输入、手势和滚动能等待目标出现、应用有界延迟，并在录屏时自动变慢
- 一个生产风格的 Todo example，主要依赖 Flutter 原生发现信号，例如 key、semantics、可见文本、route 与 rich diagnostics
- 可被 `flutter_cockpit_devtools` 查询和驱动的运行中应用 session
- 远程命令执行时把截图 payload 回传到 host，使 task-run bundle 里写入真实远程证据文件
- 大型 forensic remote snapshot 通过 `/artifacts/download` 外置传输，使 AI 能拿到完整 widget / network 上下文而不让 inline payload 膨胀
- 远程录屏停止响应时把录屏 artifact 回传给 host，从而让远程 task-run bundle 包含真实视频文件，而不是设备本地占位路径
- 在远程运行已经持有设备句柄时，host 侧录屏 adapter 能使用 `adb screenrecord` 和 `xcrun simctl io recordVideo`
- Flutter 视图截图能力，并把证据挂进 bundle 模型
- Android、iOS、macOS、Windows 与 Linux 上的验收截图能力：移动端可通过 `flutter_cockpit` plugin bridge 走原生验收截图，桌面端则优先走 host 侧截图适配器
- Android 与 iOS 上通过 `flutter_cockpit` plugin bridge 的原生验收录屏
- 带 `recordings/`、`primaryRecordingRef`、`videoAttachmentRefs` 的录屏交付元数据
- 从录屏里抽取交付关键帧，并把 `keyframes/` 证据和 coverage 元数据加入交付链
- Android / iOS / macOS / Windows / Linux 示例宿主工程，可做真实 plugin 编译验证
- 仓库内置的 `flutter_cockpit` skill 资产，包括 pressure scenarios、examples 与 maintainer-facing contract

## Package 入口

当你需要从纯 Dart 工具侧使用协议和 bundle 模型时，使用共享入口：

```dart
import 'package:flutter_cockpit/flutter_cockpit.dart';
```

当你需要在已接入的 Flutter 应用或 widget test 中使用 `FlutterCockpitApp`、`FlutterCockpitRoot`、`CockpitSurface`、`CockpitTargetNode`、`CockpitNativeCapture`、`FlutterViewCapture` 或 `InAppCockpitCommandExecutor` 时，使用 Flutter 专用入口：

```dart
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
```

这个拆分是有意为之的。`flutter_cockpit_devtools` 保持纯 Dart，而 Flutter 专属的采集与 UI instrumentation 留在 Flutter-only surface。对低侵入应用而言，默认路径是 `FlutterCockpitApp` 加原生发现；多数应用不应需要每页 wrapper 或显式 session-controller plumbing。`FlutterCockpitRoot`、`CockpitSurface`、`CockpitTargetNode` 只保留给歧义高或高价值流程。

## MCP 入口

`flutter_cockpit_devtools` 当前提供两个 MCP 入口，底层都复用同一个 `CockpitMcpServer`：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_mcp
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

这两个入口暴露同样的 13 个工具：

- `launch_development_session`
- `query_development_session`
- `reload_development_session`
- `stop_development_session`
- `collect_development_probe`
- `compare_development_probe`
- `launch_remote_session`
- `query_remote_session`
- `collect_remote_snapshot`
- `run_remote_control_script`
- `read_task_bundle_summary`
- `run_task`
- `validate_task`

MCP 层不会包装 shell 命令；它直接调用和 CLI 相同的 shared application services，因此 launch/query/run/bundle 行为在人工入口和 AI 入口之间保持一致。

对于证据密集型工作流，`read_task_bundle_summary`、`run_task` 和 `validate_task` 现在都会暴露稳定的 AI-facing evidence 视图，而不仅仅是原始 `delivery.json` 字段。这层视图会抬升出主截图、主录屏、关键帧、diagnostics artifact 路径和交付 readiness 标记，避免后续 agent 自己从 raw delivery metadata 反推路径。MCP 响应也会在存在时直接暴露 `network_summary` 和 `runtime_summary`。

对验收型运行，这个 summary 还会给出 3 层 AI-facing comparison surface：

- `baseline_evidence`：从 bundle 抬升出来的起始状态快照
- `acceptance_evidence`：最终状态 dossier，包含 route、文本、语义、accessibility，以及紧凑的 runtime / network / rebuild 信号
- `acceptance_delta`：有界 before/after 对比层，突出 route 变化、文本增删、语义变化、accessibility label 变化、网络失败、运行时错误与 rebuild hotspot

它的设计意图很明确：`validate-task` 负责门禁文件完整性、交付一致性，以及 AI-facing acceptance comparison package 是否齐备；它并不会替你“理解屏幕”。AI 仍然需要主动读取 `baseline_evidence`、`acceptance_evidence` 和 `acceptance_delta` 来比较最终 UI 状态。

## Development Session 工作流

对迭代式 AI 开发，优先使用 development-session 闭环，而不是每次都跑完整验收：

1. `launch_development_session`
2. 修改代码
3. 使用 `hot_reload` 或 `hot_restart` 调 `reload_development_session`
4. `collect_development_probe`
5. `compare_development_probe`
6. 重复直到页面状态正确
7. 只有准备交付时才升级到 `run_task` / `validate_task`

这条快循环保持了轻量：

- `quick`
  - route、有界 UI label、network/runtime 计数
- `interactive`
  - route、可见文本、semantic IDs、interactive labels、accessibility summary、带截图的 visual signals，以及紧凑的 network/runtime/rebuild 摘要
- `diagnostic`
  - investigate 级运行时上下文，适合定位 layout / style 问题
- `forensic`
  - 完整 rich diagnostics，必要时外置到 artifact

development session 是长生命周期并且 reload-aware 的。它先通过已验证的 remote-session launcher 启动应用，然后通过 `flutter attach --machine` 挂接一个长存活的 Flutter tool，使 AI 改完代码后能够 hot reload / hot restart，而不是每次都 rebuild + relaunch。supervisor 的 bootstrap 路径现在只清理当前 attempt 自己启动的进程，不再使用宽泛的模式匹配，因此一次失败 launch 不会误伤同项目或同设备上的其他 cockpit session。

development probe 也被设计成 AI-facing，而不是日志堆：

- interactive / diagnostic probe 可以带一张最新截图和标准化 `visualSignals`
- probe diff 会同时比较语义文本/label 与视觉/布局/style 指纹
- 即使文本和 semantic ID 完全没变，纯视觉回归也会在 `compare_development_probe` 里显式体现出来

## 高层 Task 工作流

`flutter_cockpit_devtools` 还提供了一条高层编排入口，对应仓库 skill 里的那条工作流。

CLI：

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-task \
  --config-json path/to/run_task.json \
  --output-json path/to/result.json
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  validate-task \
  --config-json path/to/validate_task.json \
  --output-json path/to/result.json
```

MCP：

- `run_task`
- `validate_task`

这层编排不会发明新的 app-side 行为。它只是把现有 launch/query/run/bundle services 组合成显式流程：

1. bootstrap 或复用 session
2. 记录 preflight status
3. 按需注入 baseline screenshot command
4. 执行结构化 control script
5. 读取持久化 bundle summary
6. 把结果分类成 `completed`、`failed_with_evidence`、`blocked_by_environment` 或 `needs_more_work`

`validate-task` / `validate_task` 是这条路径之上的最终交付门禁，而不是 `run_task` 的替代品。它会验证这些持久化产物：

- `acceptance.md`
- `environment.json`
- 主截图和主录屏引用
- 磁盘上必须存在的 artifact 文件
- 当任务声明需要时，对应的语义验收证据

当 host 侧有 `ffprobe` 时，`validate-task` 会用它来验证截图和录屏是否真的是可读媒体文件，而不是只看文件是否存在。若没有 `ffprobe`，则回退到内置 PNG / MP4 结构校验，从而在产物损坏时继续 fail closed。

只要存在主录屏，bundle writer 还会提取多张 PNG 关键帧写进 `keyframes/`，并把 coverage 元数据写入 `delivery.json`。`validate-task` 会把关键帧缺失或 coverage 不足直接判定为交付失败，因此“有一个可读视频文件”已经不再足以支撑生产级完成结论。

当 `requireAcceptanceSemanticEvidence` 开启时，`validate-task` 还要求 bundle summary 中存在 acceptance-facing semantic signals。这不意味着 validator 会做计算机视觉；它意味着 bundle 必须包含足够的最终 route / text / semantics 证据，以及一份有界 final-state dossier，供后续 AI 直接比较 UI 状态。

最终 acceptance screenshot 也会在 capture 前经过 quiet-state gate：运行时会等待 UI 静稳；如果网络观察开启，也会等待有界 network idle。对于需要严格门禁而不是 best-effort pre-capture waiting 的流程，应在最终验收步骤前显式调用 `waitForUiIdle`。

当 agent 需要编排工作流时，用 `run_task`。当 agent 准备做最终完成声明、并且必须证明 bundle 已 delivery-ready 时，用 `validate-task`。

对 host 驱动的远程工作流，如果 session health 已经暴露真实 `CockpitEnvironment`，`run_task` 现在可以省略 script 里的 `environment`。通过 `launch-remote-session` 启动的会话会自动满足这个条件，因为 devtools 会把真实 Flutter 版本注入 app bootstrap，并由运行时通过 remote health 发布出来。

如果 session 是人工启动且 health 没有暴露环境信息，则仍然需要显式脚本环境；`flutter_cockpit` 不会伪造环境元数据。

## Snapshot Profiles

`flutter_cockpit` 现在把 runtime observation 设计成了分层协议，而不是一份永远膨胀的大 snapshot payload。

- `live`
  - `/health`、轮询、wait/assert 流程的默认档位
  - 保持 route 和 visible target 元数据轻量
- `baseline`
  - `collectSnapshot` 与 baseline/acceptance screenshot 的默认档位
  - 增加有界 layout 和 content 摘要
- `investigate`
  - 当 locator 有歧义、断言失败、UI 状态看起来不对，或 AI 需要过滤后的 request/response / runtime 证据时使用
  - 增加有界 style 细节、ancestor 摘要、padding/alignment/typography/opacity/icon/image 等标准化 widget 属性、diagnostic properties、network endpoint 摘要和 recent runtime events
- `forensic`
  - 只在轻量档位还不够时使用
  - 通过把完整 snapshot 外置到 `diagnostics/*.json`，让 bundle 时间线保持可读，并只留下带 `diagnosticsArtifactRef` 的摘要版 inline snapshot

rebuild diagnostics 仍然是显式 opt-in。只有在 runtime bootstrap 通过 `CockpitDiagnosticsConfig(enableRebuildTracking: true)` 开启后，`investigate` 和 `forensic` 才会返回 rebuild summary。

作为 AI 调用方，不要默认使用 `forensic`。高频流程保持便宜，按需升级。

对不想跑完整 task bundle 的直接远程 runtime 诊断，`collect-remote-snapshot` 现在支持这些一等 CLI 过滤参数：

- `--include-runtime-activity`
- `--max-runtime-entries`
- `--runtime-only-errors` / `--no-runtime-only-errors`
- `--runtime-message-contains "..."`

这样 AI 就可以在同一套 host 工具面里直接查询 Flutter 错误与日志，而不是只能看网络。

## 已验证工作流

当前已验证的端到端路径是：

1. 在应用根部 bootstrap `flutter_cockpit`，优先使用 `FlutterCockpit.runApp(MyApp(), config: ...)` 或 `FlutterCockpitApp(config: ..., child: MyApp())`
2. 在 debug/dev 环境暴露本地 remote session bridge，供 host 侧 AI 工具使用
3. 当 host 侧需要自行启动应用时，用 `launch-remote-session` 启动并持久化 session-handle JSON
4. 在后续命令中通过 `query-remote-session --session-json ...` 和 `run-remote-control-script --session-json ...` 复用这个 handle，而不是手工传 base URL 和 device ID
5. 让 host 启动的 session 自动通过 remote health 暴露 `CockpitEnvironment`；如果运行时没有发布环境，则再显式提供脚本环境
6. 通过 `InAppCockpitCommandExecutor` 或 host 侧 adapter 执行结构化命令
   当 locator-based 控制不够时，手势可以回退到显式坐标（`x`/`y`、`startX`/`startY`），而不是强迫接入方加 app-specific wrapper
   当页面还在稳定过程中，让内建 interaction policy 等待目标出现并应用 pre-action pacing；只有个别流程真的需要更多松弛时，再用 `preActionTimeoutMs`、`preActionPollIntervalMs`、`preActionVisualDelayMs`
7. 通过 `CockpitSessionController` 记录每个命令结果，包括运行中应用返回的 inline remote artifact payload
8. 对诊断流程抓 Flutter-view 截图，对面向用户的验收流程抓 native acceptance screenshot
9. 当任务需要用户可见视频时，用 native acceptance recording 包裹整段命令运行
10. 用 `TaskRunBundleWriter` 持久化 `CockpitContextBundle`，包括 `delivery.json`、复制后的录屏文件和提取出的 delivery keyframes
11. 当 API 驱动的 UI 需要稳定时，先清空已抓到的网络流量，再执行动作，然后用 `waitForNetworkIdle` 或 `waitForUiIdle` 加一个带 `networkQuery` 的 `investigate` snapshot 去看请求/响应证据
12. 当运行时行为可疑时，在得出“只是视觉问题或网络问题”的结论前，先抓一份带 runtime filters 的远程 snapshot
13. rebuild tracking 和 tap feedback 只在明确的 debug session 开启；正常 acceptance 路径保持干净和轻量

对迭代式功能开发，在最终 acceptance 路径之前插入这条轻量循环：

1. `launch-development-session`
2. 修改代码
3. `reload-development-session --mode hot_reload`
4. `collect-development-probe --profile quick --checkpoint after_reload`
5. `compare-development-probe --from-probe-json ... --to-probe-json ...`
6. 如果 delta 仍然不够清晰，再升级到 `interactive` 或 `diagnostic`
7. 页面行为正确后，再跑重一点的 `run-task` / `validate-task`

对 host 侧运行，`run-remote-control-script` 支持在 script JSON 里加可选的 `recording` block。只要存在这个 block，devtools 就会在命令执行前选择录屏路径：

- Android 且提供 `--android-device-id`：通过 `adb screenrecord` 做 host 侧录屏
- iOS 且提供 `--ios-device-id`：通过 `xcrun simctl io recordVideo` 做 host 侧录屏
- macOS 且使用 `--platform macos`：优先走 host 侧截图/录屏适配器；如果当前机器的 host 工具链无法产出稳定媒体，则自动回退到 remote screenshot 或基于截图时间线合成的交付视频
- Windows 且使用 `--platform windows`：优先走基于 PowerShell 激活与桌面截图/录屏工具链的 host 侧适配器
- Linux 且使用 `--platform linux`：优先走基于 `wmctrl`、X11 截图与 ffmpeg 录屏的 host 侧适配器
- 否则：回退到应用 session 内部录屏

无论最后选中哪种策略，视频都会被复制进本地 task-run bundle，同时从录屏时间线提取关键帧，并通过同一套 `delivery.json` 字段对外摘要。

同一个 `recording` block 也支持 `tailStabilizationMs`，让 runner 在 stop 前等待一小段时间，保留稳定的末帧，供 acceptance review 使用。默认值是 `1400`。

对 host 侧远程执行，如果 remote session health 已经暴露环境，则 control script 的 `environment` 现在是可选的。如果运行时没有发布环境元数据，`run-remote-control-script` 会显式失败，而不是编造 bundle 里的环境快照。

### Remote Session Bootstrap 示例

这条 bootstrap 工作流是为 AI 驱动的开发闭环设计的：host 先启动 app，然后复用这个 session handle 跑后续控制与验收。

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  launch-remote-session \
  --project-dir examples/cockpit_demo \
  --target cockpit/main.dart \
  --platform android \
  --android-device-id emulator-5554 \
  --session-port 48331 \
  --output-json /tmp/flutter_cockpit/session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  query-remote-session \
  --session-json /tmp/flutter_cockpit/session.json

dart run flutter_cockpit_devtools:flutter_cockpit_devtools \
  run-remote-control-script \
  --session-json /tmp/flutter_cockpit/session.json \
  --script path/to/script.json \
  --output-root path/to/out
```

输出的 session handle 会把这组启动元数据打包在一起：

- remote session `baseUrl`
- 选中的平台与设备 ID
- host 和 device 端口
- 发现到的 Android application ID 或 iOS bundle ID

这个 handle 有意和 task-run bundle 分离。它存在于任何 task-run 之前，目标就是让后续 host 侧命令共享一次 bootstrap 结果。

在这条推荐模式下：

- AI 开发/调试使用 `flutter run -t cockpit/main.dart`
- 正常生产构建继续使用你现有的生产 target，不要让 AI 假设固定路径

example 应用现在证明的是根级别接入，而不是到处套 `CockpitSurface` wrapper，同时也换成了生产风格 Todo workflow，而不是早期的窄表单 demo。核心 widget tests 覆盖 root runtime 行为、Todo CRUD 流程、settings 持久化、截图挂接和 remote bridge 行为。devtools tests 则覆盖 bundle writing、`delivery.json` 和 CLI 驱动的 control scripts。

example 还附带了生成后的 Android / iOS / macOS / Windows / Linux 宿主工程，以便真实编译 plugin bridge。
仓库也内置了 `skills/flutter-cockpit/` 这套 skill 资产，教 AI 如何使用这条已验证工作流，而不是把 skill 当成未来规划。

## 当前边界

当前实现是有意收敛过的：

- 已支持的执行路径：已接入 Flutter 应用内的 in-app control
- 已支持的外部控制路径：指向运行中应用的 remote HTTP bridge
- 已支持的 bootstrap 路径：Android emulator、iOS Simulator 与本地 macOS、Windows、Linux 桌面运行上的 host-side app launch，并输出可复用的 session-handle JSON
- 已支持的截图路径：Flutter-view capture 与应用内 native acceptance screenshot
- 已支持的录屏路径：应用内 native acceptance recording，加上 Android emulator / iOS Simulator / macOS / Windows / Linux 的 host-side remote fallback；当 host 录屏无法 finalize 时，bundle writer 会用截图时间线合成有界交付视频
- 还未实现：更广泛的 Android/iOS host automation、物理 iPhone host recording、远程设备编排、聊天通道交付

这些能力已经被收敛在 adapter interface 和现有 bundle contract 后面，因此后续扩展不需要推倒协议面重来。

## Setup

```bash
dart pub get
dart run melos bootstrap
dart run melos run test
```

## 质量门禁

提交前运行：

```bash
dart fix --apply
dart format .
dart analyze
dart run melos run test
```
