# flutter_cockpit

[![pub package](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)

[English](README.md)

`flutter_cockpit` 是面向 AI 驱动 Flutter 开发的应用内运行时。

它提供：

- 通过 `FlutterCockpit.runApp` 或 `FlutterCockpitApp` 做运行时 bootstrap
- 点击、输入、手势、等待、断言、截图、快照等命令执行能力
- 基于 HTTP 的远程会话服务
- snapshot、artifact、recording 和 bundle 模型
- 面向 AI 摘要的 target / plane / surface / fallback 运行时模型

## 安装

```yaml
dependencies:
  flutter_cockpit: any
```

## 推荐接入方式

保留正常生产入口不动，新增 `cockpit/main.dart`：

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

把 `package:your_app/app_shell.dart` 换成你现有应用根组件或 bootstrap 的真实 import。`launch-app` 会注入 `FLUTTER_PILOT_REMOTE_*` 这组 dart-define，所以 `resolveFromEnvironment(...)` 可以在不接管生产入口的前提下启用远程控制面。
如果应用内部已经自己持有 `MaterialApp`，就用 `FlutterCockpitApp` 包住那层 app shell，并把 `FlutterCockpit.navigatorObserver` 接到原有 navigator 上，不要再嵌一层新的 `MaterialApp`。

运行：

```bash
flutter run -t cockpit/main.dart
```

## 运行时暴露的能力

- 低侵入根级 bootstrap
- 命令路由与执行
- 带有界诊断的 UI 快照
- accessibility、network、runtime、rebuild 信号
- 截图和录屏请求
- 远程会话状态与命令端点

宿主侧编排、MCP、workspace tooling 和交付验证在 [`flutter_cockpit_devtools`](https://pub.dev/packages/flutter_cockpit_devtools) 中。
运行时 bundle 模型现在会保留 `targetKind`、`primaryExecutionPlane`、`planesUsed`、`surfaceKindsUsed`、`fallbackCount`，以及 step / observation 级别的 plane 元数据，方便宿主侧准确解释这次控制是按预期平面完成，还是发生了受控降级。

包地址：[pub.dev/packages/flutter_cockpit](https://pub.dev/packages/flutter_cockpit)
