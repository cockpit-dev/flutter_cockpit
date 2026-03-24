# Host Devtools Setup Example

Use this pattern when the task is not "instrument the Flutter app" but "set up a host-side Dart tool or workflow that drives `flutter_cockpit`."

## Example Flow

1. Add `flutter_cockpit_devtools` to the host-side Dart package.
2. Run `dart pub get`.
3. Decide whether the host needs CLI-only usage or direct Dart imports.
4. Use the package CLI entrypoints or import the shared application services.

## Dependency

Add it to the host package's `dev_dependencies`.

From pub:

```yaml
dev_dependencies:
  flutter_cockpit_devtools: any
```

Or directly from Git:

```yaml
dev_dependencies:
  flutter_cockpit_devtools:
    git:
      url: https://github.com/cockpit-dev/flutter_cockpit.git
      path: packages/flutter_cockpit_devtools
```

Then install dependencies:

```bash
dart pub get
```

## CLI-First Usage

If the host only needs command execution, prefer the shipped CLI surface:

```bash
dart run flutter_cockpit_devtools:flutter_cockpit_devtools launch-development-session --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools collect-development-probe --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools collect-remote-snapshot --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools run-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_devtools validate-task --help
dart run flutter_cockpit_devtools:flutter_cockpit_mcp
```

When the agent needs copy-ready command templates with the required flags already present, prefer `examples/cli-command-reference.md` over raw `--help` output.

## Direct Dart Usage

If the host needs to call shared services directly:

```dart
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';

Future<void> main(List<String> args) async {
  final exitCode = await CockpitCommandRunner().run(args);
  if (exitCode != cockpitSuccessExitCode) {
    throw Exception('flutter_cockpit_devtools command failed: $exitCode');
  }
}
```

## Expected Agent Behavior

- do not add `flutter_cockpit_devtools` to the Flutter app package when the app only needs the in-app runtime
- use `flutter_cockpit_devtools` in host-side Dart tooling, automation wrappers, MCP adapters, or CI flows
- prefer the CLI entrypoints unless the host truly needs direct Dart-level access to shared services
- keep app-side integration in `flutter_cockpit` and host-side orchestration in `flutter_cockpit_devtools`
