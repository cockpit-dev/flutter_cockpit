# flutter_cockpit

[简体中文](README.zh-CN.md)

`flutter_cockpit` provides the in-app runtime layer for AI-driven Flutter development workflows.

It focuses on low-intrusion integration inside a Flutter app:

- root-level bootstrap through `FlutterCockpitApp` and `FlutterCockpitConfig`
- runtime control primitives such as tap, text input, wait/assert, scrolling, and gesture execution
- keyboard and semantics-aware control primitives for shortcuts, input actions, and accessibility-backed widgets
- screenshot and recording requests
- rich runtime snapshots with bounded diagnostics, accessibility-order summaries, network activity, and runtime event evidence
- a remote session server that host-side tooling can drive over HTTP

## Installation

From pub:

```yaml
dependencies:
  flutter_cockpit: any
```

Or directly from Git:

```yaml
dependencies:
  flutter_cockpit:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit
```

## Basic integration

For existing apps, the recommended low-friction pattern is:

- keep the existing production entrypoint unchanged
- add a dedicated cockpit bootstrap entrypoint under `cockpit/main.dart`
- import the existing app root from `lib/` instead of restructuring the app

That keeps cockpit-specific bootstrap separate from the normal production entrypoint without forcing a second app shell.

Use the Flutter entrypoint inside an instrumented app:

```dart
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

Future<void> main() async {
  FlutterCockpit.runApp(
    const MyApp(),
    config: const FlutterCockpitConfig.production(
      initialRouteName: '/inbox',
    ),
  );
}
```

If an app needs to bootstrap other services before mounting UI, call `FlutterCockpit.ensureInitialized(...)` first. `FlutterCockpitApp` and `FlutterCockpitRoot` remain available as advanced embedding primitives when tighter manual control over runtime composition is required.

A typical split then becomes:

```bash
flutter run -t cockpit/main.dart
```

For production builds, keep using the app's normal production target instead of hardcoding one path into the cockpit guidance.

`FlutterCockpitApp` no longer tears down the shared runtime when it unmounts unless `ownsRuntime: true` is set explicitly. This keeps long AI sessions stable across root rebuilds and temporary host composition changes.

For pure Dart tooling and shared models, use:

```dart
import 'package:flutter_cockpit/flutter_cockpit.dart';
```

## Interaction pacing

`flutter_cockpit` now applies a bounded interaction policy before and after visual mutations so AI-driven runs stay stable and recordings remain readable:

- wait for locator-based targets to appear within `targetResolveTimeout`
- poll discovery using `targetResolvePollInterval`
- add a short pre-action visual delay before taps, text entry, gestures, back navigation, and scroll steps
- use a longer pacing window automatically while recording is active
- add post-action visual continuity delays after route transitions and other visible mutations

Tune these defaults through `FlutterCockpitConfig.interactionPolicy`:

```dart
FlutterCockpit.runApp(
  const MyApp(),
  config: const FlutterCockpitConfig.production(
    initialRouteName: '/inbox',
    interactionPolicy: CockpitInteractionPolicy(
      targetResolveTimeout: Duration(milliseconds: 1800),
      preActionVisualDelay: Duration(milliseconds: 56),
      recordingPreActionVisualDelay: Duration(milliseconds: 140),
    ),
  ),
);
```

Debug-only diagnostics stay opt-in through `CockpitDiagnosticsConfig`:

```dart
const enableDebugDiagnostics = bool.fromEnvironment(
  'FLUTTER_COCKPIT_ENABLE_DEBUG_DIAGNOSTICS',
);
const enableTapFeedback = bool.fromEnvironment(
  'FLUTTER_COCKPIT_ENABLE_TAP_FEEDBACK',
);

FlutterCockpit.runApp(
  const MyApp(),
  config: FlutterCockpitConfig.production(
    initialRouteName: '/inbox',
    diagnostics: const CockpitDiagnosticsConfig(
      enableRebuildTracking: enableDebugDiagnostics,
      enableTapFeedback: enableTapFeedback,
    ),
  ),
);
```

When rebuild tracking is disabled, `live` and `baseline` snapshots stay lean; `investigate` and `forensic` only include rebuild summaries when the runtime explicitly opted in.

Individual commands can also override the runtime defaults when a specific flow needs more time:

- `preActionTimeoutMs`
- `preActionPollIntervalMs`
- `preActionVisualDelayMs`

When a workflow records user-facing video evidence, the recording request can also reserve a short tail window before the recorder stops so the final accepted screen is visible in the output instead of being cut on the transition:

- `tailStabilizationMs`

That value defaults to `1400` and applies to both in-app and host-driven recording flows.

## Hit testing, text input, and gesture profiles

Gesture commands support explicit miss handling when a discovered target does not actually win pointer hit testing:

- `ignore`
- `warn`
- `fail`

The runtime default is `warn`, which keeps AI control flows moving while still surfacing degraded interactions in command snapshots. High-value validation flows can opt into stricter behavior per command with `hitTestMissPolicy`.

`enterText` now supports the full text-input chain without introducing extra command types. In addition to `text`, callers can provide:

- `selectionBase`
- `selectionExtent`
- `inputAction`
- `requestFocus`
- `clearExisting`

This makes search fields, multi-step forms, and focus transitions behave more like real Flutter text-input flows.

Keyboard-driven flows now also have explicit command support:

- `sendKeyEvent`
- `sendKeyDownEvent`
- `sendKeyUpEvent`

These are intended for shortcut bars, submit keys, search fields, and desktop-style interactions where text input alone is not enough.

When the agent needs a stricter completion gate before a final comparison or acceptance screenshot, it can now issue `waitForUiIdle`. That command waits for a bounded quiet window in the Flutter scheduler and, when network observation is available, also waits for bounded network idle. Acceptance screenshots use the same quiet-state gate automatically as a best-effort pre-capture step.

Semantics-backed widgets can now expose and execute richer accessibility actions:

- `showOnScreen`
- `increase`
- `decrease`
- `dismiss`

This lets AI control sliders, steppers, dismissible elements, and other widgets whose most stable action surface is the semantics layer rather than a plain tap target.

Gesture commands also support sampling profiles so AI can balance speed against visual readability:

- `gestureProfile: fast | userLike | precise`
- `sampleHz`
- `frameIntervalMs`
- `initialHoldMs`

Use the profile defaults for most flows and only override explicit sampling when a specific interaction or acceptance recording needs tighter control.

## Accessibility-aware snapshots

`investigate` and `forensic` snapshot profiles can now attach a bounded accessibility traversal summary. This is not a full semantics dump. It is a compact, ordered view of the reachable semantics targets that matter to the currently visible cockpit targets.

Use it when AI needs to answer questions like:

- what will screen-reader traversal hit first
- whether a visible control is reachable through merged semantics
- whether multiple visually similar controls differ at the accessibility layer

`live` and `baseline` stay lean by default and do not include the accessibility summary unless explicitly requested.

## What this package contains

- control protocol models and command results
- in-app command execution and gesture support
- runtime target discovery through Flutter-native signals
- snapshot, artifact, manifest, and session models
- native screenshot and recording bridges for Android and iOS
- remote session protocol models and HTTP server

Host-side CLI and MCP tooling live in the companion package `flutter_cockpit_devtools`.

See the repository root README for the full workflow, example app, and delivery bundle contract.
