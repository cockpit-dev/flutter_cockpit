import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/session/cockpit_linux_remote_session_launcher.dart';
import 'package:cockpit/src/session/cockpit_remote_session_launch_options.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'linux remote session launcher builds, launches, and returns a handle',
    () async {
      final buildInvocations = <String>[];
      final launchInvocations = <String>[];
      final launcher = CockpitLinuxRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              buildInvocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        appExecutablePathResolver: ({required String projectDir}) async =>
            '$projectDir/build/linux/x64/debug/bundle/cockpit_demo',
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
              return 5101;
            },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'linux-bootstrap-session',
          platform: 'linux',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'linux',
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
          platform: 'linux',
          deviceId: 'linux',
          sessionPort: 47331,
        ),
      );

      expect(handle.platform, 'linux');
      expect(handle.deviceId, 'linux');
      expect(handle.appId, 'cockpit_demo');
      expect(handle.processId, 5101);
      expect(handle.baseUrl, 'http://127.0.0.1:47331');
      expect(
        buildInvocations,
        contains(
          'flutter build linux --debug --target cockpit/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        launchInvocations,
        contains(
          '/workspace/examples/cockpit_demo/build/linux/x64/debug/bundle/cockpit_demo  @/workspace/examples/cockpit_demo/build/linux/x64/debug/bundle',
        ),
      );
    },
  );

  test(
    'linux launcher reads Flutter version from the configured executable',
    () async {
      final buildInvocations = <String>[];
      final launcher = CockpitLinuxRemoteSessionLauncher(
        flutterVersionReader: () async =>
            throw StateError('legacy version reader should not be used'),
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              buildInvocations.add('$executable ${arguments.join(' ')}');
              if (executable == '/opt/flutter/bin/flutter' &&
                  arguments.join(' ') == '--version --machine') {
                return ProcessResult(0, 0, '{"frameworkVersion":"3.32.0"}', '');
              }
              return ProcessResult(0, 0, '', '');
            },
        appExecutablePathResolver: ({required String projectDir}) async =>
            '$projectDir/build/linux/x64/debug/bundle/cockpit_demo',
        appStarter:
            ({
              required String executablePath,
              List<String> arguments = const <String>[],
              String? workingDirectory,
              required Duration timeout,
            }) async => 5101,
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'linux-sdk-session',
          platform: 'linux',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'linux',
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
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'linux',
          deviceId: 'linux',
          sessionPort: 47331,
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(
        buildInvocations,
        contains('/opt/flutter/bin/flutter --version --machine'),
      );
      expect(
        buildInvocations,
        contains(
          '/opt/flutter/bin/flutter build linux --debug --target cockpit/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.32.0',
        ),
      );
    },
  );

  test('linux remote session launcher times out slow build stages', () async {
    final launcher = CockpitLinuxRemoteSessionLauncher(
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
          platform: 'linux',
          deviceId: 'linux',
          sessionPort: 47331,
          launchTimeout: Duration(milliseconds: 50),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'linux remote session launcher prefers the executable that matches pubspec name',
    () async {
      if (Platform.isWindows) {
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_remote_session_launcher_executable',
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
        p.join(tempDir.path, 'build', 'linux', 'x64', 'debug', 'bundle'),
      )..createSync(recursive: true);
      final helperBinary = File(p.join(outputDirectory.path, 'a_helper'))
        ..writeAsStringSync('');
      final appBinary = File(p.join(outputDirectory.path, 'cockpit_demo'))
        ..writeAsStringSync('');
      await Process.run('chmod', <String>[
        '+x',
        helperBinary.path,
        appBinary.path,
      ]);
      String? launchedExecutable;

      final launcher = CockpitLinuxRemoteSessionLauncher(
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
              return 9002;
            },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'linux-bootstrap-session',
          platform: 'linux',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'linux',
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
          platform: 'linux',
          deviceId: 'linux',
          sessionPort: 47331,
        ),
      );

      expect(launchedExecutable, appBinary.path);
    },
  );
}
