# flutter_cockpit

[English](README.md)

`flutter_cockpit` 是面向 AI 驱动 Flutter 开发的应用内运行时。

它提供：

- 通过 `FlutterCockpit.runApp` 做运行时 bootstrap
- 点击、输入、手势、等待、断言、截图、快照等命令执行能力
- 基于 HTTP 的远程会话服务
- snapshot、artifact、recording 和 bundle 模型

## 安装

```yaml
dependencies:
  flutter_cockpit: any
```

## 推荐接入方式

保留正常生产入口不动，新增 `cockpit/main.dart`：

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

宿主侧编排、MCP、workspace tooling 和交付验证在 [`flutter_cockpit_devtools`](../flutter_cockpit_devtools/README.md) 中。
