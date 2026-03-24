# flutter_cockpit

[简体中文](README.zh-CN.md)

`flutter_cockpit` is a production-oriented foundation for AI-driven Flutter development. The repository is building toward a full AI development loop: control the app, observe state, capture evidence, write a standard task bundle, and hand the result to later tooling or user-facing acceptance flows.

The current slice now proves three evidence paths:

- low-intrusion, root-level app integration for AI runtime access
- native acceptance screenshots generated inside the app, with Flutter-view fallback for environments where native capture is unavailable
- in-app native acceptance recording on Android and iOS, written into the standard task-run bundle for later delivery tooling
- a remote session bridge so host-side tools can inspect and control a running app over HTTP
- a remote recording workflow so host-side tools can start a recording, execute commands, stop the recording, and persist the resulting video inside the same task-run bundle
- host-side recording fallback for remote runs so Android emulators, iOS Simulators, and local macOS, Windows, and Linux runs can still produce acceptance videos when in-app recording is not the right path
- a bootstrap workflow so host-side tools can launch the app themselves, emit a reusable remote-session handle, and drive later commands without any manual pre-start step on Android, iOS Simulator, and local macOS, Windows, and Linux desktop runs

The repository still does not try to solve every platform capability yet, but the protocol and bundle format are now shaped for later host-side automation and remote orchestration.

## Workspace Layout

- `packages/flutter_cockpit`
  - Shared control, capture, session, runtime, and bundle domain models
  - Pure Dart entrypoint: `package:flutter_cockpit/flutter_cockpit.dart`
  - Flutter-only entrypoint: `package:flutter_cockpit/flutter_cockpit_flutter.dart`
- `packages/flutter_cockpit_devtools`
  - Host-side bundle writing, control runner, shared application services, CLI, and MCP server
- `examples/cockpit_demo`
  - Instrumented Flutter app proving the in-app control flow end to end
- `skills/flutter-cockpit`
  - AI-facing workflow skill, pressure scenarios, and examples for production-style `flutter_cockpit` usage
- `docs/`
  - Bundle contract, design specs, and implementation plans

For low-friction app adoption, keep the app's existing production entrypoint unchanged and place cockpit-specific bootstrap under `cockpit/main.dart`. The example app follows that pattern:

- `examples/cockpit_demo/cockpit/main.dart`
  - cockpit-enabled development entrypoint for AI control, hot reload, probing, and acceptance flows

## Installing The Repo Skill

The repository ships an AI workflow skill at `skills/flutter-cockpit/`. That directory is source-controlled reference material; it does not become active in your host automatically just because the repo is cloned.

To use the skill in an AI host, install or link that directory into the current host's skill-discovery directory, or configure the host to load it directly by path.

The exact installation path is host-specific, so the authoritative instructions live in:

- [`skills/flutter-cockpit/INSTALL.md`](skills/flutter-cockpit/INSTALL.md)

That install guide is intentionally host-first: the current agent should identify its own host, determine which local skill directory that host scans, then install `skills/flutter-cockpit/` there. Codex and Claude Code are included only as common examples.

Copyable prompt:

```text
Install the flutter-cockpit skill for the current AI host by following https://github.com/cockpit-dev/flutter_cockpit/blob/main/skills/flutter-cockpit/INSTALL.md
```

The important boundary is:

- the repo owns the skill source under `skills/flutter-cockpit/`
- your AI host owns discovery and activation
- cloning the repo alone does not install the skill

## Current Capability Slice

This repository currently validates:

- `melos` workspace bootstrapping with pub workspaces
- shared control protocol models with JSON round-tripping
- structured locator resolution and command results
- in-app execution for `tap`, `enterText`, `longPress`, `doubleTap`, `drag`, `fling`, `swipe`, `pinchZoom`, `rotate`, `panZoom`, `multiTouch`, `scrollUntilVisible`, `waitForNetworkIdle`, `waitForUiIdle`, `assertVisible`, `assertText`, `waitFor`, `captureScreenshot`, and `collectSnapshot`
- strict hit-test miss policies (`ignore`, `warn`, `fail`) so AI flows can choose between permissive exploration and fail-closed validation
- richer text-input requests covering focus, selection, and `inputAction` without fragmenting the command surface
- explicit keyboard-event commands for shortcut bars, submit keys, and search flows: `sendKeyEvent`, `sendKeyDownEvent`, `sendKeyUpEvent`
- semantics-backed control actions for accessibility-first widgets: `showOnScreen`, `increase`, `decrease`, and `dismiss`
- gesture sampling profiles (`fast`, `userLike`, `precise`) plus optional `sampleHz`, `frameIntervalMs`, and `initialHoldMs` overrides
- low-intrusion runtime bootstrap through `FlutterCockpit.runApp`, `FlutterCockpit.ensureInitialized`, `FlutterCockpitApp`, `FlutterCockpitConfig`, and `FlutterCockpit.navigatorObserver`, with `FlutterCockpitRoot` reserved for advanced runtime embedding
- shared-runtime ownership defaults so `FlutterCockpitApp` / `FlutterCockpitHost` no longer tear down the binding on unmount unless `ownsRuntime: true` is explicitly requested
- session recording with command metadata, capture routing metadata, failure summaries, and screenshot refs
- task-run bundle writing to the standard directory layout
- delivery-oriented bundle output through `delivery.json`
- host-side `run-control-script` CLI execution
- host-side `query-remote-session` and `run-remote-control-script` CLI execution
- host-side `collect-remote-snapshot` CLI execution for targeted diagnostics and network evidence without writing a full task bundle
- host-side `launch-remote-session` CLI execution that builds, installs, launches, and waits for a reachable remote session on Android, iOS Simulator, and macOS
- shared application services so CLI and MCP reuse the same launch, query, run, and bundle-summary workflows
- a `stdio` MCP server that exposes both the fast development loop (`launch_development_session`, `reload_development_session`, `collect_development_probe`, `compare_development_probe`) and the heavier evidence/validation loop (`launch_remote_session`, `query_remote_session`, `collect_remote_snapshot`, `run_remote_control_script`, `read_task_bundle_summary`, `run_task`, `validate_task`)
- a high-level run-task orchestration workflow that codifies `bootstrap -> baseline -> execute -> observe -> judge -> deliver`
- profile-driven runtime snapshots so AI can stay on `live` health payloads, escalate to `baseline` or `investigate` when needed, externalize heavy `forensic` diagnostics into bundle artifacts or remote artifact downloads, and inspect bounded request/response summaries for network debugging
- bounded accessibility-order snapshot summaries for `investigate` and `forensic` flows where AI needs to reason about reachable semantics traversal instead of only visible targets
- interaction pacing defaults so AI-driven taps, typing, gestures, and scroll steps wait for targets, apply bounded pre-action delays, and automatically slow down while recordings are active
- a production-style Todo example that is driven primarily through Flutter-native discovery signals such as keys, semantics, visible text, routes, and rich diagnostics
- a running app session that can be queried and driven remotely through `flutter_cockpit_devtools`
- remote command execution that streams screenshot payloads back to host-side tooling so task-run bundles contain real remote evidence files
- remote snapshot externalization that streams large forensic diagnostics back through `/artifacts/download` so AI can retrieve full widget and network context without bloating inline session payloads
- remote recording stop responses that transfer recording artifacts back to host-side tooling so remote task-run bundles contain real video files instead of device-local placeholder paths
- host-side recording adapters that use `adb screenrecord` and `xcrun simctl io recordVideo` when a remote run already has a direct device handle
- Flutter-view screenshot capture that attaches evidence to the bundle model
- native acceptance screenshot capture through the `flutter_cockpit` plugin bridge for Android, iOS, and macOS
- native acceptance recording through the `flutter_cockpit` plugin bridge for Android and iOS
- recording-aware bundle delivery metadata, including `recordings/`, `primaryRecordingRef`, and `videoAttachmentRefs`
- delivery keyframe extraction so recordings also produce bounded `keyframes/` evidence and coverage metadata for acceptance review
- Android, iOS, and macOS example host shells for real plugin build verification
- a repository-shipped `flutter_cockpit` skill asset with pressure scenarios, examples, and a maintainer-facing contract

## Package Entry Points

Use the shared entrypoint when you need protocol and bundle models from pure Dart tooling:

```dart
import 'package:flutter_cockpit/flutter_cockpit.dart';
```

Use the Flutter entrypoint when you need `FlutterCockpitApp`, `FlutterCockpitRoot`, `CockpitSurface`, `CockpitTargetNode`, `CockpitNativeCapture`, `FlutterViewCapture`, or `InAppCockpitCommandExecutor` inside an instrumented app or widget test:

```dart
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
```

This split is intentional. `flutter_cockpit_devtools` stays pure Dart, while Flutter-specific capture and UI instrumentation remain in the Flutter-only surface. In low-intrusion apps, `FlutterCockpitApp` plus native discovery are the default path; most apps should not need per-page wrappers or explicit session-controller plumbing. `FlutterCockpitRoot`, `CockpitSurface`, and `CockpitTargetNode` remain available only as advanced runtime primitives for ambiguous or high-value workflows.

## MCP Entry Points

`flutter_cockpit_devtools` now ships two MCP entry points backed by the same `CockpitMcpServer`:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_mcp
```

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools serve-mcp
```

Both entry points expose the same thirteen tools:

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

The MCP layer does not wrap shell commands. It calls the same shared application services used by the CLI, so launch/query/run/bundle behavior stays aligned across human and AI entrypoints.

For evidence-heavy workflows, `read_task_bundle_summary`, `run_task`, and `validate_task` now expose a stable AI-facing evidence view in addition to raw `delivery.json` fields. That view lifts the primary screenshot, primary recording, extracted keyframes, diagnostics artifact paths, and delivery readiness flags into one bounded object so later agents do not have to reverse-engineer bundle paths out of raw delivery metadata. The same MCP responses also expose first-class `network_summary` and `runtime_summary` payloads when those evidence streams are present.
For acceptance-facing runs, the same summary now also exposes three bounded AI-facing comparison layers:
- `baseline_evidence`: the before-state snapshot lifted from the bundle
- `acceptance_evidence`: the final-state dossier for route, text, semantics, accessibility, and compact runtime/network/rebuild signals
- `acceptance_delta`: the bounded before/after comparison view that highlights route changes plus added and removed text, semantics, accessibility labels, network failures, runtime errors, and rebuild hotspots

The intent is explicit: `validate-task` gates file integrity, delivery consistency, and the presence of an AI-facing acceptance comparison package for screenshot-backed completion flows. It still does not "understand the screen" for you; AI should read `baseline_evidence`, `acceptance_evidence`, and `acceptance_delta` to compare the delivered UI state directly.

## Development Session Workflow

For iterative AI development, prefer the development-session loop over full acceptance orchestration:

1. `launch_development_session`
2. edit code
3. `reload_development_session` with `hot_reload` or `hot_restart`
4. `collect_development_probe`
5. `compare_development_probe`
6. repeat until the page state is correct
7. only then escalate to `run_task` / `validate_task`

This keeps the fast loop lightweight:

- `quick`
  - route, bounded UI labels, network/runtime counts
- `interactive`
  - route plus visible text, semantic IDs, interactive labels, accessibility summary, screenshot-backed visual signals, and bounded network/runtime/rebuild summaries
- `diagnostic`
  - investigate-grade runtime context with screenshot evidence and richer visual summaries for layout/style regressions
- `forensic`
  - full rich diagnostics with artifact externalization when needed

The development session is long-lived and reload-aware. It bootstraps the app through the proven remote-session launcher, then attaches a long-lived Flutter tool over `flutter attach --machine` so AI can hot reload or hot restart without rebuilding and relaunching the entire app after every edit. The supervisor bootstrap path now scopes retries to the attempt it spawned instead of broad process-pattern cleanup, so one failed launch no longer tears down unrelated cockpit sessions on the same project or device.

Development probes are now intentionally AI-facing instead of log-shaped:

- interactive/diagnostic probes can persist a fresh screenshot and normalized `visualSignals`
- probe diffs compare both semantic text/labels and visual/layout/style fingerprints
- a pure visual regression can therefore show up in `compare_development_probe` even when visible text and semantic IDs stay unchanged

## High-Level Task Workflow

`flutter_cockpit_devtools` now also ships a high-level orchestration surface for the workflow encoded by the repository skill.

CLI:

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

MCP:

- `run_task`
- `validate_task`

The orchestration layer does not invent new app-side behavior. It composes the existing launch/query/run/bundle services into one explicit workflow:

1. bootstrap or reuse a session
2. keep preflight status
3. optionally inject a baseline screenshot command
4. execute the structured control script
5. read the persisted bundle summary
6. classify the outcome as `completed`, `failed_with_evidence`, `blocked_by_environment`, or `needs_more_work`

`validate-task` / `validate_task` builds on top of that orchestration path. It does not replace `run_task`; it adds a final delivery gate by validating persisted bundle outputs such as:

- `acceptance.md`
- `environment.json`
- primary screenshot and recording refs
- required artifact files on disk
- optional semantic acceptance evidence when the task declares it as required

When host-side tooling has `ffprobe` available, `validate-task` now uses it to validate screenshot and recording artifacts as real readable media instead of only checking file presence. If `ffprobe` is unavailable, devtools falls back to built-in PNG and MP4 structural checks so the delivery gate still fails closed on corrupt artifacts.
When a primary recording is present, the bundle writer now also extracts multiple PNG keyframes into `keyframes/` and records coverage metadata in `delivery.json`. `validate-task` treats missing or insufficient keyframe coverage as a delivery failure, so a readable video file alone is no longer enough for a production completion claim.
When `requireAcceptanceSemanticEvidence` is enabled, `validate-task` also requires acceptance-facing semantic signals to be present in the bundle summary. This does not mean the validator performs computer vision. It means the bundle must contain enough final-state route/text/semantics evidence, plus a bounded final-state dossier, for a later AI step to compare the delivered UI state directly.
Acceptance screenshots now also pass through a quiet-state gate before capture. The runtime waits for UI quiescence and, when network observation is available, also waits for bounded network idle before taking the final acceptance screenshot. For flows that need a strict gate instead of best-effort pre-capture waiting, use the explicit `waitForUiIdle` command in the control script before the final acceptance step.

Use `run_task` when the agent needs orchestration. Use `validate-task` when the agent is ready to make a final completion claim and must prove the bundle is delivery-ready.

For host-driven remote workflows, `run_task` can now omit the script `environment` when the session health already exposes a real `CockpitEnvironment`. That happens automatically for sessions launched through `launch-remote-session`, because devtools injects the active Flutter version into the app bootstrap path and the runtime publishes the resulting environment through remote health.

Manually started remote sessions may still need an explicit script `environment` if their health payload does not expose one. `flutter_cockpit` still refuses to fabricate environment values when the runtime metadata is incomplete.

## Snapshot Profiles

`flutter_cockpit` now treats runtime observation as a layered protocol instead of a single oversized snapshot payload.

- `live`
  - default for `/health`, polling, and wait/assert flows
  - keeps route and visible target metadata lightweight
- `baseline`
  - default for explicit `collectSnapshot` and baseline/acceptance screenshots
  - adds bounded layout and content summaries
- `investigate`
  - use when a locator is ambiguous, an assertion fails, UI state looks wrong, or AI needs filtered request/response or runtime evidence
  - adds bounded style details, ancestor summaries, normalized widget properties such as padding/alignment/typography/opacity/icon/image hints, diagnostic properties, network endpoint summaries, and recent runtime events
- `forensic`
  - use only when lighter profiles are not enough
  - keeps bundle timelines readable by externalizing the full snapshot into `diagnostics/*.json` and leaving a summarized inline snapshot with a `diagnosticsArtifactRef`

Rebuild diagnostics remain explicitly opt-in. `investigate` and `forensic` can request rebuild summaries, but the app only returns them when runtime bootstrap enabled rebuild tracking through `CockpitDiagnosticsConfig(enableRebuildTracking: true)`.

As an AI caller, do not default to `forensic`. Keep high-frequency flows cheap, then escalate deliberately.

For direct remote runtime diagnosis without running a full task bundle, `collect-remote-snapshot` now supports runtime filters as first-class CLI controls:

- `--include-runtime-activity`
- `--max-runtime-entries`
- `--runtime-only-errors` / `--no-runtime-only-errors`
- `--runtime-message-contains "..." `

That makes it possible to query live Flutter errors or logs through the same host tooling surface that already supports network inspection.

## Verified Workflow

The current end-to-end flow is:

1. Bootstrap `flutter_cockpit` once at the root, preferably with `FlutterCockpit.runApp(MyApp(), config: ...)` or `FlutterCockpitApp(config: ..., child: MyApp())`.
2. Expose a local remote session bridge for host-side AI tooling in debug/dev environments.
3. When host-side tooling needs to bootstrap the session itself, launch the app with `launch-remote-session` and persist the emitted session-handle JSON.
4. Reuse that handle through `query-remote-session --session-json ...` and `run-remote-control-script --session-json ...` instead of manually wiring base URLs and device IDs into later commands.
5. Let host-launched sessions provide `CockpitEnvironment` automatically through remote health, or provide explicit script environment only when the session metadata is incomplete.
6. Execute structured commands through `InAppCockpitCommandExecutor` or a host-side adapter.
   If locator-based control is not enough, gestures can fall back to explicit coordinates (`x`/`y`, `startX`/`startY`) instead of forcing app-specific wrappers.
   When a screen is still stabilizing, let the built-in interaction policy wait for the target to appear and apply pre-action pacing before firing the next visible mutation. Use per-command `preActionTimeoutMs`, `preActionPollIntervalMs`, or `preActionVisualDelayMs` only when a specific flow needs more slack than the runtime defaults.
7. Record each command result in `CockpitSessionController`, including any inline remote artifact payloads returned by the running app.
8. Capture Flutter-view screenshots for diagnostics or native acceptance screenshots for user-facing evidence.
9. Optionally wrap the command run in a native acceptance recording when the task needs user-facing video evidence.
10. Persist the resulting `CockpitContextBundle` with `TaskRunBundleWriter`, including `delivery.json`, copied recording artifacts, and extracted delivery keyframes.
11. When API-backed UI needs stabilization, clear captured traffic, run the action, then use `waitForNetworkIdle` or `waitForUiIdle` plus an `investigate` snapshot with `networkQuery` filters to inspect request and response evidence before judging the result.
12. When runtime behavior is suspicious, capture a targeted remote snapshot with runtime filters before concluding that the issue is only visual or network-related.
13. Enable rebuild tracking or tap feedback only in explicit debug sessions; keep the normal acceptance path clean and lightweight.

For iterative feature work, insert this lighter cycle before the final acceptance path:

1. `launch-development-session`
2. edit code
3. `reload-development-session --mode hot_reload`
4. `collect-development-probe --profile quick --checkpoint after_reload`
5. `compare-development-probe --from-probe-json ... --to-probe-json ...`
6. if the delta still looks wrong, escalate to `interactive` or `diagnostic`
7. once the page behavior is correct, run the heavier `run-task` / `validate-task` acceptance flow

For host-side runs, `run-remote-control-script` accepts an optional `recording` block in the script JSON. When present, devtools chooses the recording path before command execution:

- Android with `--android-device-id`: host recording through `adb screenrecord`
- iOS with `--ios-device-id`: host recording through `xcrun simctl io recordVideo`
- macOS with `--platform macos`: host-preferred screenshot/recording adapters, with remote screenshot or synthesized timeline-video fallback when host tooling cannot produce stable media on the current machine
- Windows with `--platform windows`: host-preferred screenshot/recording adapters built around PowerShell activation plus desktop capture/recording tooling
- Linux with `--platform linux`: host-preferred screenshot/recording adapters built around `wmctrl`, X11 desktop capture, and ffmpeg-based recording
- otherwise: remote in-app recording through the app session

Regardless of which strategy is chosen, the resulting video is copied into the local task-run bundle, keyframes are extracted from the recorded timeline, and the final evidence set is summarized through the same `delivery.json` fields.
The same `recording` block can also set `tailStabilizationMs` so the runner waits briefly before stopping the recording and preserves a settled end-state frame for acceptance review. The default is `1400`.

For host-side remote execution, the control script `environment` is now optional when the remote session health exposes one. If the runtime does not publish environment metadata, `run-remote-control-script` fails explicitly instead of inventing a bundle environment snapshot.

### Remote Session Bootstrap Example

The bootstrap workflow is designed for AI-controlled development loops where the host needs to start the app and then reuse the launched session across later commands.

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

The emitted session handle keeps the launched session metadata together:

- remote session `baseUrl`
- selected platform and device ID
- chosen host and device ports
- discovered Android application ID or iOS bundle ID

That handle is intentionally separate from the task-run bundle. It exists before any task-run output is created and lets later host-side commands share one bootstrap step.

For this recommended single-package pattern:

- use `flutter run -t cockpit/main.dart` for AI-driven development
- keep your normal production build target unchanged instead of teaching AI to assume a fixed path

The example app now proves root-level integration without per-page `CockpitSurface` wrappers and uses a production-style Todo workflow instead of a narrow form demo. Core widget tests cover root runtime behavior, Todo CRUD flows, settings persistence, screenshot attachment, and remote bridge behavior. Devtools tests cover bundle writing, `delivery.json`, and CLI-driven control scripts.
The example app now also contains generated Android, iOS, macOS, Windows, and Linux host projects so native plugin bridges can be compiled in a real app shell.
The repository now also ships a `skills/flutter-cockpit/` asset that teaches AI how to use the validated workflow instead of treating the skill as a future integration detail.

## Current Limits

The current implementation is intentionally narrow:

- supported execution path: in-app control through an instrumented Flutter app
- supported external control path: remote HTTP bridge to a running instrumented app
- supported bootstrap path: host-side app launch for Android emulators, iOS Simulators, and local macOS, Windows, and Linux desktop runs, with reusable session-handle JSON output
- supported screenshot paths: Flutter-view capture and in-app native acceptance screenshots
- supported recording paths: in-app native acceptance recording plus host-side remote fallback for Android emulators, iOS Simulators, and macOS, Windows, and Linux desktop runs; when host recording cannot finalize, bundle writing can synthesize a bounded timeline video from captured screenshots so the delivery gate still fails closed on missing evidence
- not implemented yet: Android/iOS host automation beyond launch and recording, physical iPhone host recording, remote device orchestration, chat-channel delivery

Those capabilities are reserved behind adapter interfaces and the existing bundle contract so later phases can extend the system without replacing the protocol surface.

## Setup

```bash
dart pub get
dart run melos bootstrap
dart run melos run test
```

## Quality Gate

Before submitting changes, run:

```bash
dart fix --apply
dart format .
dart analyze
dart run melos run test
```
