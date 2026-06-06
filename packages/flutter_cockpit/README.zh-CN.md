# flutter_cockpit

[![pub package](https://img.shields.io/pub/v/flutter_cockpit?logo=dart&label=pub.dev)](https://pub.dev/packages/flutter_cockpit)
[![pub points](https://img.shields.io/pub/points/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![likes](https://img.shields.io/pub/likes/flutter_cockpit?logo=dart)](https://pub.dev/packages/flutter_cockpit/score)
[![Runtime Loop](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml/badge.svg)](https://github.com/cockpit-dev/flutter_cockpit/actions/workflows/runtime-loop.yml)
[![License](https://img.shields.io/github/license/cockpit-dev/flutter_cockpit)](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/LICENSE)

[English](https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/README.md)

`flutter_cockpit` 是面向 AI 驱动 Flutter 开发的应用内运行时。

它提供：

- 通过 `FlutterCockpit.runApp` 或 `FlutterCockpitApp` 做运行时 bootstrap
- 点击、输入、手势、等待、断言、截图、快照等命令执行能力
- 基于 HTTP 的远程会话服务
- snapshot、artifact、recording 和 bundle 模型
- 面向 AI 摘要的 target / plane / surface / fallback 运行时模型

## 安装

需要 Flutter 3.32.0 或更高版本。

```yaml
dependencies:
  flutter_cockpit: ^1.0.0
```

如果只有 `cockpit/main.dart` import runtime，优先把 `flutter_cockpit`
放到 `dev_dependencies`。只有宿主明确选择共享入口，或需要把 runtime
作为正式发布集成的一部分时，才放到生产 `dependencies`。

## 推荐接入方式

保留正常生产入口不动，新增 `cockpit/main.dart`。不要把 `flutter_cockpit` import 加到生产 `lib/` 代码里。

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

把 `package:your_app/app_shell.dart` 换成你现有应用根组件或 bootstrap 的真实 import。`launch-app` 会注入 `FLUTTER_COCKPIT_REMOTE_*` 这组 dart-define，所以 `resolveFromEnvironment(...)` 可以在不接管生产入口的前提下启用远程控制面。
只有 cockpit 入口自己创建 navigator，或者宿主明确接受共享入口时，才把 `FlutterCockpit.navigatorObserver` 接进去。如果生产应用已经自己持有 `MaterialApp`、`GoRouter` 或其他 router，就在 `cockpit/main.dart` 里用 `FlutterCockpitApp` 包住现有根组件，并把 route 同步留在 cockpit 层，例如监听 app router 后调用 `FlutterCockpit.setCurrentRouteName(...)`。

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
在 web 上，runtime 直接支持 Flutter semantic 和 Flutter-view 控制路径；原生 method channel 会注册为“显式不可用”的 stub，这样能力判断会保持真实，不会退化成缺少插件的噪音报错。应用内截图请走 Flutter-view，浏览器录屏请走 `flutter_cockpit_devtools` 提供的宿主侧链路。

包地址：[pub.dev/packages/flutter_cockpit](https://pub.dev/packages/flutter_cockpit)
