import 'dart:convert';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_session_registry.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:cockpit/src/mcp/core/cockpit_mcp_resource.dart';
import 'package:cockpit/src/mcp/resources/cockpit_apps_resource.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'app resource returns the newest tracked record for a shared app id',
    () async {
      final registry = CockpitSessionRegistry(
        now: _clockFrom(<DateTime>[
          DateTime.utc(2026, 5, 10, 10, 0, 0),
          DateTime.utc(2026, 5, 10, 10, 5, 0),
        ]),
      );
      registry.recordDevelopmentSession(
        handle: _developmentHandle(),
        status: _developmentStatus(),
      );
      registry.recordRemoteSession(
        handle: _remoteHandle(),
        status: _remoteStatus(),
        recommendedNextStep: 'ready_for_commands',
      );

      final resource = CockpitAppResource(registry: registry);
      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://app/details?appId=dev.example.app',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      final decoded = jsonDecode(contents.text) as Map<String, Object?>;
      expect(decoded['state'], 'ready_for_commands');
      expect((decoded['app'] as Map<String, Object?>)['mode'], 'automation');
    },
  );
}

DateTime Function() _clockFrom(List<DateTime> instants) {
  var index = 0;
  return () {
    final value = instants[index];
    if (index < instants.length - 1) {
      index += 1;
    }
    return value;
  };
}

CockpitDevelopmentSessionHandle _developmentHandle() =>
    CockpitDevelopmentSessionHandle(
      developmentSessionId: 'dev-session-1',
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/app',
      target: 'lib/main.dart',
      appId: 'dev.example.app',
      appBaseUrl: 'http://127.0.0.1:57331',
      supervisorBaseUrl: 'http://127.0.0.1:59331',
      launchedAt: DateTime.utc(2026, 5, 10, 10, 0, 0),
      reloadGeneration: 0,
    );

CockpitDevelopmentSessionStatus _developmentStatus() =>
    CockpitDevelopmentSessionStatus(
      developmentSessionId: 'dev-session-1',
      state: CockpitDevelopmentSessionState.ready,
      appReachable: true,
      remoteSessionReachable: true,
      reloadGeneration: 0,
      lastStatusAt: DateTime.utc(2026, 5, 10, 10, 0, 0),
    );

CockpitRemoteSessionHandle _remoteHandle() => CockpitRemoteSessionHandle(
  platform: 'android',
  deviceId: 'emulator-5554',
  projectDir: '/workspace/app',
  target: 'cockpit/main.dart',
  appId: 'dev.example.app',
  host: '127.0.0.1',
  hostPort: 58331,
  devicePort: 47331,
  baseUrl: 'http://127.0.0.1:58331',
  launchedAt: DateTime.utc(2026, 5, 10, 10, 5, 0),
);

CockpitRemoteSessionStatus _remoteStatus() => CockpitRemoteSessionStatus(
  sessionId: 'remote-session-1',
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
