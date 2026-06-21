import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/artifacts/cockpit_timeline_video_fallback_builder.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('writes the standard task-run directory structure', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-001',
        taskId: 'task-login',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 5),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
    );

    expect(p.basename(outputDir.path), '20260320T080000000000Z_session-001');
    expect(File(p.join(outputDir.path, 'manifest.json')).existsSync(), isTrue);
    expect(
      File(p.join(outputDir.path, 'environment.json')).existsSync(),
      isTrue,
    );
    expect(File(p.join(outputDir.path, 'steps.json')).existsSync(), isTrue);
    expect(File(p.join(outputDir.path, 'trace.json')).existsSync(), isTrue);
    expect(File(p.join(outputDir.path, 'logs.json')).existsSync(), isTrue);
    expect(
      Directory(p.join(outputDir.path, 'screenshots')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(outputDir.path, 'recordings')).existsSync(),
      isTrue,
    );
  });

  test(
    'writes workflow trace entries linked to steps, commands, and artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_trace_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-trace',
          taskId: 'task-trace',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 6, 15, 8),
          finishedAt: DateTime.utc(2026, 6, 15, 8, 1),
          artifactRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/after.png',
            ),
          ],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'workflow_if',
            actionArgs: const <String, Object?>{
              'workflowStepId': 'dismiss-dialog-if-present',
              'workflowStepType': 'if',
              'workflowStepDescription': 'Dismiss optional dialog.',
              'conditionCommandId': 'has-dialog',
              'conditionSuccess': false,
              'selectedBranch': 'else',
            },
            observedAt: DateTime.utc(2026, 6, 15, 8),
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'tap',
            actionArgs: const <String, Object?>{
              'commandId': 'tap-continue',
              'workflowStepId': 'continue-flow',
              'workflowStepType': 'command',
              'workflowStepDescription': 'Continue the main flow.',
            },
            observedAt: DateTime.utc(2026, 6, 15, 8, 0, 1),
            commandType: CockpitCommandType.tap,
            status: CockpitCommandStatus.succeeded,
            artifactRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/after.png',
              ),
            ],
            captureRefs: const <CockpitArtifactRef>[
              CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/after.png',
              ),
            ],
          ),
        ],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nDone.',
        handoff: const {'status': 'completed'},
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: const <String, List<int>>{
          'screenshots/after.png': <int>[1, 2, 3],
        },
      );

      final trace =
          jsonDecode(
                File(p.join(outputDir.path, 'trace.json')).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(trace['schemaVersion'], 1);
      expect(trace['entryCount'], 2);
      final entries = (trace['entries']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(entries.first['workflowStepId'], 'dismiss-dialog-if-present');
      expect(entries.first['description'], 'Dismiss optional dialog.');
      expect(entries.first['conditionCommandId'], 'has-dialog');
      expect(entries.first['selectedBranch'], 'else');
      expect(entries.last['stepIndex'], 1);
      expect(entries.last['workflowStepId'], 'continue-flow');
      expect(entries.last['description'], 'Continue the main flow.');
      expect(entries.last['commandId'], 'tap-continue');
      expect(entries.last['captureRefs'], isNotEmpty);
    },
  );

  test('writes structured logs derived from runtime event evidence', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_logs_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-logs',
        taskId: 'task-logs',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 5),
        artifactRefs: const [],
        runtimeEventCount: 2,
        runtimeErrorCount: 1,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: [
        CockpitStepRecord(
          index: 0,
          actionType: 'runtime_event',
          actionArgs: const <String, Object?>{
            'eventId': 'evt-error-1',
            'kind': 'flutterError',
            'severity': 'error',
            'message': 'Render overflow detected',
            'recordedAt': '2026-03-20T08:02:00.000Z',
          },
          observedAt: DateTime.utc(2026, 3, 20, 8, 2),
        ),
        CockpitStepRecord(
          index: 1,
          actionType: 'runtime_event',
          actionArgs: const <String, Object?>{
            'eventId': 'evt-log-1',
            'kind': 'debugLog',
            'severity': 'info',
            'message': 'Checkout completed',
            'recordedAt': '2026-03-20T08:01:00.000Z',
          },
          observedAt: DateTime.utc(2026, 3, 20, 8, 1),
        ),
      ],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
    );

    final logsFile = File(p.join(outputDir.path, 'logs.json'));
    expect(logsFile.existsSync(), isTrue);
    final logs =
        jsonDecode(logsFile.readAsStringSync()) as Map<String, Object?>;
    expect(logs['sessionId'], 'session-logs');
    expect(logs['runtimeEventCount'], 2);
    expect(logs['runtimeErrorCount'], 1);
    expect(logs['entryCount'], 2);
    final entries = (logs['entries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(entries, hasLength(2));
    expect(entries.first['message'], 'Checkout completed');
    expect(entries.last['message'], 'Render overflow detected');
    expect(entries.last['source'], 'runtime');
    expect(entries.last['severity'], 'error');
  });

  test('task-run directory names sort lexically by start time', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_sortable_name_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    Future<String> writeStartedAt(DateTime startedAt, String sessionId) async {
      final outputDir = await writer.writeBundle(
        bundle: CockpitContextBundle(
          manifest: CockpitRunManifest(
            sessionId: sessionId,
            taskId: 'task-sortable-name',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: startedAt,
            finishedAt: startedAt.add(const Duration(seconds: 1)),
            artifactRefs: const [],
          ),
          environment: const CockpitEnvironment(
            platform: 'android',
            flutterVersion: '3.32.0',
            dartVersion: '3.8.0',
          ),
          steps: const [],
          observations: const [],
          acceptanceMarkdown: '# Acceptance\n\nDone.',
          handoff: const {'status': 'completed'},
        ),
        outputRoot: tempDir.path,
      );
      return p.basename(outputDir.path);
    }

    final names = <String>[
      await writeStartedAt(DateTime.utc(2026, 3, 20, 8, 0, 0, 0, 1), 'late'),
      await writeStartedAt(DateTime.utc(2026, 3, 20, 8), 'first'),
      await writeStartedAt(DateTime.utc(2026, 3, 20, 8, 0, 1), 'last'),
    ];

    expect(names.toList()..sort(), <String>[
      '20260320T080000000000Z_first',
      '20260320T080000000001Z_late',
      '20260320T080001000000Z_last',
    ]);
  });

  test('writes expected manifest, handoff, and acceptance content', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-002',
        taskId: 'task-signup',
        platform: 'ios',
        status: CockpitTaskStatus.failed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 6),
        artifactRefs: const [],
        failureSummary: 'Missing snackbar.',
      ),
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nNeeds follow-up.',
      handoff: const {'status': 'failed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
    );
    final manifestJson =
        jsonDecode(
              await File(
                p.join(outputDir.path, 'manifest.json'),
              ).readAsString(),
            )
            as Map<String, Object?>;
    final handoffJson =
        jsonDecode(
              await File(p.join(outputDir.path, 'handoff.json')).readAsString(),
            )
            as Map<String, Object?>;
    final acceptance = await File(
      p.join(outputDir.path, 'acceptance.md'),
    ).readAsString();

    expect(manifestJson['taskId'], 'task-signup');
    expect(handoffJson['status'], 'failed');
    expect(acceptance, contains('# Acceptance'));
  });

  test('writes issue evidence for failed task bundles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_issue_evidence_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-issue',
        taskId: 'task-issue',
        platform: 'macos',
        status: CockpitTaskStatus.failed,
        startedAt: DateTime.utc(2026, 5, 30, 8),
        finishedAt: DateTime.utc(2026, 5, 30, 8, 1),
        failureSummary: 'Expected route /editor was not reached.',
        commandCount: 1,
        failureCount: 1,
      ),
      environment: const CockpitEnvironment(
        platform: 'macos',
        flutterVersion: '3.32.0',
        dartVersion: '3.8.0',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'tap',
          actionArgs: const <String, Object?>{
            'commandId': 'open-editor',
            'expectedRouteName': '/editor',
          },
          observedAt: DateTime.utc(2026, 5, 30, 8),
          commandType: CockpitCommandType.tap,
          status: CockpitCommandStatus.failed,
          commandError: CockpitCommandError.timeout(
            message: 'Expected route /editor was not reached.',
            details: const <String, Object?>{
              'failureDiagnostics': <String, Object?>{
                'schemaVersion': 1,
                'commandId': 'open-editor',
                'routeName': '/inbox',
                'expectedRouteName': '/editor',
                'routeChanged': false,
              },
            },
          ),
        ),
      ],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nNeeds follow-up.',
      handoff: const <String, Object?>{
        'status': 'failed',
        'failureSummary': 'Expected route /editor was not reached.',
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactPayloads: const <String, List<int>>{
        'screenshots/acceptance.png': <int>[137, 80, 78, 71],
      },
    );

    final issueFile = File(p.join(outputDir.path, 'issue_evidence.json'));
    expect(issueFile.existsSync(), isTrue);
    final issueEvidence =
        jsonDecode(await issueFile.readAsString()) as Map<String, Object?>;
    expect(issueEvidence['schemaVersion'], 1);
    expect(issueEvidence['status'], 'failed');
    expect(issueEvidence['recommendedNextStep'], 'inspect_issue_evidence');
    final failedCommands = issueEvidence['failedCommands'] as List<Object?>;
    expect(failedCommands, hasLength(1));
    expect(failedCommands.single, containsPair('commandId', 'open-editor'));
  });

  test('writes issue evidence for derived delivery gate failures', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_derived_gate_issue_evidence_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-derived-gate',
        taskId: 'task-derived-gate',
        platform: 'macos',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 5, 30, 8),
        finishedAt: DateTime.utc(2026, 5, 30, 8, 1),
        artifactRefs: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/acceptance.png',
          ),
        ],
        commandCount: 1,
        screenshotCount: 1,
        deliveryArtifactsReady: true,
        recordingCount: 0,
        deliveryVideoReady: false,
      ),
      environment: const CockpitEnvironment(
        platform: 'macos',
        flutterVersion: '3.32.0',
        dartVersion: '3.8.0',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'recording_start_requested',
          actionArgs: const <String, Object?>{'recordingPurpose': 'acceptance'},
          observedAt: DateTime.utc(2026, 5, 30, 8),
        ),
      ],
      observations: const [],
      acceptanceMarkdown:
          '# Acceptance\n\nScreenshot captured; recording requested.',
      handoff: const <String, Object?>{'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryScreenshotRef': 'screenshots/acceptance.png',
        'attachmentRefs': ['screenshots/acceptance.png'],
        'deliveryArtifactsReady': true,
        'deliveryVideoReady': false,
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactPayloads: const <String, List<int>>{
        'screenshots/acceptance.png': <int>[137, 80, 78, 71],
      },
    );

    final issueFile = File(p.join(outputDir.path, 'issue_evidence.json'));
    final issueEvidence =
        jsonDecode(await issueFile.readAsString()) as Map<String, Object?>;

    expect(issueEvidence['status'], 'completed');
    expect(issueEvidence['recommendedNextStep'], 'inspect_issue_evidence');
    expect(issueEvidence['issueKinds'], contains('gateFailure'));
    final gateFailures = issueEvidence['gateFailures'] as List<Object?>;
    expect(
      gateFailures,
      contains(
        allOf(
          isA<Map<String, Object?>>(),
          containsPair('gate', 'recordingReadyOrExplained'),
          containsPair('failureCodes', <String>['primaryRecordingMissing']),
        ),
      ),
    );
  });

  test(
    'uses a file-system-safe single directory for unsafe session ids',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_safe_name_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: '../team/session:ios 17',
          taskId: 'task-safe-name',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
          artifactRefs: const [],
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const [],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nDone.',
        handoff: const {'status': 'completed'},
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
      );

      expect(p.isWithin(tempDir.path, outputDir.path), isTrue);
      expect(p.dirname(outputDir.path), tempDir.path);
      expect(p.basename(outputDir.path), contains('team_session_ios_17'));
      expect(
        p.basename(outputDir.path),
        isNot(
          anyOf(contains('/'), contains('..'), contains(' '), contains(':')),
        ),
      );
      expect(
        File(p.join(outputDir.path, 'manifest.json')).existsSync(),
        isTrue,
      );
    },
  );

  test('writes binary artifact payloads into the bundle output', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final artifact = const CockpitArtifactRef(
      role: 'screenshot',
      relativePath: 'screenshots/home_acceptance.png',
    );
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-003',
        taskId: 'task-capture',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
        artifactRefs: [artifact],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactPayloads: <String, List<int>>{
        artifact.relativePath: <int>[137, 80, 78, 71],
      },
    );

    expect(
      File(p.join(outputDir.path, artifact.relativePath)).readAsBytesSync(),
      <int>[137, 80, 78, 71],
    );
  });

  test('rejects artifact payload paths that escape the bundle', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_escape_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-escape',
        taskId: 'task-escape',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    await expectLater(
      writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: const <String, List<int>>{
          '../outside.png': <int>[137, 80, 78, 71],
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Artifact path must stay inside the task-run bundle'),
        ),
      ),
    );

    expect(File(p.join(tempDir.path, 'outside.png')).existsSync(), isFalse);
  });

  test(
    'rejects manifest artifact refs outside their expected evidence directory',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_invalid_manifest_ref',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-invalid-manifest-ref',
          taskId: 'task-invalid-manifest-ref',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
          artifactRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'recordings/not_a_screenshot.mp4',
            ),
          ],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const <CockpitStepRecord>[],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nDone.',
        handoff: const <String, Object?>{'status': 'completed'},
      );

      await expectLater(
        writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains(
              'Manifest artifact refs must stay under their expected evidence directory.',
            ),
          ),
        ),
      );
    },
  );

  test(
    'rejects manifest artifact refs that are missing from the bundle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_missing_manifest_artifact',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-missing-manifest-artifact',
          taskId: 'task-missing-manifest-artifact',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
          artifactRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/missing_acceptance.png',
            ),
          ],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const <CockpitStepRecord>[],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nDone.',
        handoff: const <String, Object?>{'status': 'completed'},
      );

      await expectLater(
        writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Manifest artifact file does not exist'),
          ),
        ),
      );
    },
  );

  test(
    'writes delivery.json with bundle-local screenshot references',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final artifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-004',
          taskId: 'task-delivery',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 2),
          artifactRefs: [artifact],
          nativeScreenshotCount: 1,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const [],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nDelivered.',
        handoff: const {'status': 'completed'},
        delivery: const <String, Object?>{
          'summary': 'Ready for user delivery',
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': ['screenshots/home_acceptance.png'],
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          artifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;

      expect(deliveryJson['primaryScreenshotRef'], artifact.relativePath);
      expect((deliveryJson['attachmentRefs'] as List<Object?>).cast<String>(), [
        artifact.relativePath,
      ]);
    },
  );

  test(
    'rejects delivery screenshot refs that are missing from the bundle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_missing_delivery_artifact',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-missing-delivery-artifact',
          taskId: 'task-missing-delivery-artifact',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 2),
          artifactRefs: const <CockpitArtifactRef>[],
          nativeScreenshotCount: 1,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const <CockpitStepRecord>[],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nDelivered.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'summary': 'Ready for user delivery',
          'primaryScreenshotRef': 'screenshots/missing_acceptance.png',
          'attachmentRefs': <String>['screenshots/missing_acceptance.png'],
          'deliveryArtifactsReady': true,
        },
      );

      await expectLater(
        writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Delivery artifact file does not exist'),
          ),
        ),
      );
    },
  );

  test('rejects delivery keyframe refs outside keyframe artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_invalid_keyframe_ref',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter(
      keyframeExtractor: const _InvalidKeyframeExtractor(
        keyframeRef: 'screenshots/not_a_keyframe.png',
      ),
    );
    final recordingArtifact = const CockpitArtifactRef(
      role: 'recording',
      relativePath: 'recordings/home_acceptance.mp4',
    );
    final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
    await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
    final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-invalid-keyframe-ref',
        taskId: 'task-invalid-keyframe-ref',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(seconds: 2)),
        artifactRefs: <CockpitArtifactRef>[recordingArtifact],
        recordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'recording_started',
          actionArgs: const <String, Object?>{'recordingPurpose': 'acceptance'},
          observedAt: startedAt,
        ),
      ],
      observations: const <CockpitObservation>[],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const <String, Object?>{'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': <String>['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    await expectLater(
      writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: sourceFile.path,
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Delivery keyframe refs must stay under keyframes/'),
        ),
      ),
    );
  });

  test(
    'rejects delivery keyframe linked screenshot refs outside screenshot artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_invalid_keyframe_linked_screenshot',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: const _InvalidKeyframeExtractor(
          linkedScreenshotRef: 'recordings/not_a_screenshot.mp4',
        ),
      );
      final recordingArtifact = const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/home_acceptance.mp4',
      );
      final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
      await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-invalid-keyframe-link',
          taskId: 'task-invalid-keyframe-link',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(seconds: 2)),
          artifactRefs: <CockpitArtifactRef>[recordingArtifact],
          recordingCount: 1,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
            },
            observedAt: startedAt,
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryRecordingRef': 'recordings/home_acceptance.mp4',
          'videoAttachmentRefs': <String>['recordings/home_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      await expectLater(
        writer.writeBundle(
          bundle: bundle,
          outputRoot: tempDir.path,
          artifactSourcePaths: <String, String>{
            recordingArtifact.relativePath: sourceFile.path,
          },
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains(
              'Delivery keyframe linked screenshot refs must stay under screenshots/',
            ),
          ),
        ),
      );
    },
  );

  test(
    'rejects delivery screenshot refs outside screenshot artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_invalid_delivery_ref',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-invalid-delivery',
          taskId: 'task-invalid-delivery',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 2),
          artifactRefs: const <CockpitArtifactRef>[],
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const <CockpitStepRecord>[],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nDelivered.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'recordings/not_a_screenshot.mp4',
          'attachmentRefs': <String>['../outside.png'],
          'deliveryArtifactsReady': true,
        },
      );

      await expectLater(
        writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Delivery screenshot refs must stay under screenshots/'),
          ),
        ),
      );
    },
  );

  test('rejects delivery recording refs outside recording artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_invalid_delivery_recording_ref',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-invalid-delivery-recording',
        taskId: 'task-invalid-delivery-recording',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 2),
        artifactRefs: const <CockpitArtifactRef>[],
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const <CockpitStepRecord>[],
      observations: const <CockpitObservation>[],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const <String, Object?>{'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'screenshots/not_a_recording.png',
        'videoAttachmentRefs': <String>['../outside.mp4'],
        'deliveryVideoReady': true,
      },
    );

    await expectLater(
      writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Delivery recording refs must stay under recordings/'),
        ),
      ),
    );
  });

  test('copies recording source files into the bundle output', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final artifact = const CockpitArtifactRef(
      role: 'recording',
      relativePath: 'recordings/home_acceptance.mp4',
    );
    final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
    await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);

    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-005',
        taskId: 'task-video',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 3),
        artifactRefs: [artifact],
        recordingCount: 1,
        nativeRecordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const {'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );

    expect(
      File(p.join(outputDir.path, artifact.relativePath)).readAsBytesSync(),
      <int>[0, 1, 2, 3, 4],
    );
  });

  test(
    'synthesizes a fallback delivery video when recording failed but screenshots exist',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_fallback_video',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _FakeRecordingKeyframeExtractor(),
        timelineVideoFallbackBuilder: _FakeTimelineVideoFallbackBuilder(
          sourceRoot: tempDir.path,
          durationMs: 2400,
        ),
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 23, 2, 0, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-fallback-video',
          taskId: 'task-fallback-video',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(seconds: 4)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
          ],
          screenshotCount: 2,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_start_requested',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 200)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 1800)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_failed',
            actionArgs: const <String, Object?>{
              'failureReason': 'simctl recording output did not finalize.',
            },
            observedAt: startedAt.add(const Duration(seconds: 4)),
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': false,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final manifestJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'manifest.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      final handoffJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'handoff.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;

      expect(manifestJson['deliveryVideoReady'], isTrue);
      expect(manifestJson['recordingCount'], 1);
      expect(manifestJson['deliveryVideoFailureCodes'], isEmpty);
      expect(deliveryJson['deliveryVideoReady'], isTrue);
      expect(deliveryJson['deliveryVideoSynthesized'], isTrue);
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
            as Map<Object?, Object?>)['ready'],
        isTrue,
      );
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
            as Map<Object?, Object?>)['failureCodes'],
        isEmpty,
      );
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
                as Map<Object?, Object?>)
            .containsKey('failureReason'),
        isFalse,
      );
      expect(
        deliveryJson['primaryRecordingRef'],
        'recordings/task-fallback-video_session-fallback-video_timeline_fallback.mp4',
      );
      expect(
        File(
          p.join(
            outputDir.path,
            deliveryJson['primaryRecordingRef']! as String,
          ),
        ).readAsBytesSync(),
        <int>[0, 1, 2, 3],
      );
      expect(handoffJson['deliveryVideoSynthesized'], isTrue);
      expect(
        ((handoffJson['gates']
            as Map<Object?, Object?>)['recordingReadyOrExplained']),
        isTrue,
      );
      expect(
        ((handoffJson['gateFailureCodes']
            as Map<Object?, Object?>)['recordingReadyOrExplained']),
        isEmpty,
      );
    },
  );

  test(
    'adds a midpoint keyframe when a synthesized fallback video only has early and late screenshot evidence',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_fallback_midpoint',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _SparseRecordingKeyframeExtractor(),
        timelineVideoFallbackBuilder: _FakeTimelineVideoFallbackBuilder(
          sourceRoot: tempDir.path,
          durationMs: 3125,
        ),
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 23, 2, 30, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-fallback-midpoint',
          taskId: 'task-fallback-midpoint',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 3125)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
          ],
          screenshotCount: 2,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_start_requested',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 446)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 2525)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_failed',
            actionArgs: const <String, Object?>{
              'failureReason': 'simctl recording output did not finalize.',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 3125)),
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': false,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();

      expect(deliveryJson['deliveryVideoSynthesized'], isTrue);
      expect(deliveryJson['deliveryKeyframesReady'], isTrue);
      expect(deliveryJson['keyframeCoverage'], <String, Object?>{
        'durationMs': 3269,
        'hasEarlyCoverage': true,
        'hasMidCoverage': true,
        'hasLateCoverage': true,
        'isReady': true,
      });
      expect(
        keyframes.map((keyframe) => keyframe['label']),
        containsAll(<Object?>['baseline', 'midpoint', 'tail_consistency']),
      );
      expect(
        keyframes.map((keyframe) => keyframe['ref'] as String).toList()..sort(),
        keyframes.map((keyframe) => keyframe['ref'] as String).toList(),
      );
      final midpoint = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'midpoint',
      );
      expect(midpoint['linkedScreenshotRef'], acceptanceArtifact.relativePath);
      expect(
        File(p.join(outputDir.path, midpoint['ref']! as String)).existsSync(),
        isTrue,
      );
    },
  );

  test('writes extracted recording keyframes into delivery metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter(
      keyframeExtractor: _FakeRecordingKeyframeExtractor(),
    );
    final artifact = const CockpitArtifactRef(
      role: 'recording',
      relativePath: 'recordings/home_acceptance.mp4',
    );
    final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
    await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
    final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);

    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-005b',
        taskId: 'task-video-keyframes',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(seconds: 8)),
        artifactRefs: [artifact],
        recordingCount: 1,
        nativeRecordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'recording_started',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'recording',
          },
          observedAt: startedAt,
        ),
        CockpitStepRecord(
          index: 1,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
          },
          observedAt: startedAt.add(const Duration(seconds: 8)),
          artifactRefs: <CockpitArtifactRef>[artifact],
        ),
      ],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const {'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );

    final deliveryJson =
        jsonDecode(
              await File(
                p.join(outputDir.path, 'delivery.json'),
              ).readAsString(),
            )
            as Map<String, Object?>;
    final keyframes = (deliveryJson['keyframes'] as List<Object?>)
        .cast<Map<Object?, Object?>>();

    expect(deliveryJson['deliveryKeyframesReady'], isTrue);
    expect(deliveryJson['keyframeCoverage'], <String, Object?>{
      'durationMs': 8000,
      'hasEarlyCoverage': true,
      'hasMidCoverage': true,
      'hasLateCoverage': true,
      'isReady': true,
    });
    expect(keyframes, hasLength(2));
    expect(
      File(
        p.join(outputDir.path, keyframes.first['ref']! as String),
      ).existsSync(),
      isTrue,
    );
  });

  test(
    'persists issue evidence for failed recording keyframe coverage',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_keyframe_issue_evidence',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: const _InsufficientRecordingKeyframeExtractor(),
      );
      const recordingArtifact = CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/home_acceptance.mp4',
      );
      const screenshotArtifact = CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
      await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
      final startedAt = DateTime.utc(2026, 3, 22, 6);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-keyframe-issue',
          taskId: 'task-keyframe-issue',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(seconds: 8)),
          artifactRefs: const <CockpitArtifactRef>[
            screenshotArtifact,
            recordingArtifact,
          ],
          screenshotCount: 1,
          recordingCount: 1,
          nativeRecordingCount: 1,
          deliveryArtifactsReady: true,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.32.0',
          dartVersion: '3.8.0',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'recording',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: startedAt.add(const Duration(seconds: 7)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: const <CockpitArtifactRef>[screenshotArtifact],
            captureRefs: const <CockpitArtifactRef>[screenshotArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'recording_stopped',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'completed',
              'recordingDurationMs': 8000,
            },
            observedAt: startedAt.add(const Duration(seconds: 8)),
            artifactRefs: const <CockpitArtifactRef>[recordingArtifact],
          ),
        ],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': <String>['screenshots/home_acceptance.png'],
          'deliveryArtifactsReady': true,
          'primaryRecordingRef': 'recordings/home_acceptance.mp4',
          'videoAttachmentRefs': <String>['recordings/home_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: sourceFile.path,
        },
        artifactPayloads: const <String, List<int>>{
          'screenshots/home_acceptance.png': <int>[137, 80, 78, 71],
        },
      );

      final issueEvidence =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'issue_evidence.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;

      expect(issueEvidence['recommendedNextStep'], 'inspect_issue_evidence');
      expect(issueEvidence['issueKinds'], contains('gateFailure'));
      final gateFailures = issueEvidence['gateFailures'] as List<Object?>;
      expect(
        gateFailures,
        contains(
          allOf(
            isA<Map<String, Object?>>(),
            containsPair('gate', 'artifactsReady'),
            containsPair(
              'failureCodes',
              contains('recordingCoverageInsufficient'),
            ),
          ),
        ),
      );
      expect(
        gateFailures,
        contains(
          allOf(
            isA<Map<String, Object?>>(),
            containsPair('gate', 'deliveryValidated'),
            containsPair(
              'failureCodes',
              contains('recordingCoverageInsufficient'),
            ),
          ),
        ),
      );
    },
  );

  test(
    'supplements sparse recording keyframes with baseline and acceptance screenshots',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _SparseRecordingKeyframeExtractor(),
      );
      final recordingArtifact = const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/home_acceptance.mp4',
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
      await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-005c',
          taskId: 'task-video-keyframes-sparse',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 3269)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
            recordingArtifact,
          ],
          recordingCount: 1,
          nativeRecordingCount: 1,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'recording',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'baseline_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 340)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 1222)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_stopped',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'completed',
              'recordingDurationMs': 3269,
            },
            observedAt: startedAt.add(const Duration(milliseconds: 3269)),
            artifactRefs: <CockpitArtifactRef>[recordingArtifact],
          ),
        ],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const {'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'primaryRecordingRef': 'recordings/home_acceptance.mp4',
          'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: sourceFile.path,
        },
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();

      expect(deliveryJson['deliveryKeyframesReady'], isTrue);
      expect(deliveryJson.containsKey('keyframeFailureReason'), isFalse);
      expect(deliveryJson['keyframeCoverage'], <String, Object?>{
        'durationMs': 3269,
        'hasEarlyCoverage': true,
        'hasMidCoverage': true,
        'hasLateCoverage': true,
        'isReady': true,
      });
      expect(keyframes, hasLength(3));
      expect(
        keyframes.map((keyframe) => keyframe['label']),
        containsAll(<Object?>['baseline', 'acceptance', 'tail_consistency']),
      );
      final supplementedBaseline = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'baseline',
      );
      final supplementedAcceptance = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'acceptance',
      );
      expect(
        supplementedBaseline['linkedScreenshotRef'],
        baselineArtifact.relativePath,
      );
      expect(
        supplementedAcceptance['linkedScreenshotRef'],
        acceptanceArtifact.relativePath,
      );
      expect(
        File(
          p.join(outputDir.path, supplementedBaseline['ref']! as String),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(outputDir.path, supplementedAcceptance['ref']! as String),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'chooses a tail consistency keyframe that matches the final acceptance view',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_tail_consistency',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final acceptancePng = _encodePng(_buildAcceptanceImage());
      final baselinePng = _encodePng(_buildBaselineImage());
      final staleTailPng = _encodePng(_buildStaleEditorImage());
      final recordingArtifact = const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/ios_acceptance.mp4',
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/ios_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/ios_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 22, 12, 45, 29);
      final recordingFile = File(p.join(tempDir.path, 'ios_acceptance.mp4'))
        ..writeAsBytesSync(const <int>[0, 1, 2, 3, 4]);

      final writer = TaskRunBundleWriter(
        keyframeExtractor: DefaultCockpitRecordingKeyframeExtractor(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"hevc","codec_type":"video","width":1320,"height":2868}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"8.445"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              if (outputPath.contains('tail_consistency')) {
                final seekValue = arguments[arguments.indexOf('-sseof') + 1];
                final bytes = switch (seekValue) {
                  '-0.600' => staleTailPng,
                  '-1.200' || '-1.800' => acceptancePng,
                  _ => <int>[],
                };
                if (bytes.isNotEmpty) {
                  await File(outputPath).writeAsBytes(bytes);
                }
                return ProcessResult(0, 0, '', '');
              }
              final bytes = outputPath.contains('baseline')
                  ? baselinePng
                  : acceptancePng;
              await File(outputPath).writeAsBytes(bytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
      );

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-tail-consistency',
          taskId: 'task-tail-consistency',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 11178)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
            recordingArtifact,
          ],
          screenshotCount: 2,
          recordingCount: 1,
          nativeRecordingCount: 1,
          deliveryArtifactsReady: true,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'recording',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'baseline_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 235)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 8445)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_stopped',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'completed',
              'recordingDurationMs': 11178,
            },
            observedAt: startedAt.add(const Duration(milliseconds: 11178)),
            artifactRefs: <CockpitArtifactRef>[recordingArtifact],
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/ios_acceptance.png',
          'attachmentRefs': [
            'screenshots/ios_baseline.png',
            'screenshots/ios_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'primaryRecordingRef': 'recordings/ios_acceptance.mp4',
          'videoAttachmentRefs': ['recordings/ios_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: baselinePng,
          acceptanceArtifact.relativePath: acceptancePng,
        },
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: recordingFile.path,
        },
      );

      final deliveryJson =
          jsonDecode(
                await File(
                  p.join(outputDir.path, 'delivery.json'),
                ).readAsString(),
              )
              as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();
      final tailKeyframe = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'tail_consistency',
      );
      final tailBytes = await File(
        p.join(outputDir.path, tailKeyframe['ref']! as String),
      ).readAsBytes();

      expect(tailBytes, acceptancePng);
    },
  );

  test(
    'externalizes forensic snapshots into diagnostics artifacts and keeps step snapshots summarized',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      final writer = TaskRunBundleWriter();
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final diagnosticsArtifact = const CockpitArtifactRef(
        role: 'diagnostics',
        relativePath: 'diagnostics/step_000_snapshot.json',
      );
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-006',
          taskId: 'task-diagnostics',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 4),
          artifactRefs: <CockpitArtifactRef>[diagnosticsArtifact],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'collectSnapshot',
            actionArgs: const <String, Object?>{},
            observedAt: DateTime.utc(2026, 3, 20, 8, 1),
            artifactRefs: <CockpitArtifactRef>[diagnosticsArtifact],
            snapshot: CockpitSnapshot(
              routeName: '/checkout',
              diagnosticLevel: CockpitSnapshotProfile.forensic,
              truncated: true,
              diagnosticsArtifactRef: diagnosticsArtifact,
              summary: CockpitSnapshotSummary(
                visibleTargetCount: 1,
                targetsWithCockpitIdCount: 1,
                targetsWithTextCount: 0,
                styleDetailsIncluded: false,
                diagnosticPropertiesIncluded: true,
                ancestorSummariesIncluded: false,
                rebuildSummaryIncluded: false,
                accessibilitySummaryIncluded: false,
              ),
              visibleTargets: <CockpitSnapshotTarget>[
                CockpitSnapshotTarget(
                  registrationId: 'checkout.submit',
                  cockpitId: 'submit_button',
                  routeName: '/checkout',
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
                  ],
                  diagnosticProperties: <CockpitDiagnosticProperty>[
                    CockpitDiagnosticProperty(
                      name: 'label',
                      value: 'Submit',
                      category: CockpitDiagnosticCategory.basic,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        observations: <CockpitObservation>[
          CockpitObservation(
            routeName: '/checkout',
            diagnosticLevel: CockpitSnapshotProfile.forensic,
            truncated: true,
            diagnosticsArtifactRef: diagnosticsArtifact,
          ),
        ],
        acceptanceMarkdown: '# Acceptance\n\nDiagnosed.',
        handoff: const {'status': 'completed'},
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
      );
      final diagnosticsJson =
          jsonDecode(
                File(
                  p.join(outputDir.path, diagnosticsArtifact.relativePath),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final stepsJson =
          jsonDecode(
                File(p.join(outputDir.path, 'steps.json')).readAsStringSync(),
              )
              as List<Object?>;
      final inlineSnapshot =
          ((stepsJson.single as Map<Object?, Object?>)['snapshot']
              as Map<Object?, Object?>?) ??
          const <Object?, Object?>{};

      expect(
        File(
          p.join(outputDir.path, diagnosticsArtifact.relativePath),
        ).existsSync(),
        isTrue,
      );
      expect(diagnosticsJson['diagnosticLevel'], 'forensic');
      expect(
        (diagnosticsJson['visibleTargets'] as List<Object?>),
        hasLength(1),
      );
      expect(
        inlineSnapshot['diagnosticsArtifactRef'],
        diagnosticsArtifact.toJson(),
      );
      expect(inlineSnapshot['truncated'], isTrue);
    },
  );

  test(
    'rejects externalized diagnostics refs outside diagnostics artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_invalid_diagnostics_ref',
      );
      final writer = TaskRunBundleWriter();
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      const diagnosticsArtifact = CockpitArtifactRef(
        role: 'diagnostics',
        relativePath: 'screenshots/not_diagnostics.json',
      );
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-invalid-diagnostics',
          taskId: 'task-invalid-diagnostics',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 4),
          artifactRefs: const <CockpitArtifactRef>[diagnosticsArtifact],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'collectSnapshot',
            actionArgs: const <String, Object?>{},
            observedAt: DateTime.utc(2026, 3, 20, 8, 1),
            artifactRefs: const <CockpitArtifactRef>[diagnosticsArtifact],
            snapshot: CockpitSnapshot(
              routeName: '/checkout',
              diagnosticLevel: CockpitSnapshotProfile.forensic,
              truncated: true,
              diagnosticsArtifactRef: diagnosticsArtifact,
            ),
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nDiagnosed.',
        handoff: const <String, Object?>{'status': 'completed'},
      );

      await expectLater(
        writer.writeBundle(bundle: bundle, outputRoot: tempDir.path),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('Diagnostics artifact path must stay under diagnostics/'),
          ),
        ),
      );
    },
  );
}

final class _FakeRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: const <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_baseline.png',
          label: 'baseline',
          offsetMs: 600,
          source: CockpitRecordingKeyframeSource.stepCapture,
        ),
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_tail.png',
          label: 'tail_consistency',
          offsetMs: 7600,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/home_acceptance_baseline.png': const <int>[137, 80, 78, 71],
        'keyframes/home_acceptance_tail.png': const <int>[137, 80, 78, 71],
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 8000,
        hasEarlyCoverage: true,
        hasMidCoverage: true,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _InvalidKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  const _InvalidKeyframeExtractor({
    this.keyframeRef = 'keyframes/home_acceptance_tail.png',
    this.linkedScreenshotRef,
  });

  final String keyframeRef;
  final String? linkedScreenshotRef;

  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: keyframeRef,
          label: 'tail_consistency',
          offsetMs: 1600,
          source: CockpitRecordingKeyframeSource.tailConsistency,
          linkedScreenshotRef: linkedScreenshotRef,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        keyframeRef: const <int>[137, 80, 78, 71],
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 1800,
        hasEarlyCoverage: true,
        hasMidCoverage: true,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _SparseRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: const <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_tail.png',
          label: 'tail_consistency',
          offsetMs: 2669,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/home_acceptance_tail.png': const <int>[137, 80, 78, 71],
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 3269,
        hasEarlyCoverage: false,
        hasMidCoverage: false,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _InsufficientRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  const _InsufficientRecordingKeyframeExtractor();

  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return const CockpitRecordingKeyframeExtractionResult(
      keyframes: <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_tail.png',
          label: 'tail_consistency',
          offsetMs: 7600,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/home_acceptance_tail.png': <int>[137, 80, 78, 71],
      },
      coverage: CockpitRecordingCoverage(
        durationMs: 8000,
        hasEarlyCoverage: false,
        hasMidCoverage: false,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _FakeTimelineVideoFallbackBuilder
    implements CockpitTimelineVideoFallbackBuilder {
  const _FakeTimelineVideoFallbackBuilder({
    required this.sourceRoot,
    required this.durationMs,
  });

  final String sourceRoot;
  final int durationMs;

  @override
  Future<CockpitTimelineVideoFallbackResult?> build({
    required CockpitContextBundle bundle,
    required String outputDirectoryPath,
  }) async {
    final file = File(p.join(sourceRoot, 'fallback-video.mp4'));
    await file.writeAsBytes(const <int>[0, 1, 2, 3]);
    return CockpitTimelineVideoFallbackResult(
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath:
            'recordings/task-fallback-video_session-fallback-video_timeline_fallback.mp4',
      ),
      sourceFilePath: file.path,
      durationMs: durationMs,
      screenshotRefs: const <String>[
        'screenshots/home_baseline.png',
        'screenshots/home_acceptance.png',
      ],
    );
  }
}

List<int> _encodePng(img.Image image) => img.encodePng(image);

img.Image _buildAcceptanceImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(9, 14, 14));
  img.fillRect(
    image,
    x1: 20,
    y1: 40,
    x2: 220,
    y2: 100,
    color: img.ColorRgb8(20, 36, 34),
  );
  img.fillRect(
    image,
    x1: 20,
    y1: 140,
    x2: 220,
    y2: 430,
    color: img.ColorRgb8(12, 19, 18),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 170,
    x2: 208,
    y2: 182,
    color: img.ColorRgb8(235, 238, 237),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 210,
    x2: 160,
    y2: 218,
    color: img.ColorRgb8(212, 216, 214),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 248,
    x2: 188,
    y2: 256,
    color: img.ColorRgb8(212, 216, 214),
  );
  return image;
}

img.Image _buildBaselineImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(14, 18, 22));
  img.fillRect(
    image,
    x1: 20,
    y1: 56,
    x2: 220,
    y2: 156,
    color: img.ColorRgb8(28, 45, 52),
  );
  return image;
}

img.Image _buildStaleEditorImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(10, 14, 14));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 188,
    color: img.ColorRgb8(18, 24, 24),
  );
  img.fillRect(
    image,
    x1: 20,
    y1: 320,
    x2: 220,
    y2: 372,
    color: img.ColorRgb8(161, 195, 187),
  );
  img.fillRect(
    image,
    x1: 24,
    y1: 214,
    x2: 216,
    y2: 216,
    color: img.ColorRgb8(86, 96, 94),
  );
  return image;
}
