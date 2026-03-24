# Flutter App Setup Example

Use this pattern when the task is not just "run the app" but "make this Flutter app controllable by `flutter_cockpit` in the first place."

## Example Flow

1. Add the `flutter_cockpit` dependency to the app package.
2. Run `flutter pub get`.
3. Bootstrap cockpit once at the app root.
4. Add `FlutterCockpit.navigatorObserver` to the app navigator.
5. Enable remote session configuration in debug/dev environments.
6. Keep rebuild tracking and tap feedback explicitly debug-only.

## Dependency

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

Then install dependencies:

```bash
flutter pub get
```

## Minimal Root Bootstrap

For simple apps, prefer the lowest-friction root bootstrap:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

Future<void> main() async {
  FlutterCockpit.runApp(
    MaterialApp(
      navigatorObservers: <NavigatorObserver>[
        FlutterCockpit.navigatorObserver,
      ],
      home: const MyHomePage(),
    ),
    config: FlutterCockpitConfig.production(
      initialRouteName: '/',
      remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
        fallback: const CockpitRemoteSessionConfiguration(
          enabled: true,
          host: '127.0.0.1',
          port: 47331,
        ),
      ),
    ),
  );
}
```

## App-Wrapped Bootstrap

For real apps that already own service initialization, state, or theme composition, prefer wrapping the app tree with `FlutterCockpitApp`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

final class MyAppShell extends StatelessWidget {
  const MyAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitApp(
      config: FlutterCockpitConfig.production(
        initialRouteName: '/inbox',
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
        initialRoute: '/inbox',
        onGenerateRoute: _buildRoute,
      ),
    );
  }
}
```

## Debug-Only Diagnostics

Rebuild tracking and tap feedback should stay explicit and debug-only:

```dart
const enableDebugDiagnostics = bool.fromEnvironment(
  'FLUTTER_COCKPIT_ENABLE_DEBUG_DIAGNOSTICS',
);
const enableTapFeedback = bool.fromEnvironment(
  'FLUTTER_COCKPIT_ENABLE_TAP_FEEDBACK',
);

final config = FlutterCockpitConfig.production(
  diagnostics: const CockpitDiagnosticsConfig(
    enableRebuildTracking: enableDebugDiagnostics,
    enableTapFeedback: enableTapFeedback,
  ),
);
```

## Expected Agent Behavior

- do not add `flutter_cockpit` to a pure Dart tool package that never mounts Flutter UI
- prefer `FlutterCockpit.runApp(...)` for simple roots and `FlutterCockpitApp(...)` for existing app shells
- wire `FlutterCockpit.navigatorObserver` into the navigator instead of inventing a parallel route tracker
- keep remote-session enablement and debug diagnostics explicit
- treat direct `FlutterCockpitRoot` composition as an advanced escape hatch, not the default recommendation
