# Flutter App Setup Example

Use this pattern when the task is not just "run the app" but "make this Flutter app controllable by `flutter_cockpit` in the first place."

## Example Flow

1. Create a standalone `cockpit/` Flutter development project and add
   `flutter_cockpit` and `cockpit` to that shell's `dev_dependencies`.
2. Run `flutter pub get`.
3. Keep the app's existing production entrypoint unchanged.
4. Add the shell entrypoint at `cockpit/main.dart` and launch it with
   `--project-dir cockpit --target main.dart`.
5. Keep all Cockpit imports and wiring under `cockpit/`. Do not add `flutter_cockpit` imports to production `lib/` code.
6. Let `FlutterCockpitApp` discover public Router providers automatically. Add `FlutterCockpit.navigatorObserver` only to navigators created or configurable from `cockpit/`.
7. Enable remote session configuration in debug/dev environments.
8. Keep rebuild tracking and tap feedback explicitly debug-only.

## Dependency

From pub for the non-intrusive `cockpit/` entrypoint pattern:

```yaml
dev_dependencies:
  flutter_cockpit: ^1.1.4
  cockpit: ^1.1.4
```

Or directly from Git:

```yaml
dev_dependencies:
  flutter_cockpit:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit
  cockpit:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/cockpit
```

Then install dependencies:

```bash
flutter pub get
```

## Recommended Directory Pattern

Keep the user's normal app structure intact:

```text
cockpit/
  main.dart
  cockpit_bootstrap.dart
```

- the existing production entrypoint stays production-owned, wherever the app already keeps it
- the standalone `cockpit/` project becomes the AI development entrypoint
- `cockpit/cockpit_bootstrap.dart` stays thin and only owns cockpit wiring
- Do not add `flutter_cockpit` imports to production `lib/` code
- do not mirror or rewrite the user's internal `lib/` layout just to add cockpit

## Cockpit Development Entrypoint

`cockpit/main.dart` in the standalone shell

```dart
import 'package:flutter/widgets.dart';

import 'cockpit_bootstrap.dart';

void main() {
  runApp(buildCockpitDevelopmentApp());
}
```

`cockpit/cockpit_bootstrap.dart`

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'package:your_app/app_shell.dart';

Widget buildCockpitDevelopmentApp() {
  const enableDebugDiagnostics = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_DEBUG_DIAGNOSTICS',
  );
  const enableTapFeedback = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_TAP_FEEDBACK',
  );

  return FlutterCockpitApp(
    config: FlutterCockpitConfig.production(
      remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
        fallback: const CockpitRemoteSessionConfiguration(
          enabled: true,
          host: '127.0.0.1',
          port: 47331,
        ),
      ),
      diagnostics: CockpitDiagnosticsConfig(
        enableRebuildTracking: enableDebugDiagnostics,
        enableTapFeedback: enableTapFeedback,
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

Replace `package:your_app/app_shell.dart` with whatever import already exposes the app's existing root widget or bootstrap. Do not invent a new `lib/` structure just for cockpit.
The `navigatorObservers` snippet is only for the root navigator wired from this cockpit bootstrap. Give every plain nested Navigator its own `FlutterCockpit.createNavigatorObserver()`. `FlutterCockpitApp` automatically discovers public `RouteInformationProvider` instances used by Flutter Router, `RouterConfig`, `go_router`, and other Router-based libraries. For a dynamically created router that cannot be discovered from the mounted tree, bind its provider from `cockpit/` with `FlutterCockpit.bindRouteInformationProvider(...)`. Use a `setCurrentRouteName(...)` bridge only when the router exposes neither a provider nor observers.
Use `CockpitRemoteSessionConfiguration.resolveFromEnvironment(...)` or an equivalent app-owned bridge so `launch-app` can enable the remote surface through `FLUTTER_COCKPIT_REMOTE_*` dart-defines without rewriting production bootstrap.

## App-Wrapped Bootstrap

For real apps that already own service initialization, state, or theme composition, keep this wrapper in `cockpit/` and import the existing app root:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

final class MyAppShell extends StatelessWidget {
  const MyAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitApp(
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
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FlutterCockpit.navigatorObserver,
        ],
        initialRoute: '/',
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
- use a dedicated standalone `cockpit/` development project with `main.dart`; keep the existing production path and release dependency graph untouched
- do not assume the user's production bootstrap lives at `lib/main.dart` or under any fixed `lib/` subpath
- prefer `FlutterCockpit.runApp(...)` for simple roots and `FlutterCockpitApp(...)` for existing app shells
- Do not add `flutter_cockpit` imports to production `lib/` code
- rely on automatic public Router provider discovery, wire `FlutterCockpit.navigatorObserver` only from `cockpit/`, use one `createNavigatorObserver()` per plain nested navigator, and reserve a cockpit-owned `setCurrentRouteName(...)` bridge for routers without provider or observer support
- use `CockpitRemoteSessionConfiguration.resolveFromEnvironment(...)` or an equivalent app-owned bridge so host launchers can enable control without editing production config
- keep remote-session enablement and debug diagnostics explicit
- treat direct `FlutterCockpitRoot` composition as an advanced escape hatch, not the default recommendation
