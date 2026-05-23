import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launch_options.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_windows_remote_session_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'windows remote session launcher builds, launches, and returns a handle',
    () async {
      final buildInvocations = <String>[];
      final launchInvocations = <String>[];
      final launcher = CockpitWindowsRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              buildInvocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        appExecutablePathResolver: ({required String projectDir}) async =>
            '$projectDir/build/windows/x64/runner/Debug/cockpit_demo.exe',
        appStarter:
            ({
              required String executablePath,
              List<String> arguments = const <String>[],
              String? workingDirectory,
              required Duration timeout,
            }) async {
              launchInvocations.add(
                '$executablePath ${arguments.join(' ')} @${workingDirectory ?? ''}',
              );
              return 4101;
            },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'windows-bootstrap-session',
          platform: 'windows',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'windows',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
            supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      final handle = await launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
        ),
      );

      expect(handle.platform, 'windows');
      expect(handle.deviceId, 'windows');
      expect(handle.appId, 'cockpit_demo');
      expect(handle.processId, 4101);
      expect(handle.baseUrl, 'http://127.0.0.1:47331');
      expect(
        buildInvocations,
        contains(
          '${cockpitFlutterExecutable()} build windows --debug --target cockpit/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        launchInvocations,
        contains(
          '/workspace/examples/cockpit_demo/build/windows/x64/runner/Debug/cockpit_demo.exe  @/workspace/examples/cockpit_demo/build/windows/x64/runner/Debug',
        ),
      );
    },
  );

  test('windows remote session launcher times out slow build stages', () async {
    final launcher = CockpitWindowsRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) {
        return Future<ProcessResult>.delayed(
          const Duration(milliseconds: 150),
          () => ProcessResult(0, 0, '', ''),
        );
      },
      now: () => DateTime.utc(2026, 3, 24, 12),
    );

    expect(
      () => launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
          launchTimeout: Duration(milliseconds: 50),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'windows remote session launcher prefers the executable that matches pubspec name',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_windows_remote_session_launcher_executable',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      await File(
        p.join(tempDir.path, 'pubspec.yaml'),
      ).writeAsString('name: cockpit_demo\n');
      final outputDirectory = Directory(
        p.join(tempDir.path, 'build', 'windows', 'x64', 'runner', 'Debug'),
      )..createSync(recursive: true);
      final helperExe = File(p.join(outputDirectory.path, 'a_helper.exe'))
        ..writeAsStringSync('');
      final appExe = File(p.join(outputDirectory.path, 'cockpit_demo.exe'))
        ..writeAsStringSync('');
      String? launchedExecutable;

      final launcher = CockpitWindowsRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              return ProcessResult(0, 0, '', '');
            },
        appStarter:
            ({
              required String executablePath,
              List<String> arguments = const <String>[],
              String? workingDirectory,
              required Duration timeout,
            }) async {
              launchedExecutable = executablePath;
              return 9001;
            },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'windows-bootstrap-session',
          platform: 'windows',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'windows',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'cockpit/main.dart',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 47331,
        ),
      );

      expect(helperExe.existsSync(), isTrue);
      expect(launchedExecutable, appExe.path);
    },
  );
}
