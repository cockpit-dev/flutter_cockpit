import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_snapshot_store.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_snapshot_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitReadRemoteSnapshotService', () {
    test('reads snapshots with profile-normalized options', () async {
      CockpitSnapshotOptions? capturedOptions;
      final service = CockpitReadRemoteSnapshotService(
        readSnapshot: (_, options) async {
          capturedOptions = options;
          return CockpitRemoteSnapshotResponse(
            snapshot: CockpitSnapshot(
              routeName: '/details',
              diagnosticLevel: options.profile,
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
        CockpitReadRemoteSnapshotRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.standard(),
        ),
      );

      expect(capturedOptions?.profile, CockpitSnapshotProfile.baseline);
      expect(result.uiSummary?.routeName, '/details');
      expect(result.snapshot, isNull);
      expect(result.snapshotRef, isNotEmpty);
    });

    test('returns full snapshots for forensic reads', () async {
      final service = CockpitReadRemoteSnapshotService(
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/forensic',
            diagnosticLevel: CockpitSnapshotProfile.forensic,
          ),
        ),
      );

      final result = await service.read(
        CockpitReadRemoteSnapshotRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.evidence(),
        ),
      );

      expect(result.snapshot?.routeName, '/forensic');
      expect(result.uiSummary, isNull);
    });

    test('filters failures-only diagnostics for inspect reads', () async {
      final service = CockpitReadRemoteSnapshotService(
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/inspect',
            diagnosticLevel: CockpitSnapshotProfile.investigate,
            network: CockpitNetworkSnapshot(
              totalEntryCount: 1,
              failureCount: 1,
              entries: <CockpitNetworkEntry>[
                CockpitNetworkEntry(
                  requestId: 'network-1',
                  method: 'GET',
                  uri: 'https://example.com/fail',
                  startedAt: DateTime.utc(2026, 3, 30),
                  durationMs: 80,
                  statusCode: 500,
                ),
              ],
              capturedEntryCount: 1,
            ),
            runtime: CockpitRuntimeSnapshot(
              totalEntryCount: 1,
              errorCount: 1,
              warningCount: 0,
              entries: <CockpitRuntimeEvent>[
                CockpitRuntimeEvent(
                  eventId: 'runtime-1',
                  kind: CockpitRuntimeEventKind.flutterError,
                  severity: CockpitRuntimeEventSeverity.error,
                  message: 'boom',
                  recordedAt: DateTime.utc(2026, 3, 30),
                ),
              ],
            ),
            rebuild: const CockpitRebuildSnapshot(
              totalRebuildCount: 3,
              uniqueElementCount: 1,
              capturedEntryCount: 1,
              truncated: false,
              entries: <CockpitRebuildEntry>[],
            ),
            accessibility: CockpitAccessibilitySummary(
              totalAccessibleTargetCount: 1,
              traversalEntries: const <CockpitAccessibilityEntry>[
                CockpitAccessibilityEntry(nodeId: 1, label: 'Inspect'),
              ],
              truncated: false,
            ),
          ),
        ),
      );

      final result = await service.read(
        CockpitReadRemoteSnapshotRequest(
          sessionHandle: _sessionHandle(),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(result.diagnostics?['level'], 'failures_only');
      expect(result.diagnostics?['network'], isNotNull);
      expect(result.diagnostics?['runtime'], isNotNull);
      expect(result.diagnostics?.containsKey('rebuild'), isFalse);
      expect(result.diagnostics?.containsKey('accessibility'), isFalse);
    });

    test('reports missing compare refs as structured errors', () async {
      final service = CockpitReadRemoteSnapshotService(
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(routeName: '/details'),
        ),
      );

      expect(
        () => service.read(
          CockpitReadRemoteSnapshotRequest(
            sessionHandle: _sessionHandle(),
            compareAgainstSnapshotRef: 'missing-ref',
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'interactiveSnapshotRefNotFound',
          ),
        ),
      );
    });

    test('returns deltas when comparing with a stored snapshot', () async {
      final store = CockpitInteractiveSnapshotStore();
      final baselineRef = store.put(
        sessionKey: _sessionHandle().baseUri.toString(),
        snapshot: CockpitSnapshot(
          routeName: '/before',
          visibleTargets: <CockpitSnapshotTarget>[
            CockpitSnapshotTarget(
              registrationId: 'target-1',
              routeName: '/before',
              text: 'Before',
            ),
          ],
        ),
      );
      final service = CockpitReadRemoteSnapshotService(
        snapshotStore: store,
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/after',
            visibleTargets: <CockpitSnapshotTarget>[
              CockpitSnapshotTarget(
                registrationId: 'target-1',
                routeName: '/after',
                text: 'After',
              ),
            ],
          ),
        ),
      );

      final result = await service.read(
        CockpitReadRemoteSnapshotRequest(
          sessionHandle: _sessionHandle(),
          compareAgainstSnapshotRef: baselineRef,
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(result.delta?.routeChanged, isTrue);
      expect(result.delta?.addedTextPreviews, contains('After'));
    });
  });
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
