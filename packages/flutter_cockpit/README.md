# flutter_cockpit

[![pub package](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)

[简体中文](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/README.zh-CN.md)

`flutter_cockpit` is the in-app runtime for AI-driven Flutter development.

It provides:

- runtime bootstrap through `FlutterCockpit.runApp` or `FlutterCockpitApp`
- command execution for taps, text input, gestures, waits, assertions, screenshots, and snapshots
- remote session serving over HTTP
- snapshot, artifact, recording, and bundle models
- target, plane, surface, and fallback-aware runtime models for AI-first summaries

## Install

Requires Flutter 3.32.0 or newer.

```yaml
dependencies:
  flutter_cockpit: ^1.1.0
```

If only `cockpit/main.dart` imports the runtime, prefer putting
`flutter_cockpit` under `dev_dependencies`. Use production `dependencies` only
for an explicit shared-entrypoint or shipped-runtime integration.

The runtime package declares native plugin entries for Android, iOS, macOS,
Linux, Windows, and web. That lets app-window screenshots and recording
fallbacks register consistently whenever the cockpit entrypoint is compiled.
Keep the integration low-intrusion by importing it from `cockpit/main.dart`
instead of production `lib/` code unless the host app explicitly ships a shared
runtime entrypoint. Flutter-view screenshots, semantic control, network signals,
runtime diagnostics, and remote sessions work in-app. System dialogs,
notifications, host screenshots, and host recordings should still be driven by
`cockpit` system actions so capability discovery and platform fallbacks remain
truthful.

## Recommended Integration

Keep the normal production entrypoint unchanged and add `cockpit/main.dart`. Do not add `flutter_cockpit` imports to production `lib/` code.

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

Replace `package:your_app/app_shell.dart` with the import that already exposes your app root widget or bootstrap. `launch-app` injects the `FLUTTER_COCKPIT_REMOTE_*` dart-defines, so `resolveFromEnvironment(...)` enables the remote surface without taking over the production bootstrap.
Only wire `FlutterCockpit.navigatorObserver` inside a navigator created by the cockpit entrypoint, or in a shared entrypoint the host explicitly accepts. If your production app already owns `MaterialApp`, `GoRouter`, or another router, wrap the existing root with `FlutterCockpitApp` from `cockpit/main.dart` and keep route synchronization in that cockpit layer, for example by listening to the app router and calling `FlutterCockpit.setCurrentRouteName(...)`.

Run it with:

```bash
flutter run -t cockpit/main.dart
```

## What The Runtime Exposes

- low-intrusion root bootstrap
- command routing and execution
- UI snapshots with bounded diagnostics
- accessibility, network, runtime, and rebuild signals
- screenshot and recording requests
- remote session status and command endpoints

Host-side orchestration, MCP, workspace tooling, and delivery validation live in [`cockpit`](https://pub.dev/packages/cockpit).
The runtime bundle models now preserve `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, plus per-step and per-observation plane metadata so host-side tooling can explain when Flutter control stayed on-plan versus when it had to degrade to another surface.
On web, the runtime supports the Flutter semantic and Flutter-view control path directly, while the method channels are registered as explicit unavailable stubs so capability checks stay truthful instead of failing through missing-plugin noise. On mobile and desktop, native method-channel recording and capture register through the package plugin entries and are used as app-window evidence fallbacks; prefer system or host evidence through `cockpit` when the goal is to prove system dialogs, notifications, host windows, or cross-app behavior.

Package page: [pub.dev/packages/flutter_cockpit](https://pub.dev/packages/flutter_cockpit)
