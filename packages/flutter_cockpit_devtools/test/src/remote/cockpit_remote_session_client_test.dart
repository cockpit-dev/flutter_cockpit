import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test(
    'remote session client reads health, snapshot, command, and recording flows',
    () async {
      Uri? snapshotRequestUri;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        switch ((request.method, request.uri.path)) {
          case ('GET', '/health'):
            request.response.write(
              jsonEncode(
                CockpitRemoteSessionStatus(
                  sessionId: 'remote-demo',
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
                    supportedCommands: <CockpitCommandType>[
                      CockpitCommandType.tap,
                      CockpitCommandType.captureScreenshot,
                    ],
                    supportedLocatorStrategies: CockpitLocatorKind.values,
                  ),
                  recordingCapabilities: CockpitRecordingCapabilities(
                    supportsNativeRecording: true,
                    preferredAcceptanceRecordingKind:
                        CockpitRecordingKind.nativeScreen,
                  ),
                  snapshot: CockpitSnapshot(
                    routeName: '/home',
                    runtime: CockpitRuntimeSnapshot(
                      totalEntryCount: 1,
                      errorCount: 1,
                      warningCount: 0,
                      entries: <CockpitRuntimeEvent>[
                        CockpitRuntimeEvent(
                          eventId: 'runtime-1',
                          kind: CockpitRuntimeEventKind.flutterError,
                          severity: CockpitRuntimeEventSeverity.error,
                          message: 'RenderFlex overflowed',
                          recordedAt: DateTime.utc(2026, 3, 22, 1, 0),
                        ),
                      ],
                    ),
                  ),
                ).toJson(),
              ),
            );
          case ('GET', '/snapshot'):
            snapshotRequestUri = request.uri;
            request.response.write(
              jsonEncode(
                CockpitSnapshot(
                  routeName: '/home',
                  diagnosticLevel: CockpitSnapshotProfile.investigate,
                  runtime: CockpitRuntimeSnapshot(
                    totalEntryCount: 1,
                    errorCount: 1,
                    warningCount: 0,
                    entries: <CockpitRuntimeEvent>[
                      CockpitRuntimeEvent(
                        eventId: 'runtime-1',
                        kind: CockpitRuntimeEventKind.flutterError,
                        severity: CockpitRuntimeEventSeverity.error,
                        message: 'RenderFlex overflowed',
                        recordedAt: DateTime.utc(2026, 3, 22, 1, 0),
                      ),
                    ],
                  ),
                  visibleTargets: <CockpitSnapshotTarget>[
                    CockpitSnapshotTarget(
                      registrationId: 'home.open_form_button',
                      cockpitId: 'open_form_button',
                      text: 'Open form',
                      typeName: 'ElevatedButton',
                      routeName: '/home',
                      supportedCommands: <CockpitCommandType>[
                        CockpitCommandType.tap,
                      ],
                    ),
                  ],
                ).toJson(),
              ),
            );
          case ('POST', '/commands/execute'):
            request.response.write(
              jsonEncode(
                CockpitRemoteCommandResponse(
                  result: CockpitCommandResult(
                    success: true,
                    commandId: 'tap-open',
                    commandType: CockpitCommandType.tap,
                    durationMs: 42,
                    locatorResolution: const CockpitLocatorResolution(
                      matchedKind: CockpitLocatorKind.cockpitId,
                      matchedValue: 'open_form_button',
                    ),
                    snapshot: CockpitSnapshot(routeName: '/form').toJson(),
                  ),
                  artifactPayloads: const <CockpitRemoteArtifactPayload>[
                    CockpitRemoteArtifactPayload(
                      artifact: CockpitArtifactRef(
                        role: 'screenshot',
                        relativePath: 'screenshots/form_after_action.png',
                      ),
                      bytes: <int>[1, 2, 3, 4],
                    ),
                  ],
                ).toJson(),
              ),
            );
          case ('POST', '/recording/start'):
            request.response.write(
              jsonEncode(
                const CockpitRecordingSession(
                  request: CockpitRecordingRequest(
                    purpose: CockpitRecordingPurpose.acceptance,
                    name: 'demo_acceptance',
                    attachToStep: true,
                  ),
                  state: CockpitRecordingState.recording,
                ).toJson(),
              ),
            );
          case ('POST', '/recording/stop'):
            request.response.write(
              jsonEncode(
                CockpitRemoteRecordingResponse(
                  result: CockpitRecordingResult(
                    state: CockpitRecordingState.completed,
                    purpose: CockpitRecordingPurpose.acceptance,
                    recordingKind: CockpitRecordingKind.nativeScreen,
                    artifact: const CockpitArtifactRef(
                      role: 'recording',
                      relativePath: 'recordings/demo_acceptance.mp4',
                    ),
                    durationMs: 2600,
                  ),
                  artifactDownloads: const <CockpitRemoteArtifactDownload>[
                    CockpitRemoteArtifactDownload(
                      artifact: CockpitArtifactRef(
                        role: 'recording',
                        relativePath: 'recordings/demo_acceptance.mp4',
                      ),
                      downloadPath:
                          '/artifacts/download?path=recordings%2Fdemo_acceptance.mp4',
                    ),
                  ],
                ).toJson(),
              ),
            );
          case ('GET', '/artifacts/download'):
            request.response.headers.contentType = ContentType.binary;
            request.response.add(const <int>[8, 6, 7, 5, 3, 0, 9]);
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final client = CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      final status = await client.readStatus();
      final snapshot = await client.readSnapshot(
        options: const CockpitSnapshotOptions.investigate(),
      );
      final execution = await client.executeDetailed(
        CockpitCommand(
          commandId: 'tap-open',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(
            cockpitId: 'open_form_button',
          ),
        ),
      );
      final recordingSession = await client.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'demo_acceptance',
          attachToStep: true,
        ),
      );
      final recordingResult = await client.stopRecording();

      expect(status.currentRouteName, '/home');
      expect(status.snapshot.diagnosticLevel, CockpitSnapshotProfile.live);
      expect(status.snapshot.runtime?.errorCount, 1);
      expect(
        snapshotRequestUri?.queryParameters['profile'],
        CockpitSnapshotProfile.investigate.jsonValue,
      );
      expect(
        snapshotRequestUri?.queryParameters['includeNetworkActivity'],
        'true',
      );
      expect(snapshotRequestUri?.queryParameters['maxNetworkEntries'], '8');
      expect(
        snapshotRequestUri?.queryParameters['networkOnlyFailures'],
        'true',
      );
      expect(
        snapshotRequestUri?.queryParameters['includeRuntimeActivity'],
        'true',
      );
      expect(snapshotRequestUri?.queryParameters['runtimeOnlyErrors'], 'true');
      expect(
        snapshotRequestUri?.queryParameters['includeRebuildActivity'],
        'true',
      );
      expect(snapshotRequestUri?.queryParameters['maxRebuildEntries'], '8');
      expect(
        snapshotRequestUri?.queryParameters['includeAccessibilitySummary'],
        'true',
      );
      expect(
        snapshotRequestUri?.queryParameters['maxAccessibilityEntries'],
        '8',
      );
      expect(snapshot.visibleTargets.single.cockpitId, 'open_form_button');
      expect(snapshot.diagnosticLevel, CockpitSnapshotProfile.investigate);
      expect(snapshot.runtime?.errorCount, 1);
      expect(execution.result.success, isTrue);
      expect(
        execution.artifactPayloads['screenshots/form_after_action.png'],
        <int>[1, 2, 3, 4],
      );
      expect(recordingSession.state, CockpitRecordingState.recording);
      expect(
        recordingResult.artifact?.relativePath,
        'recordings/demo_acceptance.mp4',
      );
      expect(recordingResult.bytes, <int>[8, 6, 7, 5, 3, 0, 9]);
    },
  );

  test(
    'remote session client downloads externalized forensic snapshot artifacts',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final fullSnapshot = CockpitSnapshot(
        routeName: '/debug',
        diagnosticLevel: CockpitSnapshotProfile.forensic,
        visibleTargets: <CockpitSnapshotTarget>[
          CockpitSnapshotTarget(
            registrationId: 'debug.sync_check',
            keyValue: 'settings-sync-check-button',
            text: 'Run check',
            typeName: 'FilledButton',
            routeName: '/debug',
            supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
            diagnosticProperties: <CockpitDiagnosticProperty>[
              const CockpitDiagnosticProperty(
                name: 'payload',
                value: '',
                category: CockpitDiagnosticCategory.other,
              ),
            ],
          ),
        ],
      );
      final inflatedSnapshot = fullSnapshot.copyWith(
        visibleTargets: <CockpitSnapshotTarget>[
          CockpitSnapshotTarget(
            registrationId: 'debug.sync_check',
            keyValue: 'settings-sync-check-button',
            text: 'Run check',
            typeName: 'FilledButton',
            routeName: '/debug',
            supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
            diagnosticProperties: <CockpitDiagnosticProperty>[
              CockpitDiagnosticProperty(
                name: 'payload',
                value: 'x' * 24000,
                category: CockpitDiagnosticCategory.other,
              ),
            ],
          ),
        ],
      );

      server.listen((request) async {
        switch ((request.method, request.uri.path)) {
          case ('GET', '/snapshot'):
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(<String, Object?>{
                'snapshot': CockpitSnapshot(
                  routeName: '/debug',
                  diagnosticLevel: CockpitSnapshotProfile.forensic,
                  diagnosticsArtifactRef: const CockpitArtifactRef(
                    role: 'diagnostics',
                    relativePath: 'diagnostics/remote_snapshot_debug.json',
                  ),
                  summary: const CockpitSnapshotSummary(
                    visibleTargetCount: 1,
                    targetsWithCockpitIdCount: 0,
                    targetsWithTextCount: 1,
                    styleDetailsIncluded: true,
                    diagnosticPropertiesIncluded: true,
                    ancestorSummariesIncluded: true,
                    rebuildSummaryIncluded: false,
                    accessibilitySummaryIncluded: false,
                  ),
                  visibleTargets: <CockpitSnapshotTarget>[
                    CockpitSnapshotTarget(
                      registrationId: 'debug.sync_check',
                      keyValue: 'settings-sync-check-button',
                      text: 'Run check',
                      typeName: 'FilledButton',
                      routeName: '/debug',
                      supportedCommands: <CockpitCommandType>[
                        CockpitCommandType.tap,
                      ],
                    ),
                  ],
                ).toJson(),
                'artifactDownloads': const <Map<String, Object?>>[
                  <String, Object?>{
                    'artifact': <String, Object?>{
                      'role': 'diagnostics',
                      'relativePath': 'diagnostics/remote_snapshot_debug.json',
                    },
                    'downloadPath':
                        '/artifacts/download?path=diagnostics%2Fremote_snapshot_debug.json',
                  },
                ],
              }),
            );
          case ('GET', '/artifacts/download'):
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode(inflatedSnapshot.toJson()));
          default:
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(const <String, Object?>{'error': 'notFound'}),
            );
        }
        await request.response.close();
      });

      final client = CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      final snapshot = await client.readSnapshot(
        options: const CockpitSnapshotOptions.forensic(),
      );

      expect(snapshot.routeName, '/debug');
      expect(
        snapshot.diagnosticsArtifactRef?.relativePath,
        'diagnostics/remote_snapshot_debug.json',
      );
      expect(
        snapshot.visibleTargets.single.diagnosticProperties.single.value.length,
        greaterThan(20000),
      );
    },
  );
}
