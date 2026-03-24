# flutter_cockpit

[English](README.md)

`flutter_cockpit` 是 `flutter_cockpit` 体系里的应用内运行时层，面向 AI 驱动的 Flutter 开发工作流。

它聚焦于 Flutter 应用内部的低侵入接入：

- 通过 `FlutterCockpitApp` 与 `FlutterCockpitConfig` 做根级 bootstrap
- 提供点击、输入、等待/断言、滚动和手势执行等运行时控制原语
- 提供面向键盘和语义层的控制能力，适用于快捷键、输入动作和 accessibility-first widget
- 提供截图与录屏请求
- 提供带有界诊断、accessibility-order summary、network activity 和 runtime event evidence 的 rich runtime snapshot
- 提供可被 host 侧工具通过 HTTP 驱动的 remote session server

## 安装

从 pub：

```yaml
dependencies:
  flutter_cockpit: any
```

或者直接从 Git：

```yaml
dependencies:
  flutter_cockpit:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit
```

## 基础接入

对于已有 Flutter 应用，推荐使用低心智负担的双入口模式：

- 生产入口继续保持在 `lib/main.dart`
- 额外新增一个 `cockpit/main.dart` 作为 cockpit 开发入口
- `cockpit/` 入口直接复用 `lib/` 里的应用根组件，不要求你重构应用结构

这样可以把 cockpit bootstrap 和正常生产入口分开，同时避免引入第二个 app shell。

在已接入的 Flutter 应用里，优先使用 Flutter 入口：

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

如果应用在挂 UI 之前还需要先初始化别的服务，可以先调 `FlutterCockpit.ensureInitialized(...)`。当你需要更细粒度地控制运行时组合方式时，仍然可以使用 `FlutterCockpitApp`、`FlutterCockpitRoot`。

典型的开发/生产命令可以这样分开：

```bash
flutter run -t cockpit/main.dart
flutter build apk --release -t lib/main.dart
```

除非显式设置 `ownsRuntime: true`，否则 `FlutterCockpitApp` 在卸载时不会 tear down 共享 runtime。这样 AI 的长会话在 root rebuild 或临时 host 组合变化下仍然稳定。

如果你要在纯 Dart 工具侧使用共享模型和协议面，请使用：

```dart
import 'package:flutter_cockpit/flutter_cockpit.dart';
```

## 当前包含内容

- 控制协议模型与 command results
- 应用内命令执行与手势支持
- 基于 Flutter 原生信号的 runtime target discovery
- snapshot、artifact、manifest 和 session 模型
- Android / iOS 的原生截图与录屏 bridge
- 远程 session 协议模型与 HTTP server

Host 侧的 CLI 与 MCP 工具面在配套包 `flutter_cockpit_devtools` 中。

完整工作流、示例应用和交付 bundle contract 请看仓库根目录 README。
