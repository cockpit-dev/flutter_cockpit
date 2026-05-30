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
  flutter_cockpit: ^1.0.0
```

## Recommended Integration

Keep the normal production entrypoint unchanged and add `cockpit/main.dart`:

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
If your app already owns `MaterialApp`, wrap that shell with `FlutterCockpitApp` and add `FlutterCockpit.navigatorObserver` there instead of nesting a second `MaterialApp`.

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

Host-side orchestration, MCP, workspace tooling, and delivery validation live in [`flutter_cockpit_devtools`](https://pub.dev/packages/flutter_cockpit_devtools).
The runtime bundle models now preserve `targetKind`, `primaryExecutionPlane`, `planesUsed`, `surfaceKindsUsed`, `fallbackCount`, plus per-step and per-observation plane metadata so host-side tooling can explain when Flutter control stayed on-plan versus when it had to degrade to another surface.
On web, the runtime supports the Flutter semantic and Flutter-view control path directly, while the native method channels are registered as explicit unavailable stubs so capability checks stay truthful instead of failing through missing-plugin noise. Use Flutter-view screenshots in-app and host-side browser recording through `flutter_cockpit_devtools`.

Package page: [pub.dev/packages/flutter_cockpit](https://pub.dev/packages/flutter_cockpit)
