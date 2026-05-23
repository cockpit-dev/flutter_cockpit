import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_interactive_cli_support.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_app_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('launch-app defaults project-dir and desktop platform when safe',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_launch_app_cli_defaults',
    );
    final previousCurrent = Directory.current;
    Directory.current = tempDir;
    addTearDown(() async {
      Directory.current = previousCurrent;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    CockpitLaunchAppRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchAppResult(
              app: CockpitAppHandle(
                appId: 'dev.cockpit.demo',
                mode: CockpitAppMode.development,
                platform: request.platform,
                deviceId: request.deviceId,
                projectDir: request.projectDir,
                target: request.target ?? 'cockpit/main.dart',
                baseUrl: 'http://127.0.0.1:57331',
                launchedAt: DateTime.utc(2026, 4, 12),
              ),
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>['launch-app']) ?? 0;

    expect(exitCode, 0);
    expect(
      File(capturedRequest!.projectDir).resolveSymbolicLinksSync(),
      tempDir.resolveSymbolicLinksSync(),
    );
    expect(capturedRequest?.platform, _hostDesktopPlatform());
    expect(capturedRequest?.deviceId, _hostDesktopPlatform());
  });

  test('launch-app persists the default latest app handle path when omitted',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_launch_app_cli',
    );
    final previousCurrent = Directory.current;
    Directory.current = tempDir;
    addTearDown(() async {
      Directory.current = previousCurrent;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    CockpitLaunchAppRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          stdoutSink: stdoutBuffer,
          launch: (request) async {
            capturedRequest = request;
            final handle = CockpitAppHandle(
              appId: 'dev.cockpit.demo',
              mode: CockpitAppMode.development,
              platform: 'macos',
              deviceId: 'macos',
              projectDir: request.projectDir,
              target: request.target ?? 'cockpit/main.dart',
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 4, 12),
            );
            final path = request.appHandlePath!;
            final file = File(path);
            await file.parent.create(recursive: true);
            await file.writeAsString(jsonEncode(handle.toJson()));
            return CockpitLaunchAppResult(
              app: handle,
              appJsonPath: path,
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-app',
          '--project-dir',
          'examples/cockpit_demo',
          '--platform',
          'macos',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(
      p.equals(
        capturedRequest?.appHandlePath ?? '',
        cockpitDefaultAppHandlePath(Directory.current.path),
      ),
      isTrue,
    );
    expect(File(capturedRequest!.appHandlePath!).existsSync(), isTrue);
    expect(stdoutBuffer.toString(), contains('appJsonPath'));
  });

  test('launch-app forwards flavor when provided', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchAppResult(
              app: CockpitAppHandle(
                appId: 'dev.cockpit.demo',
                mode: CockpitAppMode.development,
                platform: 'android',
                deviceId: 'emulator-5554',
                projectDir: request.projectDir,
                target: request.target ?? 'cockpit/main.dart',
                baseUrl: 'http://127.0.0.1:57331',
                launchedAt: DateTime.utc(2026, 4, 12),
              ),
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-app',
          '--project-dir',
          'examples/cockpit_demo',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--flavor',
          'staging',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.flavor, 'staging');
  });
}

String _hostDesktopPlatform() {
  if (Platform.isMacOS) {
    return 'macos';
  }
  if (Platform.isWindows) {
    return 'windows';
  }
  if (Platform.isLinux) {
    return 'linux';
  }
  throw StateError('This test requires a desktop host.');
}
