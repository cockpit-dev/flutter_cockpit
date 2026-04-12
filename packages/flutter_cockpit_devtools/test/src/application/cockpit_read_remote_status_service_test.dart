import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_status_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitReadRemoteStatusService', () {
    test('reads status through a session handle', () async {
      final handle = _sessionHandle();
      Uri? capturedBaseUri;
      final service = CockpitReadRemoteStatusService(
        readStatus: (baseUri) async {
          capturedBaseUri = baseUri;
          return _status(snapshot: CockpitSnapshot(routeName: '/home'));
        },
      );

      final result = await service.read(
        CockpitReadRemoteStatusRequest(
          sessionHandle: handle,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(capturedBaseUri, handle.baseUri);
      expect(result.sessionId, 'session-1');
      expect(result.currentRouteName, '/home');
      expect(result.snapshot, isNull);
      expect(result.uiSummary, isNull);
    });

    test('reads a richer snapshot when the profile requires it', () async {
      CockpitSnapshotOptions? capturedOptions;
      final service = CockpitReadRemoteStatusService(
        readStatus: (_) async => _status(
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
        readSnapshot: (_, options) async {
          capturedOptions = options;
          return CockpitRemoteSnapshotResponse(
            snapshot: CockpitSnapshot(
              routeName: '/details',
              diagnosticLevel: CockpitSnapshotProfile.investigate,
              visibleTargets: <CockpitSnapshotTarget>[
                CockpitSnapshotTarget(
                  registrationId: 'target-1',
                  routeName: '/details',
                  text: 'Details',
                ),
              ],
              summary: const CockpitSnapshotSummary(
                visibleTargetCount: 1,
                targetsWithCockpitIdCount: 0,
                targetsWithTextCount: 1,
                styleDetailsIncluded: true,
                diagnosticPropertiesIncluded: true,
                ancestorSummariesIncluded: false,
                rebuildSummaryIncluded: false,
                accessibilitySummaryIncluded: false,
              ),
            ),
          );
        },
      );

      final result = await service.read(
        CockpitReadRemoteStatusRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(capturedOptions?.profile, CockpitSnapshotProfile.investigate);
      expect(result.currentRouteName, '/details');
      expect(result.uiSummary?.routeName, '/details');
      expect(result.snapshot, isNull);
      expect(result.snapshotRef, isNotEmpty);
    });

    test('returns full snapshots for forensic reads', () async {
      final service = CockpitReadRemoteStatusService(
        readStatus: (_) async => _status(
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/forensic',
            diagnosticLevel: CockpitSnapshotProfile.forensic,
          ),
        ),
      );

      final result = await service.read(
        CockpitReadRemoteStatusRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.evidence(),
        ),
      );

      expect(result.snapshot?.routeName, '/forensic');
      expect(result.uiSummary, isNull);
    });

    test('retries transient empty rich snapshots for read-app flows', () async {
      var readCount = 0;
      final service = CockpitReadRemoteStatusService(
        readStatus: (_) async => _status(
          snapshot: CockpitSnapshot(routeName: '/settings'),
        ),
        readSnapshot: (_, __) async {
          readCount += 1;
          return CockpitRemoteSnapshotResponse(
            snapshot: readCount == 1
                ? CockpitSnapshot(
                    routeName: '/settings',
                    diagnosticLevel: CockpitSnapshotProfile.forensic,
                    summary: const CockpitSnapshotSummary(
                      visibleTargetCount: 0,
                      targetsWithCockpitIdCount: 0,
                      targetsWithTextCount: 0,
                      styleDetailsIncluded: true,
                      diagnosticPropertiesIncluded: true,
                      ancestorSummariesIncluded: true,
                      rebuildSummaryIncluded: true,
                      accessibilitySummaryIncluded: true,
                    ),
                  )
                : CockpitSnapshot(
                    routeName: '/settings',
                    diagnosticLevel: CockpitSnapshotProfile.forensic,
                    visibleTargets: <CockpitSnapshotTarget>[
                      CockpitSnapshotTarget(
                        registrationId: 'settings-save',
                        routeName: '/settings',
                        text: 'Save settings',
                      ),
                    ],
                    summary: const CockpitSnapshotSummary(
                      visibleTargetCount: 1,
                      targetsWithCockpitIdCount: 0,
                      targetsWithTextCount: 1,
                      styleDetailsIncluded: true,
                      diagnosticPropertiesIncluded: true,
                      ancestorSummariesIncluded: true,
                      rebuildSummaryIncluded: true,
                      accessibilitySummaryIncluded: true,
                    ),
                  ),
          );
        },
      );

      final result = await service.read(
        CockpitReadRemoteStatusRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.evidence(),
        ),
      );

      expect(readCount, 2);
      expect(result.currentRouteName, '/settings');
      expect(result.snapshot?.visibleTargets, isNotEmpty);
    });
  });
}

CockpitRemoteSessionStatus _status({required CockpitSnapshot snapshot}) {
  return CockpitRemoteSessionStatus(
    sessionId: 'session-1',
    platform: 'macos',
    transportType: 'remoteHttp',
    currentRouteName: snapshot.routeName,
    capabilities: CockpitCapabilities(
      platform: 'macos',
      transportType: 'remoteHttp',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: true,
      supportsHostAutomation: false,
      supportedCommands: const <CockpitCommandType>[CockpitCommandType.tap],
      supportedLocatorStrategies: CockpitLocatorKind.values,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
    ),
    snapshot: snapshot,
  );
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 47331,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 3, 30),
  );
}
