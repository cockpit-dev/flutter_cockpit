import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_session_registry.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test('developmentSessionByAppId returns the latest updated record', () {
    final registry = CockpitSessionRegistry(
      now: _clockFrom(<DateTime>[
        DateTime.utc(2026, 5, 10, 10, 0, 0),
        DateTime.utc(2026, 5, 10, 10, 5, 0),
      ]),
    );
    registry.recordDevelopmentSession(
      handle: _developmentHandle(
        id: 'dev-1',
        appBaseUrl: 'http://127.0.0.1:57331',
      ),
      status: _developmentStatus('dev-1'),
    );
    registry.recordDevelopmentSession(
      handle: _developmentHandle(
        id: 'dev-2',
        appBaseUrl: 'http://127.0.0.1:58331',
      ),
      status: _developmentStatus('dev-2'),
    );

    final record = registry.developmentSessionByAppId('dev.example.app');

    expect(record?.handle.developmentSessionId, 'dev-2');
    expect(record?.handle.appBaseUrl, 'http://127.0.0.1:58331');
  });

  test('remoteSessionByAppId returns the latest updated record', () {
    final registry = CockpitSessionRegistry(
      now: _clockFrom(<DateTime>[
        DateTime.utc(2026, 5, 10, 10, 0, 0),
        DateTime.utc(2026, 5, 10, 10, 5, 0),
      ]),
    );
    registry.recordRemoteSession(
      handle: _remoteHandle(hostPort: 57331),
      status: _remoteStatus(),
      recommendedNextStep: 'ready',
    );
    registry.recordRemoteSession(
      handle: _remoteHandle(hostPort: 58331),
      status: _remoteStatus(),
      recommendedNextStep: 'ready',
    );

    final record = registry.remoteSessionByAppId('dev.example.app');

    expect(record?.handle.hostPort, 58331);
    expect(record?.recommendedNextStep, 'ready');
  });
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

CockpitDevelopmentSessionHandle _developmentHandle({
  required String id,
  required String appBaseUrl,
}) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: id,
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/app',
    target: 'cockpit/main.dart',
    appId: 'dev.example.app',
    appBaseUrl: appBaseUrl,
    supervisorBaseUrl: 'http://127.0.0.1:57332',
    launchedAt: DateTime.utc(2026, 5, 10),
    reloadGeneration: 0,
  );
}

CockpitDevelopmentSessionStatus _developmentStatus(String id) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: id,
    state: CockpitDevelopmentSessionState.ready,
    appReachable: true,
    remoteSessionReachable: true,
    reloadGeneration: 0,
    lastStatusAt: DateTime.utc(2026, 5, 10),
  );
}

CockpitRemoteSessionHandle _remoteHandle({required int hostPort}) {
  return CockpitRemoteSessionHandle(
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/app',
    target: 'cockpit/main.dart',
    appId: 'dev.example.app',
    host: '127.0.0.1',
    hostPort: hostPort,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:$hostPort',
    launchedAt: DateTime.utc(2026, 5, 10),
  );
}

CockpitRemoteSessionStatus _remoteStatus() {
  return CockpitRemoteSessionStatus(
    sessionId: 'session-1',
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
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
      supportedLayers: <CockpitRecordingLayer>[CockpitRecordingLayer.system],
    ),
    snapshot: CockpitSnapshot(
      routeName: '/home',
      summary: const CockpitSnapshotSummary(
        visibleTargetCount: 0,
        targetsWithCockpitIdCount: 0,
        targetsWithTextCount: 0,
        styleDetailsIncluded: false,
        diagnosticPropertiesIncluded: false,
        ancestorSummariesIncluded: false,
        rebuildSummaryIncluded: false,
        accessibilitySummaryIncluded: false,
      ),
    ),
  );
}
