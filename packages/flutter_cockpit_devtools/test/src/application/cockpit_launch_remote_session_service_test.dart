import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_entrypoint_resolver.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launch_options.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'launch service returns a reusable session handle, health, and optional persisted json',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_launch_remote_session_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final expectedHandle = CockpitRemoteSessionHandle(
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final expectedStatus = CockpitRemoteSessionStatus(
        sessionId: 'launch-demo',
        platform: 'android',
        transportType: 'remoteHttp',
        currentRouteName: '/home',
        capabilities: CockpitCapabilities(
          platform: 'android',
          transportType: 'remoteHttp',
          supportsInAppControl: true,
          supportsFlutterViewCapture: true,
          supportsNativeScreenCapture: true,
          supportsHostAutomation: false,
          supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
          supportedLocatorStrategies: CockpitLocatorKind.values,
        ),
        recordingCapabilities: CockpitRecordingCapabilities(
          supportsNativeRecording: true,
          preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
        ),
        snapshot: CockpitSnapshot(routeName: '/home'),
      );

      final outputFile = File(p.join(tempDir.path, 'session_handle.json'));
      final service = CockpitLaunchRemoteSessionService(
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        launcher: _FakeRemoteSessionLauncher(expectedHandle),
        statusReader: (baseUri) async {
          expect(baseUri.toString(), expectedHandle.baseUrl);
          return expectedStatus;
        },
      );

      final result = await service.launch(
        CockpitLaunchRemoteSessionRequest(
          projectDir: expectedHandle.projectDir,
          target: expectedHandle.target,
          platform: expectedHandle.platform,
          deviceId: expectedHandle.deviceId,
          sessionPort: expectedHandle.devicePort,
          launchTimeout: const Duration(seconds: 45),
          persistHandlePath: outputFile.path,
        ),
      );

      expect(result.sessionHandle.toJson(), expectedHandle.toJson());
      expect(result.health.sessionId, 'launch-demo');
      expect(result.persistedHandlePath, outputFile.path);

      final persistedJson =
          jsonDecode(await outputFile.readAsString()) as Map<String, Object?>;
      expect(persistedJson['platform'], 'android');
      expect(persistedJson['deviceId'], 'emulator-5554');
      expect(persistedJson['baseUrl'], 'http://127.0.0.1:58421');
    },
  );

  test('launch service infers cockpit/main.dart when target is omitted',
      () async {
    final expectedHandle = CockpitRemoteSessionHandle(
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 58421,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:58421',
      launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
    );
    final expectedStatus = CockpitRemoteSessionStatus(
      sessionId: 'launch-demo',
      platform: 'macos',
      transportType: 'remoteHttp',
      currentRouteName: '/home',
      capabilities: CockpitCapabilities(
        platform: 'macos',
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
    );

    final service = CockpitLaunchRemoteSessionService(
      entrypointResolver: CockpitEntrypointResolver(
        exists: (path) =>
            path == '/workspace/examples/cockpit_demo/cockpit/main.dart',
      ),
      launcher: _FakeRemoteSessionLauncher(expectedHandle),
      statusReader: (_) async => expectedStatus,
    );

    final result = await service.launch(
      CockpitLaunchRemoteSessionRequest(
        projectDir: expectedHandle.projectDir,
        platform: expectedHandle.platform,
        deviceId: expectedHandle.deviceId,
        sessionPort: expectedHandle.devicePort,
      ),
    );

    expect(result.sessionHandle.target, 'cockpit/main.dart');
  });
}

final class _FakeRemoteSessionLauncher implements CockpitRemoteSessionLauncher {
  const _FakeRemoteSessionLauncher(this.handle);

  final CockpitRemoteSessionHandle handle;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    expect(options.projectDir, handle.projectDir);
    expect(options.target, handle.target);
    expect(options.platform, handle.platform);
    expect(options.deviceId, handle.deviceId);
    expect(options.sessionPort, handle.devicePort);
    return handle;
  }
}
