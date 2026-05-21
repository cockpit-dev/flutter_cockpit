import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'read bundle summary service expands artifact refs to absolute paths and returns an evidence summary',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      Directory(
        p.join(bundleDir.path, 'screenshots'),
      ).createSync(recursive: true);
      Directory(
        p.join(bundleDir.path, 'recordings'),
      ).createSync(recursive: true);
      Directory(
        p.join(bundleDir.path, 'diagnostics'),
      ).createSync(recursive: true);
      File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytesSync(const <int>[4, 5, 6]);
      File(
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      ).writeAsBytesSync(const <int>[7, 8, 9]);
      File(
        p.join(bundleDir.path, 'diagnostics', 'step_000_snapshot.json'),
      ).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'routeName': '/acceptance',
          'diagnosticLevel': 'forensic',
          'visibleTargets': <Object?>[
            <String, Object?>{
              'registrationId': 'task.save',
              'text': 'Save changes',
              'semanticId': 'Save changes',
              'typeName': 'FilledButton',
              'routeName': '/acceptance',
              'supportedCommands': <String>['tap'],
              'content': <String, Object?>{
                'displayLabel': 'Save changes',
                'textPreview': 'Save changes',
              },
            },
            <String, Object?>{
              'registrationId': 'task.title',
              'text': 'Acceptance bundles',
              'semanticId': 'Acceptance bundles',
              'typeName': 'Text',
              'routeName': '/acceptance',
              'supportedCommands': <String>[],
              'content': <String, Object?>{
                'displayLabel': 'Acceptance bundles',
                'textPreview': 'Acceptance bundles',
              },
            },
          ],
          'accessibility': <String, Object?>{
            'totalAccessibleTargetCount': 2,
            'traversalEntries': <Object?>[
              <String, Object?>{
                'nodeId': 7,
                'label': null,
                'identifier': 'save_button',
                'value': null,
                'hint': 'Submit changes',
                'tooltip': null,
              },
              <String, Object?>{
                'nodeId': 8,
                'label': 'Acceptance bundles',
                'identifier': null,
                'value': null,
                'hint': null,
                'tooltip': null,
              },
            ],
            'truncated': false,
          },
          'summary': <String, Object?>{
            'visibleTargetCount': 2,
            'targetsWithCockpitIdCount': 0,
            'targetsWithTextCount': 2,
            'styleDetailsIncluded': true,
            'diagnosticPropertiesIncluded': true,
            'ancestorSummariesIncluded': true,
            'rebuildSummaryIncluded': true,
            'accessibilitySummaryIncluded': true,
          },
          'network': <String, Object?>{
            'totalEntryCount': 2,
            'failureCount': 1,
            'truncated': false,
            'entries': <Object?>[
              CockpitNetworkEntry(
                requestId: 'net-2',
                method: 'POST',
                uri: 'https://api.example.dev/tasks',
                startedAt: DateTime.utc(2026, 3, 21, 0, 3),
                durationMs: 190,
                statusCode: 500,
                requestBodyPreview: '{"title":"Review bundle"}',
                responseBodyPreview: '{"error":"boom"}',
                error: 'serverError',
              ).toJson(),
              CockpitNetworkEntry(
                requestId: 'net-1',
                method: 'GET',
                uri: 'https://api.example.dev/tasks',
                startedAt: DateTime.utc(2026, 3, 21, 0, 2),
                durationMs: 84,
                statusCode: 200,
              ).toJson(),
            ],
          },
          'runtime': <String, Object?>{
            'totalEntryCount': 2,
            'errorCount': 1,
            'warningCount': 1,
            'capturedEntryCount': 2,
            'truncated': false,
            'entries': <Object?>[
              CockpitRuntimeEvent(
                eventId: 'runtime-2',
                kind: CockpitRuntimeEventKind.uncaughtError,
                severity: CockpitRuntimeEventSeverity.error,
                message: 'Socket closed',
                recordedAt: DateTime.utc(2026, 3, 21, 0, 4),
              ).toJson(),
              CockpitRuntimeEvent(
                eventId: 'runtime-1',
                kind: CockpitRuntimeEventKind.debugLog,
                severity: CockpitRuntimeEventSeverity.info,
                message: 'sync started',
                recordedAt: DateTime.utc(2026, 3, 21, 0, 1),
              ).toJson(),
            ],
          },
          'rebuild': <String, Object?>{
            'totalRebuildCount': 5,
            'uniqueElementCount': 2,
            'capturedEntryCount': 2,
            'truncated': false,
            'entries': <Object?>[
              const CockpitRebuildEntry(
                signature: '/acceptance|FilledButton|sync',
                routeName: '/acceptance',
                typeName: 'FilledButton',
                rebuildCount: 3,
                builtOnceCount: 1,
                keyValue: 'sync',
              ).toJson(),
              const CockpitRebuildEntry(
                signature: '/acceptance|TextField|title',
                routeName: '/acceptance',
                typeName: 'TextField',
                rebuildCount: 2,
                builtOnceCount: 1,
                keyValue: 'title',
              ).toJson(),
            ],
          },
        }),
      );
      File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'bundle-session',
            taskId: 'bundle-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            artifactRefs: <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              CockpitArtifactRef(
                role: 'recording',
                relativePath: 'recordings/acceptance.mp4',
              ),
            ],
            commandCount: 2,
            screenshotCount: 1,
            recordingCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
            runtimeEventCount: 2,
            runtimeErrorCount: 1,
            runtimeWarningCount: 1,
          ).toJson(),
        ),
      );
      File(p.join(bundleDir.path, 'handoff.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'status': 'completed',
          'commandCount': 2,
          'screenshotCount': 1,
          'recordingCount': 1,
        }),
      );
      File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/acceptance.png',
          'attachmentRefs': <String>['screenshots/acceptance.png'],
          'primaryRecordingRef': 'recordings/acceptance.mp4',
          'videoAttachmentRefs': <String>['recordings/acceptance.mp4'],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': true,
        }),
      );
      File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsStringSync('# Acceptance\n\n- Status: completed\n');
      File(p.join(bundleDir.path, 'steps.json')).writeAsStringSync(
        jsonEncode(<Object?>[
          CockpitStepRecord(
            index: 0,
            actionType: 'collectSnapshot',
            actionArgs: const <String, Object?>{},
            observedAt: DateTime.utc(2026, 3, 21, 0, 1),
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/step_000_snapshot.json',
              ),
            ],
            snapshot: CockpitSnapshot(
              routeName: '/acceptance',
              diagnosticLevel: CockpitSnapshotProfile.forensic,
              truncated: true,
              diagnosticsArtifactRef: CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/step_000_snapshot.json',
              ),
            ),
          ).toJson(),
          CockpitStepRecord(
            index: 1,
            actionType: 'runtime_event',
            actionArgs: <String, Object?>{
              'eventId': 'runtime-2',
              'kind': CockpitRuntimeEventKind.uncaughtError.jsonValue,
              'severity': CockpitRuntimeEventSeverity.error.jsonValue,
              'message': 'Socket closed',
              'recordedAt': DateTime.utc(2026, 3, 21, 0, 4).toIso8601String(),
            },
            observedAt: DateTime.utc(2026, 3, 21, 0, 4),
          ).toJson(),
        ]),
      );
      File(p.join(bundleDir.path, 'observations.json')).writeAsStringSync(
        jsonEncode(<Object?>[
          CockpitObservation(
            routeName: '/acceptance',
            diagnosticLevel: CockpitSnapshotProfile.forensic,
            truncated: true,
            diagnosticsArtifactRef: CockpitArtifactRef(
              role: 'diagnostics',
              relativePath: 'diagnostics/step_000_snapshot.json',
            ),
          ).toJson(),
        ]),
      );

      final service = CockpitReadTaskBundleSummaryService();
      final result = await service.read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(result.manifest.status, CockpitTaskStatus.completed);
      expect(
        result.delivery['primaryScreenshotRef'],
        'screenshots/acceptance.png',
      );
      expect(
        result.artifactPaths.primaryScreenshotPath,
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      );
      expect(
        result.artifactPaths.primaryRecordingPath,
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      );
      expect(result.diagnosticsArtifactPaths, <String>[
        p.join(bundleDir.path, 'diagnostics', 'step_000_snapshot.json'),
      ]);
      expect(result.acceptanceEvidence, isNotNull);
      expect(result.acceptanceEvidence!.routeName, '/acceptance');
      expect(result.acceptanceEvidence!.diagnosticLevel, 'forensic');
      expect(result.acceptanceEvidence!.visibleTargetCount, 2);
      expect(result.acceptanceEvidence!.accessibilityEntryCount, 2);
      expect(result.acceptanceEvidence!.hasAccessibilitySummary, isTrue);
      expect(result.acceptanceEvidence!.visibleTextPreviews, <String>[
        'Save changes',
        'Acceptance bundles',
      ]);
      expect(result.acceptanceEvidence!.visibleSemanticIds, <String>[
        'Save changes',
        'Acceptance bundles',
      ]);
      expect(result.acceptanceEvidence!.interactiveLabels, <String>[
        'Save changes',
      ]);
      expect(result.acceptanceEvidence!.accessibilityLabels, <String>[
        'save_button',
        'Acceptance bundles',
      ]);
      expect(result.acceptanceEvidence!.networkEntryCount, 2);
      expect(result.acceptanceEvidence!.networkFailureCount, 1);
      expect(result.acceptanceEvidence!.networkFailureSignals, hasLength(1));
      expect(
        result.acceptanceEvidence!.networkFailureSignals.single.toJson(),
        <String, Object?>{
          'requestId': 'net-2',
          'method': 'POST',
          'uri': 'https://api.example.dev/tasks',
          'statusCode': 500,
          'error': 'serverError',
          'durationMs': 190,
        },
      );
      expect(result.acceptanceEvidence!.runtimeEntryCount, 2);
      expect(result.acceptanceEvidence!.runtimeErrorCount, 1);
      expect(result.acceptanceEvidence!.runtimeWarningCount, 1);
      expect(result.acceptanceEvidence!.runtimeErrorSignals, hasLength(1));
      expect(
        result.acceptanceEvidence!.runtimeErrorSignals.single.toJson(),
        <String, Object?>{
          'eventId': 'runtime-2',
          'kind': 'uncaughtError',
          'severity': 'error',
          'message': 'Socket closed',
        },
      );
      expect(result.acceptanceEvidence!.rebuildTotalCount, 5);
      expect(result.acceptanceEvidence!.rebuildUniqueElementCount, 2);
      expect(result.acceptanceEvidence!.rebuildHotspots, hasLength(2));
      expect(
        result.acceptanceEvidence!.rebuildHotspots.first.toJson(),
        <String, Object?>{
          'signature': '/acceptance|FilledButton|sync',
          'routeName': '/acceptance',
          'typeName': 'FilledButton',
          'rebuildCount': 3,
          'keyValue': 'sync',
          'semanticId': null,
          'textPreview': null,
        },
      );
      expect(result.evidenceSummary['status'], 'completed');
      expect(result.evidenceSummary['commandCount'], 2);
      expect(result.evidenceSummary['screenshotCount'], 1);
      expect(result.evidenceSummary['recordingCount'], 1);
      expect(result.evidenceSummary['failureCount'], 0);
      expect(result.evidenceSummary['keyframeCount'], 0);
      expect(result.evidenceSummary['deliveryKeyframesReady'], isFalse);
      expect(result.evidenceSummary['diagnosticsArtifactCount'], 1);
      expect(result.evidenceSummary['networkEntryCount'], 2);
      expect(result.evidenceSummary['networkFailureCount'], 1);
      expect(result.evidenceSummary['runtimeEventCount'], 2);
      expect(result.evidenceSummary['runtimeErrorCount'], 1);
      expect(result.evidenceSummary['runtimeWarningCount'], 1);
      expect(result.evidenceSummary['rebuildTotalCount'], 5);
      expect(result.evidenceSummary['rebuildUniqueElementCount'], 2);
      expect(result.evidenceSummary['baselineSemanticSignalCount'], 0);
      expect(result.evidenceSummary['acceptanceSemanticSignalCount'], 7);
      expect(result.evidenceSummary['acceptanceAccessibilityEntryCount'], 2);
      expect(result.evidenceSummary['acceptanceInteractiveLabelCount'], 1);
      expect(result.evidenceSummary['acceptanceNetworkFailureCount'], 1);
      expect(result.evidenceSummary['acceptanceRuntimeErrorCount'], 1);
      expect(result.evidenceSummary['acceptanceRebuildHotspotCount'], 2);
      expect(result.evidenceSummary['acceptanceRouteChanged'], isFalse);
      expect(result.evidenceSummary['acceptanceSemanticSignalDeltaCount'], 0);
      expect(result.evidenceSummary['acceptanceNewNetworkFailureCount'], 0);
      expect(result.evidenceSummary['acceptanceNewRuntimeErrorCount'], 0);
      expect(result.evidenceSummary['acceptanceComparisonReady'], isFalse);
      expect(result.gateSummary.isSatisfied(CockpitTaskGate.screenshotReady),
          isTrue);
      expect(
        result.gateSummary
            .isSatisfied(CockpitTaskGate.acceptanceEvidenceReadable),
        isFalse,
      );
      expect(
        result.gateSummary
            .failureCodesFor(CockpitTaskGate.acceptanceEvidenceReadable),
        <String>['baselineEvidenceMissing', 'acceptanceDeltaMissing'],
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.finalAssertionPassed),
        isFalse,
      );
      expect(
        result.gateSummary
            .failureCodesFor(CockpitTaskGate.finalAssertionPassed),
        <String>['runtimeErrorsDetected'],
      );
      expect(result.networkSummary, isNotNull);
      expect(result.networkSummary!.totalEntryCount, 2);
      expect(result.networkSummary!.failureCount, 1);
      expect(result.networkSummary!.recentEntries, hasLength(2));
      expect(result.networkSummary!.recentEntries.first.requestId, 'net-2');
      expect(result.networkSummary!.failingEntries.single.requestId, 'net-2');
      expect(result.runtimeSummary, isNotNull);
      expect(result.runtimeSummary!.totalEntryCount, 2);
      expect(result.runtimeSummary!.errorCount, 1);
      expect(result.runtimeSummary!.recentEntries.first.eventId, 'runtime-2');
      expect(result.toMcpJson()['acceptanceEvidence'], <String, Object?>{
        'routeName': '/acceptance',
        'diagnosticLevel': 'forensic',
        'diagnosticsArtifactPath': p.join(
          bundleDir.path,
          'diagnostics',
          'step_000_snapshot.json',
        ),
        'visibleTextPreviews': <String>['Save changes', 'Acceptance bundles'],
        'visibleSemanticIds': <String>['Save changes', 'Acceptance bundles'],
        'interactiveLabels': <String>['Save changes'],
        'accessibilityLabels': <String>['save_button', 'Acceptance bundles'],
        'visibleTargetCount': 2,
        'accessibilityEntryCount': 2,
        'hasAccessibilitySummary': true,
        'networkEntryCount': 2,
        'networkFailureCount': 1,
        'networkFailureSignals': <Object?>[
          <String, Object?>{
            'requestId': 'net-2',
            'method': 'POST',
            'uri': 'https://api.example.dev/tasks',
            'statusCode': 500,
            'error': 'serverError',
            'durationMs': 190,
          },
        ],
        'runtimeEntryCount': 2,
        'runtimeErrorCount': 1,
        'runtimeWarningCount': 1,
        'runtimeErrorSignals': <Object?>[
          <String, Object?>{
            'eventId': 'runtime-2',
            'kind': 'uncaughtError',
            'severity': 'error',
            'message': 'Socket closed',
          },
        ],
        'rebuildTotalCount': 5,
        'rebuildUniqueElementCount': 2,
        'rebuildHotspots': <Object?>[
          <String, Object?>{
            'signature': '/acceptance|FilledButton|sync',
            'routeName': '/acceptance',
            'typeName': 'FilledButton',
            'rebuildCount': 3,
            'keyValue': 'sync',
            'semanticId': null,
            'textPreview': null,
          },
          <String, Object?>{
            'signature': '/acceptance|TextField|title',
            'routeName': '/acceptance',
            'typeName': 'TextField',
            'rebuildCount': 2,
            'keyValue': 'title',
            'semanticId': null,
            'textPreview': null,
          },
        ],
      });
      expect(result.toMcpJson()['rebuildSummary'], <String, Object?>{
        'totalRebuildCount': 5,
        'uniqueElementCount': 2,
        'truncated': false,
        'entries': <Object?>[
          <String, Object?>{
            'signature': '/acceptance|FilledButton|sync',
            'routeName': '/acceptance',
            'typeName': 'FilledButton',
            'rebuildCount': 3,
            'builtOnceCount': 1,
            'keyValue': 'sync',
            'semanticId': null,
            'textPreview': null,
          },
          <String, Object?>{
            'signature': '/acceptance|TextField|title',
            'routeName': '/acceptance',
            'typeName': 'TextField',
            'rebuildCount': 2,
            'builtOnceCount': 1,
            'keyValue': 'title',
            'semanticId': null,
            'textPreview': null,
          },
        ],
      });
    },
  );

  test(
    'acceptance evidence falls back to target semantics diagnostics when accessibility summary is absent',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service_a11y_fallback',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      Directory(
        p.join(bundleDir.path, 'screenshots'),
      ).createSync(recursive: true);
      Directory(
        p.join(bundleDir.path, 'diagnostics'),
      ).createSync(recursive: true);
      File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytesSync(const <int>[1, 2, 3]);
      File(
        p.join(bundleDir.path, 'diagnostics', 'acceptance_snapshot.json'),
      ).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'routeName': '/settings',
          'diagnosticLevel': 'investigate',
          'visibleTargets': <Object?>[
            <String, Object?>{
              'registrationId': 'settings.back',
              'text': 'Back',
              'typeName': 'IconButton',
              'routeName': '/settings',
              'supportedCommands': <String>['tap'],
              'diagnosticProperties': <Object?>[
                <String, Object?>{
                  'name': 'Semantics Label',
                  'value': 'Back',
                  'category': 'basic',
                },
              ],
            },
            <String, Object?>{
              'registrationId': 'settings.sync',
              'text': 'Run check',
              'typeName': 'FilledButton',
              'routeName': '/settings',
              'supportedCommands': <String>['tap'],
              'diagnosticProperties': <Object?>[
                <String, Object?>{
                  'name': 'Semantics Hint',
                  'value': 'Runs sync health check',
                  'category': 'basic',
                },
                <String, Object?>{
                  'name': 'Semantics Identifier',
                  'value': 'settings_sync_check',
                  'category': 'basic',
                },
              ],
            },
          ],
          'summary': <String, Object?>{
            'visibleTargetCount': 2,
            'targetsWithCockpitIdCount': 0,
            'targetsWithTextCount': 2,
            'styleDetailsIncluded': true,
            'diagnosticPropertiesIncluded': true,
            'ancestorSummariesIncluded': true,
            'rebuildSummaryIncluded': false,
            'accessibilitySummaryIncluded': true,
          },
        }),
      );
      File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'bundle-session',
            taskId: 'bundle-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/acceptance_snapshot.json',
              ),
            ],
            commandCount: 1,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
          ).toJson(),
        ),
      );
      File(
        p.join(bundleDir.path, 'handoff.json'),
      ).writeAsStringSync(jsonEncode(<String, Object?>{'status': 'completed'}));
      File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/acceptance.png',
          'attachmentRefs': <String>['screenshots/acceptance.png'],
          'deliveryArtifactsReady': true,
        }),
      );
      File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsStringSync('# Acceptance\n\n- Status: completed\n');
      File(p.join(bundleDir.path, 'steps.json')).writeAsStringSync(
        jsonEncode(<Object?>[
          CockpitStepRecord(
            index: 0,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: DateTime.utc(2026, 3, 21, 0, 1),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/acceptance_snapshot.json',
              ),
            ],
          ).toJson(),
        ]),
      );

      final result = await const CockpitReadTaskBundleSummaryService().read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(result.acceptanceEvidence, isNotNull);
      expect(result.acceptanceEvidence!.accessibilityLabels, <String>[
        'Back',
        'Runs sync health check',
        'settings_sync_check',
      ]);
      expect(result.acceptanceEvidence!.hasAccessibilitySummary, isTrue);
    },
  );

  test(
    'read bundle summary returns baseline evidence and acceptance delta for AI comparison',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service_delta',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      Directory(
        p.join(bundleDir.path, 'screenshots'),
      ).createSync(recursive: true);
      Directory(
        p.join(bundleDir.path, 'diagnostics'),
      ).createSync(recursive: true);
      File(
        p.join(bundleDir.path, 'screenshots', 'baseline.png'),
      ).writeAsBytesSync(const <int>[1, 2, 3]);
      File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytesSync(const <int>[1, 2, 3]);
      File(
        p.join(bundleDir.path, 'diagnostics', 'baseline_snapshot.json'),
      ).writeAsStringSync(
        jsonEncode(
          _snapshotJsonForDelta(routeName: '/editor', isAcceptance: false),
        ),
      );
      File(
        p.join(bundleDir.path, 'diagnostics', 'acceptance_snapshot.json'),
      ).writeAsStringSync(
        jsonEncode(
          _snapshotJsonForDelta(routeName: '/preview', isAcceptance: true),
        ),
      );
      File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'delta-session',
            taskId: 'delta-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 23, 1, 0),
            finishedAt: DateTime.utc(2026, 3, 23, 1, 2),
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/baseline.png',
              ),
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/baseline_snapshot.json',
              ),
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/acceptance_snapshot.json',
              ),
            ],
            commandCount: 2,
            screenshotCount: 2,
            deliveryArtifactsReady: true,
          ).toJson(),
        ),
      );
      File(
        p.join(bundleDir.path, 'handoff.json'),
      ).writeAsStringSync(jsonEncode(<String, Object?>{'status': 'completed'}));
      File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/acceptance.png',
          'attachmentRefs': <String>[
            'screenshots/baseline.png',
            'screenshots/acceptance.png',
          ],
          'deliveryArtifactsReady': true,
        }),
      );
      File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsStringSync('# Acceptance\n\n- Status: completed\n');
      File(p.join(bundleDir.path, 'steps.json')).writeAsStringSync(
        jsonEncode(<Object?>[
          CockpitStepRecord(
            index: 0,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'baseline_capture',
            },
            observedAt: DateTime.utc(2026, 3, 23, 1, 0, 5),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/baseline_snapshot.json',
              ),
            ],
          ).toJson(),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: DateTime.utc(2026, 3, 23, 1, 1, 0),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'diagnostics',
                relativePath: 'diagnostics/acceptance_snapshot.json',
              ),
            ],
          ).toJson(),
        ]),
      );
      File(p.join(bundleDir.path, 'observations.json')).writeAsStringSync('[]');

      final result = await const CockpitReadTaskBundleSummaryService().read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(result.baselineEvidence, isNotNull);
      expect(result.baselineEvidence!.routeName, '/editor');
      expect(
        result.baselineEvidence!.visibleTextPreviews,
        unorderedEquals(<String>['Draft title', 'Save draft']),
      );
      expect(result.acceptanceEvidence, isNotNull);
      expect(result.acceptanceEvidence!.routeName, '/preview');
      expect(result.acceptanceDelta, isNotNull);
      expect(result.acceptanceDelta!.routeChanged, isTrue);
      expect(
        result.acceptanceDelta!.addedVisibleTextPreviews,
        unorderedEquals(<String>['Published title', 'Share result']),
      );
      expect(
        result.acceptanceDelta!.removedVisibleTextPreviews,
        unorderedEquals(<String>['Draft title', 'Save draft']),
      );
      expect(result.acceptanceDelta!.addedSemanticIds, <String>[
        'publish.share',
      ]);
      expect(result.acceptanceDelta!.removedSemanticIds, <String>[
        'draft.save',
      ]);
      expect(result.acceptanceDelta!.addedInteractiveLabels, <String>[
        'Share result',
      ]);
      expect(result.acceptanceDelta!.removedInteractiveLabels, <String>[
        'Save draft',
      ]);
      expect(result.acceptanceDelta!.addedAccessibilityLabels, <String>[
        'publish.share',
      ]);
      expect(result.acceptanceDelta!.removedAccessibilityLabels, <String>[
        'draft.save',
      ]);
      expect(result.acceptanceDelta!.networkFailureDeltaCount, 1);
      expect(result.acceptanceDelta!.newNetworkFailureSignals, hasLength(1));
      expect(
        result.acceptanceDelta!.newNetworkFailureSignals.single.toJson(),
        <String, Object?>{
          'requestId': 'publish-1',
          'method': 'POST',
          'uri': 'https://api.example.dev/publish',
          'statusCode': 500,
          'error': 'serverError',
          'durationMs': 220,
        },
      );
      expect(result.acceptanceDelta!.runtimeErrorDeltaCount, 1);
      expect(result.acceptanceDelta!.newRuntimeErrorSignals, hasLength(1));
      expect(
        result.acceptanceDelta!.newRuntimeErrorSignals.single.toJson(),
        <String, Object?>{
          'eventId': 'runtime-publish',
          'kind': 'uncaughtError',
          'severity': 'error',
          'message': 'Publish failed',
        },
      );
      expect(result.acceptanceDelta!.rebuildTotalDeltaCount, 4);
      expect(result.acceptanceDelta!.rebuildUniqueElementDeltaCount, 1);
      expect(result.acceptanceDelta!.newRebuildHotspots, hasLength(1));
      expect(
        result.acceptanceDelta!.newRebuildHotspots.single.toJson(),
        <String, Object?>{
          'signature': '/preview|FilledButton|share',
          'routeName': '/preview',
          'typeName': 'FilledButton',
          'rebuildCount': 4,
          'keyValue': 'share',
          'semanticId': null,
          'textPreview': null,
        },
      );
      expect(result.evidenceSummary['baselineSemanticSignalCount'], 5);
      expect(result.evidenceSummary['acceptanceRouteChanged'], isTrue);
      expect(result.evidenceSummary['acceptanceSemanticSignalDeltaCount'], 10);
      expect(result.evidenceSummary['acceptanceNewNetworkFailureCount'], 1);
      expect(result.evidenceSummary['acceptanceNewRuntimeErrorCount'], 1);
      expect(result.evidenceSummary['acceptanceComparisonReady'], isTrue);
      final baselineMcp =
          result.toMcpJson()['baselineEvidence'] as Map<String, Object?>;
      expect(baselineMcp['routeName'], '/editor');
      final acceptanceDeltaMcp =
          result.toMcpJson()['acceptanceDelta'] as Map<String, Object?>;
      expect(acceptanceDeltaMcp['baselineRouteName'], '/editor');
      expect(acceptanceDeltaMcp['acceptanceRouteName'], '/preview');
      expect(acceptanceDeltaMcp['routeChanged'], isTrue);
      expect(
        acceptanceDeltaMcp['addedVisibleTextPreviews'],
        unorderedEquals(<String>['Published title', 'Share result']),
      );
      expect(
        acceptanceDeltaMcp['removedVisibleTextPreviews'],
        unorderedEquals(<String>['Draft title', 'Save draft']),
      );
      expect(acceptanceDeltaMcp['addedSemanticIds'], <String>[
        'publish.share',
      ]);
      expect(acceptanceDeltaMcp['removedSemanticIds'], <String>[
        'draft.save',
      ]);
      expect(acceptanceDeltaMcp['addedInteractiveLabels'], <String>[
        'Share result',
      ]);
      expect(acceptanceDeltaMcp['removedInteractiveLabels'], <String>[
        'Save draft',
      ]);
      expect(acceptanceDeltaMcp['addedAccessibilityLabels'], <String>[
        'publish.share',
      ]);
      expect(acceptanceDeltaMcp['removedAccessibilityLabels'], <String>[
        'draft.save',
      ]);
      expect(acceptanceDeltaMcp['networkFailureDeltaCount'], 1);
      expect(acceptanceDeltaMcp['newNetworkFailureSignals'], <Object?>[
        <String, Object?>{
          'requestId': 'publish-1',
          'method': 'POST',
          'uri': 'https://api.example.dev/publish',
          'statusCode': 500,
          'error': 'serverError',
          'durationMs': 220,
        },
      ]);
      expect(acceptanceDeltaMcp['runtimeErrorDeltaCount'], 1);
      expect(acceptanceDeltaMcp['newRuntimeErrorSignals'], <Object?>[
        <String, Object?>{
          'eventId': 'runtime-publish',
          'kind': 'uncaughtError',
          'severity': 'error',
          'message': 'Publish failed',
        },
      ]);
      expect(acceptanceDeltaMcp['rebuildTotalDeltaCount'], 4);
      expect(acceptanceDeltaMcp['rebuildUniqueElementDeltaCount'], 1);
      expect(acceptanceDeltaMcp['newRebuildHotspots'], <Object?>[
        <String, Object?>{
          'signature': '/preview|FilledButton|share',
          'routeName': '/preview',
          'typeName': 'FilledButton',
          'rebuildCount': 4,
          'keyValue': 'share',
          'semanticId': null,
          'textPreview': null,
        },
      ]);
      expect(acceptanceDeltaMcp['semanticSignalDeltaCount'], 10);
    },
  );

  test(
    'read bundle summary surfaces plane-aware execution fields and gates',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service_plane_aware',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      await bundleDir.create(recursive: true);
      await File(p.join(bundleDir.path, 'manifest.json')).writeAsString(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'bundle-session',
            taskId: 'bundle-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 4, 11, 9, 0),
            finishedAt: DateTime.utc(2026, 4, 11, 9, 1),
            targetKind: CockpitTargetKind.flutterApp,
            primaryExecutionPlane: CockpitPlaneKind.flutterSemanticPlane,
            planesUsed: const <CockpitPlaneKind>[
              CockpitPlaneKind.flutterSemanticPlane,
              CockpitPlaneKind.nativeUiPlane,
            ],
            surfaceKindsUsed: const <CockpitSurfaceKind>[
              CockpitSurfaceKind.flutterSemantic,
              CockpitSurfaceKind.nativeUi,
            ],
            fallbackCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
            runtimeEventCount: 1,
          ).toJson(),
        ),
      );
      await File(p.join(bundleDir.path, 'handoff.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'status': 'completed',
          'targetKind': 'flutterApp',
          'primaryExecutionPlane': 'flutterSemanticPlane',
          'planesUsed': <String>['flutterSemanticPlane', 'nativeUiPlane'],
          'surfaceKindsUsed': <String>['flutterSemantic', 'nativeUi'],
          'fallbackCount': 1,
        }),
      );
      await File(p.join(bundleDir.path, 'delivery.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': true,
        }),
      );
      await File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsString('# Acceptance\n\n- Status: completed\n');
      await File(p.join(bundleDir.path, 'steps.json')).writeAsString(
        jsonEncode(<Object?>[
          CockpitStepRecord(
            index: 0,
            actionType: 'runtime_event',
            actionArgs: <String, Object?>{
              'eventId': 'runtime-1',
              'kind': CockpitRuntimeEventKind.debugLog.jsonValue,
              'severity': CockpitRuntimeEventSeverity.info.jsonValue,
              'message': 'fallback used',
              'recordedAt':
                  DateTime.utc(2026, 4, 11, 9, 0, 30).toIso8601String(),
            },
            observedAt: DateTime.utc(2026, 4, 11, 9, 0, 30),
            targetKind: CockpitTargetKind.flutterApp,
            executionPlane: CockpitPlaneKind.nativeUiPlane,
            surfaceKind: CockpitSurfaceKind.nativeUi,
            usedPlaneFallback: true,
            fallbackTrail: const <CockpitPlaneKind>[
              CockpitPlaneKind.flutterSemanticPlane,
            ],
          ).toJson(),
        ]),
      );

      final service = CockpitReadTaskBundleSummaryService();
      final result = await service.read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(result.manifest.targetKind, CockpitTargetKind.flutterApp);
      expect(
        result.manifest.primaryExecutionPlane,
        CockpitPlaneKind.flutterSemanticPlane,
      );
      expect(result.evidenceSummary['targetKind'], 'flutterApp');
      expect(
        result.evidenceSummary['primaryExecutionPlane'],
        'flutterSemanticPlane',
      );
      expect(result.evidenceSummary['planesUsed'], <String>[
        'flutterSemanticPlane',
        'nativeUiPlane',
      ]);
      expect(result.evidenceSummary['surfaceKindsUsed'], <String>[
        'flutterSemantic',
        'nativeUi',
      ]);
      expect(result.evidenceSummary['fallbackCount'], 1);
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.targetReachable),
        isTrue,
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.intendedPlaneWorked),
        isFalse,
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.fallbackAcceptable),
        isTrue,
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.logsCollected),
        isTrue,
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.deliveryReadable),
        isTrue,
      );
    },
  );

  test(
    'read bundle summary rejects delivery readiness when referenced files are missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service_missing_delivery_files',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      await Directory(p.join(bundleDir.path, 'screenshots')).create(
        recursive: true,
      );
      await Directory(p.join(bundleDir.path, 'recordings')).create(
        recursive: true,
      );
      await File(p.join(bundleDir.path, 'manifest.json')).writeAsString(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'bundle-session',
            taskId: 'bundle-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 4, 12, 9, 0),
            finishedAt: DateTime.utc(2026, 4, 12, 9, 1),
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/missing_acceptance.png',
              ),
              CockpitArtifactRef(
                role: 'recording',
                relativePath: 'recordings/missing_acceptance.mp4',
              ),
            ],
            commandCount: 1,
            screenshotCount: 1,
            recordingCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
          ).toJson(),
        ),
      );
      await File(p.join(bundleDir.path, 'handoff.json')).writeAsString(
        jsonEncode(<String, Object?>{'status': 'completed'}),
      );
      await File(p.join(bundleDir.path, 'delivery.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/missing_acceptance.png',
          'attachmentRefs': <String>['screenshots/missing_acceptance.png'],
          'primaryRecordingRef': 'recordings/missing_acceptance.mp4',
          'videoAttachmentRefs': <String>['recordings/missing_acceptance.mp4'],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': true,
        }),
      );
      await File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsString('# Acceptance\n\n- Status: completed\n');
      await File(p.join(bundleDir.path, 'steps.json')).writeAsString('[]');

      final service = CockpitReadTaskBundleSummaryService();
      final result = await service.read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.screenshotReady),
        isFalse,
      );
      expect(
        result.gateSummary.failureCodesFor(CockpitTaskGate.screenshotReady),
        <String>['acceptanceScreenshotMissing'],
      );
      expect(
        result.gateSummary
            .isSatisfied(CockpitTaskGate.recordingReadyOrExplained),
        isFalse,
      );
      expect(
        result.gateSummary
            .failureCodesFor(CockpitTaskGate.recordingReadyOrExplained),
        <String>['acceptanceRecordingMissing'],
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.artifactsReady),
        isFalse,
      );
      expect(
        result.gateSummary.isSatisfied(CockpitTaskGate.deliveryValidated),
        isFalse,
      );
      expect(
        result.evidenceSummary['deliveryValidated'],
        isFalse,
      );
      expect(
        result.evidenceSummary['artifactFailureCodes'],
        containsAll(<String>[
          'acceptanceScreenshotMissing',
          'acceptanceRecordingMissing',
        ]),
      );
    },
  );

  test(
    'read bundle summary ignores keyframe refs that are not bundle-local files',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_task_bundle_summary_service_escaped_keyframes',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      await Directory(p.join(bundleDir.path, 'screenshots')).create(
        recursive: true,
      );
      await Directory(p.join(bundleDir.path, 'recordings')).create(
        recursive: true,
      );
      await Directory(p.join(bundleDir.path, 'keyframes')).create(
        recursive: true,
      );
      await File(
        p.join(bundleDir.path, 'screenshots', 'acceptance.png'),
      ).writeAsBytes(const <int>[1, 2, 3]);
      await File(
        p.join(bundleDir.path, 'recordings', 'acceptance.mp4'),
      ).writeAsBytes(const <int>[4, 5, 6]);
      await File(
        p.join(bundleDir.path, 'keyframes', 'acceptance_tail.png'),
      ).writeAsBytes(const <int>[7, 8, 9]);
      await File(p.join(bundleDir.path, 'manifest.json')).writeAsString(
        jsonEncode(
          CockpitRunManifest(
            sessionId: 'bundle-session',
            taskId: 'bundle-task',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 4, 12, 10, 0),
            finishedAt: DateTime.utc(2026, 4, 12, 10, 1),
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              CockpitArtifactRef(
                role: 'recording',
                relativePath: 'recordings/acceptance.mp4',
              ),
            ],
            commandCount: 1,
            screenshotCount: 1,
            recordingCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
          ).toJson(),
        ),
      );
      await File(p.join(bundleDir.path, 'handoff.json')).writeAsString(
        jsonEncode(<String, Object?>{'status': 'completed'}),
      );
      await File(p.join(bundleDir.path, 'delivery.json')).writeAsString(
        jsonEncode(<String, Object?>{
          'primaryScreenshotRef': 'screenshots/acceptance.png',
          'primaryRecordingRef': 'recordings/acceptance.mp4',
          'keyframes': <Map<String, Object?>>[
            <String, Object?>{
              'ref': '../escaped_tail.png',
              'label': 'tail_consistency',
              'offsetMs': 700,
              'source': 'tailConsistency',
            },
            <String, Object?>{
              'ref': 'keyframes/acceptance_tail.png',
              'label': 'acceptance',
              'offsetMs': 700,
              'source': 'stepCapture',
            },
          ],
          'keyframeCoverage': <String, Object?>{
            'durationMs': 900,
            'hasEarlyCoverage': true,
            'hasMidCoverage': true,
            'hasLateCoverage': true,
            'isReady': true,
          },
        }),
      );
      await File(
        p.join(bundleDir.path, 'acceptance.md'),
      ).writeAsString('# Acceptance\n\n- Status: completed\n');
      await File(p.join(bundleDir.path, 'steps.json')).writeAsString('[]');

      final service = CockpitReadTaskBundleSummaryService();
      final result = await service.read(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir.path),
      );

      expect(result.artifactPaths.keyframePaths, <String>[
        p.join(bundleDir.path, 'keyframes', 'acceptance_tail.png'),
      ]);
      expect(
        result.evidence.keyframes.map((keyframe) => keyframe.ref),
        <String>['keyframes/acceptance_tail.png'],
      );
      expect(
        result.evidence.keyframes.single.path,
        p.join(bundleDir.path, 'keyframes', 'acceptance_tail.png'),
      );
    },
  );
}

Map<String, Object?> _snapshotJsonForDelta({
  required String routeName,
  required bool isAcceptance,
}) {
  final networkEntries = isAcceptance
      ? <Map<String, Object?>>[
          <String, Object?>{
            'requestId': 'publish-1',
            'method': 'POST',
            'uri': 'https://api.example.dev/publish',
            'statusCode': 500,
            'error': 'serverError',
            'durationMs': 220,
            'startedAt': DateTime.utc(2026, 3, 23, 1, 1, 0).toIso8601String(),
            'finishedAt': DateTime.utc(2026, 3, 23, 1, 1, 1).toIso8601String(),
          },
        ]
      : <Map<String, Object?>>[];
  final runtimeEntries = isAcceptance
      ? <Map<String, Object?>>[
          <String, Object?>{
            'eventId': 'runtime-publish',
            'kind': 'uncaughtError',
            'severity': 'error',
            'message': 'Publish failed',
            'recordedAt': DateTime.utc(2026, 3, 23, 1, 1, 2).toIso8601String(),
          },
        ]
      : <Map<String, Object?>>[];
  final rebuildEntries = isAcceptance
      ? <Map<String, Object?>>[
          <String, Object?>{
            'signature': '/preview|FilledButton|share',
            'routeName': '/preview',
            'typeName': 'FilledButton',
            'rebuildCount': 4,
            'builtOnceCount': 1,
            'keyValue': 'share',
          },
        ]
      : <Map<String, Object?>>[];

  return <String, Object?>{
    'routeName': routeName,
    'diagnosticLevel': 'investigate',
    'visibleTargets': isAcceptance
        ? <Object?>[
            <String, Object?>{
              'registrationId': 'share',
              'text': 'Share result',
              'semanticId': 'publish.share',
              'typeName': 'FilledButton',
              'routeName': routeName,
              'supportedCommands': <String>['tap'],
              'diagnosticProperties': <Object?>[
                <String, Object?>{
                  'name': 'Semantics Identifier',
                  'value': 'publish.share',
                  'category': 'basic',
                },
              ],
            },
            <String, Object?>{
              'registrationId': 'published-title',
              'text': 'Published title',
              'typeName': 'RichText',
              'routeName': routeName,
              'supportedCommands': <String>[],
              'diagnosticProperties': <Object?>[],
            },
          ]
        : <Object?>[
            <String, Object?>{
              'registrationId': 'save',
              'text': 'Save draft',
              'semanticId': 'draft.save',
              'typeName': 'FilledButton',
              'routeName': routeName,
              'supportedCommands': <String>['tap'],
              'diagnosticProperties': <Object?>[
                <String, Object?>{
                  'name': 'Semantics Identifier',
                  'value': 'draft.save',
                  'category': 'basic',
                },
              ],
            },
            <String, Object?>{
              'registrationId': 'draft-title',
              'text': 'Draft title',
              'typeName': 'RichText',
              'routeName': routeName,
              'supportedCommands': <String>[],
              'diagnosticProperties': <Object?>[],
            },
          ],
    'summary': <String, Object?>{
      'visibleTargetCount': 2,
      'targetsWithCockpitIdCount': 0,
      'targetsWithTextCount': 2,
      'styleDetailsIncluded': true,
      'diagnosticPropertiesIncluded': true,
      'ancestorSummariesIncluded': false,
      'rebuildSummaryIncluded': true,
      'accessibilitySummaryIncluded': true,
    },
    'network': <String, Object?>{
      'totalEntryCount': networkEntries.length,
      'failureCount': isAcceptance ? 1 : 0,
      'capturedEntryCount': networkEntries.length,
      'truncated': false,
      'entries': networkEntries,
      'query': const <String, Object?>{'onlyFailures': true},
    },
    'runtime': <String, Object?>{
      'totalEntryCount': runtimeEntries.length,
      'errorCount': isAcceptance ? 1 : 0,
      'warningCount': 0,
      'capturedEntryCount': runtimeEntries.length,
      'truncated': false,
      'entries': runtimeEntries,
      'query': const <String, Object?>{'onlyErrors': true},
    },
    'rebuild': <String, Object?>{
      'totalRebuildCount': isAcceptance ? 4 : 0,
      'uniqueElementCount': isAcceptance ? 1 : 0,
      'truncated': false,
      'entries': rebuildEntries,
    },
    'accessibility': <String, Object?>{
      'totalAccessibleTargetCount': 1,
      'traversalEntries': <Object?>[
        <String, Object?>{
          'nodeId': isAcceptance ? 2 : 1,
          'label': isAcceptance ? 'publish.share' : 'draft.save',
        },
      ],
    },
  };
}
