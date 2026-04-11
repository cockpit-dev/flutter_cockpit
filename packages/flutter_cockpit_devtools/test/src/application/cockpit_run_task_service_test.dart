import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_query_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_task_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_task_gate.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_control_script.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('run task request json uses lower camel case keys', () {
    final request = CockpitRunTaskRequest(
      launch: const CockpitRunTaskLaunchRequest(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        platform: 'android',
        deviceId: 'emulator-5554',
        sessionPort: 47331,
        launchTimeout: Duration(seconds: 90),
        persistHandlePath: '/tmp/session.json',
      ),
      sessionHandlePath: '/tmp/existing-session.json',
      script: _script(platform: 'android'),
      outputRoot: '/tmp/output',
      persistScriptPath: '/tmp/script.json',
      baseline: const CockpitRunTaskBaselineRequest(
        captureScreenshot: true,
        screenshotName: 'baseline-home',
        includeSnapshot: false,
      ),
      requirements: const CockpitRunTaskEvidenceRequirements(
        requireScreenshotEvidence: true,
        requireVideoEvidence: true,
      ),
    );

    expect(request.toJson(), <String, Object?>{
      'launch': <String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'cockpit/main.dart',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'sessionPort': 47331,
        'launchTimeoutSeconds': 90,
        'persistHandlePath': '/tmp/session.json',
      },
      'sessionHandlePath': '/tmp/existing-session.json',
      'script': _script(platform: 'android').toJson(),
      'outputRoot': '/tmp/output',
      'persistScriptPath': '/tmp/script.json',
      'baseline': <String, Object?>{
        'captureScreenshot': true,
        'screenshotName': 'baseline-home',
        'includeSnapshot': false,
      },
      'requirements': <String, Object?>{
        'requireScreenshotEvidence': true,
        'requireVideoEvidence': true,
      },
    });
  });

  test(
    'run task launches, injects baseline capture, reads the persisted bundle, and classifies completion',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_completed',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      final preflightStatus = _status(
        sessionId: 'run-task-launch-demo',
        platform: 'android',
        route: '/home',
      );
      CockpitRunRemoteControlScriptRequest? capturedRunRequest;
      final service = CockpitRunTaskService(
        launch: (_) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: handle,
          health: preflightStatus,
        ),
        query: (_) async => throw UnimplementedError(),
        runScript: (request) async {
          capturedRunRequest = request;
          return CockpitRunRemoteControlScriptResult(
            sessionHandle: handle,
            bundleDir: bundleDir,
            manifest: CockpitRunManifest(
              sessionId: 'run-task-session',
              taskId: 'run-task-id',
              platform: 'android',
              status: CockpitTaskStatus.completed,
              startedAt: DateTime.utc(2026, 3, 21, 0, 0),
              finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
              commandCount: 2,
              screenshotCount: 1,
              deliveryArtifactsReady: true,
            ),
            handoff: const <String, Object?>{'status': 'completed'},
            delivery: const <String, Object?>{
              'primaryScreenshotRef': 'screenshots/acceptance.png',
            },
            artifactPaths: CockpitBundleArtifactPaths(
              primaryScreenshotPath: p.join(
                bundleDir.path,
                'screenshots',
                'acceptance.png',
              ),
            ),
          );
        },
        readSummary: (_) async => CockpitReadTaskBundleSummaryResult(
          bundleDir: bundleDir.path,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 2,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
          },
          acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
          ),
          evidenceSummary: const <String, Object?>{
            'status': 'completed',
            'commandCount': 2,
            'screenshotCount': 1,
            'recordingCount': 0,
            'failureCount': 0,
          },
        ),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          launch: const CockpitRunTaskLaunchRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'lib/main.dart',
            platform: 'android',
            deviceId: 'emulator-5554',
            sessionPort: 47331,
          ),
          script: _script(platform: 'android'),
          outputRoot: bundleDir.path,
          baseline: const CockpitRunTaskBaselineRequest(
            captureScreenshot: true,
            screenshotName: 'task-baseline',
          ),
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(result.recommendedNextStep, 'delivery_ready');
      expect(result.sessionHandle?.toJson(), handle.toJson());
      expect(result.preflightStatus?.sessionId, 'run-task-launch-demo');
      expect(result.bundleSummary?.bundleDir, bundleDir.path);
      expect(capturedRunRequest?.script.commands, hasLength(2));
      expect(
        capturedRunRequest?.script.commands.first.commandType,
        CockpitCommandType.captureScreenshot,
      );
      expect(
        capturedRunRequest?.script.commands.first.screenshotRequest?.reason,
        CockpitScreenshotReason.baseline,
      );
      expect(
        capturedRunRequest
            ?.script.commands.first.screenshotRequest?.snapshotOptions?.profile,
        CockpitSnapshotProfile.baseline,
      );
    },
  );

  test(
    'run task classifies missing required video evidence as needs_more_work',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_needs_more_work',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'ios');
      final service = CockpitRunTaskService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'run-task-reuse-demo',
            platform: 'ios',
            route: '/home',
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (request) async => CockpitRunRemoteControlScriptResult(
          sessionHandle: handle,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'ios',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: false,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
          },
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
          ),
        ),
        readSummary: (_) async => CockpitReadTaskBundleSummaryResult(
          bundleDir: bundleDir.path,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'ios',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: false,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
          },
          acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
          ),
          evidenceSummary: const <String, Object?>{
            'status': 'completed',
            'commandCount': 1,
            'screenshotCount': 1,
            'recordingCount': 0,
            'failureCount': 0,
          },
        ),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          sessionHandle: handle,
          script: _script(platform: 'ios'),
          outputRoot: bundleDir.path,
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
            requireVideoEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.needsMoreWork);
      expect(result.recommendedNextStep, 'collect_missing_evidence');
    },
  );

  test(
    'run task classifies runtime errors as failed_with_evidence even when media is present',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_runtime_errors',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      final service = CockpitRunTaskService(
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'run-task-runtime-demo',
            platform: 'android',
            route: '/home',
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (request) async => CockpitRunRemoteControlScriptResult(
          sessionHandle: handle,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
            runtimeEventCount: 1,
            runtimeErrorCount: 1,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
          },
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
          ),
        ),
        readSummary: (_) async => CockpitReadTaskBundleSummaryResult(
          bundleDir: bundleDir.path,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
            screenshotCount: 1,
            deliveryArtifactsReady: true,
            runtimeEventCount: 1,
            runtimeErrorCount: 1,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
          },
          acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
          ),
          evidenceSummary: const <String, Object?>{
            'status': 'completed',
            'commandCount': 1,
            'screenshotCount': 1,
            'recordingCount': 0,
            'failureCount': 0,
            'runtimeEventCount': 1,
            'runtimeErrorCount': 1,
            'runtimeWarningCount': 0,
          },
        ),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          sessionHandle: handle,
          script: _script(platform: 'android'),
          outputRoot: bundleDir.path,
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
          ),
        ),
      );

      expect(
        result.classification,
        CockpitRunTaskClassification.failedWithEvidence,
      );
      expect(result.recommendedNextStep, 'inspect_bundle');
    },
  );

  test(
    'run task classifies bootstrap failure as blocked_by_environment instead of throwing',
    () async {
      final service = CockpitRunTaskService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => throw const CockpitApplicationServiceException(
          code: 'missingSessionReference',
          message: 'Session reference is required.',
        ),
        runScript: (_) async => throw UnimplementedError(),
        readSummary: (_) async => throw UnimplementedError(),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          sessionHandlePath: '/tmp/missing.json',
          script: _script(platform: 'android'),
          outputRoot: '/tmp/out',
        ),
      );

      expect(
        result.classification,
        CockpitRunTaskClassification.blockedByEnvironment,
      );
      expect(result.recommendedNextStep, 'needs_relaunch');
      expect(result.blockedReason, contains('Session reference is required.'));
      expect(result.bundleSummary, isNull);
    },
  );

  test(
    'run task classifies bundle summary read failure as blocked_by_environment',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_summary_failure',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      final service = CockpitRunTaskService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'run-task-reuse-demo',
            platform: 'android',
            route: '/home',
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (_) async => CockpitRunRemoteControlScriptResult(
          sessionHandle: handle,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{},
          artifactPaths: CockpitBundleArtifactPaths(),
        ),
        readSummary: (_) async =>
            throw const CockpitApplicationServiceException(
          code: 'invalidBundleJson',
          message: 'Bundle JSON is invalid.',
        ),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          sessionHandle: handle,
          script: _script(platform: 'android'),
          outputRoot: bundleDir.path,
        ),
      );

      expect(
        result.classification,
        CockpitRunTaskClassification.blockedByEnvironment,
      );
      expect(result.recommendedNextStep, 'needs_relaunch');
      expect(result.blockedReason, 'Bundle JSON is invalid.');
      expect(result.bundleSummary, isNull);
    },
  );

  test(
    'run task allows a script without environment when preflight status provides one',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_resolved_environment',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      final service = CockpitRunTaskService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'run-task-reuse-demo',
            platform: 'android',
            route: '/home',
            environment: const CockpitEnvironment(
              platform: 'android',
              flutterVersion: '3.38.9',
              dartVersion: '3.10.8',
            ),
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (_) async => CockpitRunRemoteControlScriptResult(
          sessionHandle: handle,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{},
          artifactPaths: CockpitBundleArtifactPaths(),
        ),
        readSummary: (_) async => CockpitReadTaskBundleSummaryResult(
          bundleDir: bundleDir.path,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
            platform: 'android',
            status: CockpitTaskStatus.completed,
            startedAt: DateTime.utc(2026, 3, 21, 0, 0),
            finishedAt: DateTime.utc(2026, 3, 21, 0, 5),
            commandCount: 1,
          ),
          handoff: const <String, Object?>{'status': 'completed'},
          delivery: const <String, Object?>{},
          acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
          artifactPaths: CockpitBundleArtifactPaths(),
          evidenceSummary: const <String, Object?>{
            'status': 'completed',
            'commandCount': 1,
            'screenshotCount': 0,
            'recordingCount': 0,
            'failureCount': 0,
          },
        ),
      );

      final request = CockpitRunTaskRequest.fromJson(<String, Object?>{
        'sessionHandle': handle.toJson(),
        'script': <String, Object?>{
          'sessionId': 'run-task-session',
          'taskId': 'run-task-id',
          'platform': 'android',
          'commands': <Map<String, Object?>>[
            <String, Object?>{
              'commandId': 'tap-open',
              'commandType': 'tap',
              'locator': const CockpitLocator(
                cockpitId: 'open_form_button',
              ).toJson(),
            },
          ],
          'failFast': true,
        },
        'outputRoot': bundleDir.path,
      });

      final result = await service.run(request);

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(result.preflightStatus?.toJson()['environment'], isNotNull);
    },
  );

  test(
    'run task keeps completed classification when fallback is acceptable but exposes degraded plane gates',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_run_task_service_plane_fallback',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      final gateSummary = const CockpitBundleGateSummary(
        gates: <CockpitTaskGate, bool>{
          CockpitTaskGate.sessionReachable: true,
          CockpitTaskGate.targetReachable: true,
          CockpitTaskGate.baselineCollected: true,
          CockpitTaskGate.executionFinished: true,
          CockpitTaskGate.bundleWritten: true,
          CockpitTaskGate.intendedPlaneWorked: false,
          CockpitTaskGate.fallbackAcceptable: true,
          CockpitTaskGate.postconditionsSatisfied: true,
          CockpitTaskGate.artifactsReady: true,
          CockpitTaskGate.logsCollected: true,
          CockpitTaskGate.deliveryReadable: true,
          CockpitTaskGate.deliveryValidated: true,
          CockpitTaskGate.acceptanceEvidenceReadable: true,
          CockpitTaskGate.screenshotReady: true,
          CockpitTaskGate.recordingReadyOrExplained: true,
          CockpitTaskGate.finalAssertionPassed: true,
        },
      );
      final service = CockpitRunTaskService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'run-task-fallback-demo',
            platform: 'android',
            route: '/home',
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (_) async => CockpitRunRemoteControlScriptResult(
          sessionHandle: handle,
          bundleDir: bundleDir,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
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
            commandCount: 1,
            screenshotCount: 1,
            recordingCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
            runtimeEventCount: 1,
          ),
          handoff: const <String, Object?>{
            'status': 'completed',
            'fallbackCount': 1,
          },
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
            'primaryRecordingRef': 'recordings/acceptance.mp4',
          },
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
            primaryRecordingPath: p.join(
              bundleDir.path,
              'recordings',
              'acceptance.mp4',
            ),
          ),
        ),
        readSummary: (_) async => CockpitReadTaskBundleSummaryResult(
          bundleDir: bundleDir.path,
          manifest: CockpitRunManifest(
            sessionId: 'run-task-session',
            taskId: 'run-task-id',
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
            commandCount: 1,
            screenshotCount: 1,
            recordingCount: 1,
            deliveryArtifactsReady: true,
            deliveryVideoReady: true,
            runtimeEventCount: 1,
          ),
          handoff: const <String, Object?>{
            'status': 'completed',
            'fallbackCount': 1,
          },
          delivery: const <String, Object?>{
            'primaryScreenshotRef': 'screenshots/acceptance.png',
            'primaryRecordingRef': 'recordings/acceptance.mp4',
          },
          acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
          artifactPaths: CockpitBundleArtifactPaths(
            primaryScreenshotPath: p.join(
              bundleDir.path,
              'screenshots',
              'acceptance.png',
            ),
            primaryRecordingPath: p.join(
              bundleDir.path,
              'recordings',
              'acceptance.mp4',
            ),
          ),
          evidenceSummary: const <String, Object?>{
            'status': 'completed',
            'commandCount': 1,
            'screenshotCount': 1,
            'recordingCount': 1,
            'failureCount': 0,
            'targetKind': 'flutterApp',
            'primaryExecutionPlane': 'flutterSemanticPlane',
            'planesUsed': <String>[
              'flutterSemanticPlane',
              'nativeUiPlane',
            ],
            'surfaceKindsUsed': <String>['flutterSemantic', 'nativeUi'],
            'fallbackCount': 1,
          },
          gateSummary: gateSummary,
        ),
      );

      final result = await service.run(
        CockpitRunTaskRequest(
          sessionHandle: handle,
          script: _script(platform: 'android'),
          outputRoot: bundleDir.path,
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
            requireVideoEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(result.recommendedNextStep, 'review_fallbacks');
      expect(
        result.bundleSummary?.gateSummary.isSatisfied(
          CockpitTaskGate.intendedPlaneWorked,
        ),
        isFalse,
      );
      expect(
        result.bundleSummary?.gateSummary.isSatisfied(
          CockpitTaskGate.fallbackAcceptable,
        ),
        isTrue,
      );
    },
  );
}

CockpitControlScript _script({required String platform}) {
  return CockpitControlScript(
    sessionId: 'run-task-session',
    taskId: 'run-task-id',
    platform: platform,
    environment: CockpitEnvironment(
      platform: platform,
      flutterVersion: '3.38.9',
      dartVersion: '3.10.8',
    ),
    commands: <CockpitCommand>[
      CockpitCommand(
        commandId: 'tap-open',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(
          cockpitId: 'open_form_button',
        ),
      ),
    ],
    failFast: true,
  );
}

CockpitRemoteSessionHandle _sessionHandle({required String platform}) {
  return CockpitRemoteSessionHandle(
    platform: platform,
    deviceId: platform == 'android' ? 'emulator-5554' : 'simulator',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    host: '127.0.0.1',
    hostPort: 58421,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:58421',
    launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
  );
}

CockpitRemoteSessionStatus _status({
  required String sessionId,
  required String platform,
  required String route,
  CockpitEnvironment? environment,
}) {
  return CockpitRemoteSessionStatus(
    sessionId: sessionId,
    platform: platform,
    transportType: 'remoteHttp',
    currentRouteName: route,
    capabilities: CockpitCapabilities(
      platform: platform,
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
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
    ),
    snapshot: CockpitSnapshot(routeName: route),
    environment: environment,
  );
}
