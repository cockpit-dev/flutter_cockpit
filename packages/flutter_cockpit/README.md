# flutter_cockpit

[![pub package](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)

[简体中文](README.zh-CN.md)

`flutter_cockpit` is the in-app runtime for AI-driven Flutter development.

It provides:

- runtime bootstrap through `FlutterCockpit.runApp`
- command execution for taps, text input, gestures, waits, assertions, screenshots, and snapshots
- remote session serving over HTTP
- snapshot, artifact, recording, and bundle models

## Install

```yaml
dependencies:
  flutter_cockpit: any
```

## Recommended Integration

Keep the normal production entrypoint unchanged and add `cockpit/main.dart`:

```dart
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import '../lib/app.dart';

Future<void> main() async {
  FlutterCockpit.runApp(
    const MyApp(),
    config: const FlutterCockpitConfig.production(
      initialRouteName: '/inbox',
    ),
  );
}
```

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

Host-side orchestration, MCP, workspace tooling, and delivery validation live in [`flutter_cockpit_devtools`](../flutter_cockpit_devtools/README.md).

Package page: [pub.dev/packages/flutter_cockpit](https://pub.dev/packages/flutter_cockpit)
