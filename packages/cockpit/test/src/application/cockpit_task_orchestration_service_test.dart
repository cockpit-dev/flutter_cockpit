import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_bundle_artifact_paths.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_launch_remote_session_service.dart';
import 'package:cockpit/src/application/cockpit_query_remote_session_service.dart';
import 'package:cockpit/src/application/cockpit_read_task_bundle_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_remote_control_script_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/application/cockpit_task_gate.dart';
import 'package:cockpit/src/application/cockpit_task_orchestration_service.dart';
import 'package:cockpit/src/application/cockpit_task_stage.dart';
import 'package:cockpit/src/cli/cockpit_control_script.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'orchestration completes the closed loop when session, bundle, and delivery evidence are ready',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_task_orchestration_completed',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'android');
      CockpitRunRemoteControlScriptRequest? capturedRunScriptRequest;
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: handle,
          health: _status(
            sessionId: 'task-orchestration-launch-demo',
            platform: 'android',
            route: '/editor',
          ),
        ),
        query: (_) async => throw UnimplementedError(),
        runScript: (request) async {
          capturedRunScriptRequest = request;
          return _runScriptResult(
            bundleDir: bundleDir,
            handle: handle,
            platform: 'android',
            screenshotRelativePath: 'screenshots/acceptance.png',
            recordingRelativePath: 'recordings/acceptance.mp4',
          );
        },
        readSummary: (_) async => _summary(
          bundleDir: bundleDir,
          platform: 'android',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          status: CockpitTaskStatus.completed,
        ),
      );

      final result = await service.orchestrate(
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
          liveRunId: '20260619T120000000Z_task-orchestration-session',
          liveRunDisplayName: 'Task orchestration acceptance',
          baseline: const CockpitRunTaskBaselineRequest(
            captureScreenshot: true,
          ),
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
            requireVideoEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(result.recommendedNextStep, 'delivery_ready');
      expect(
        result.completedStages,
        containsAll(<CockpitTaskStage>[
          CockpitTaskStage.assess,
          CockpitTaskStage.bootstrap,
          CockpitTaskStage.baseline,
          CockpitTaskStage.execute,
          CockpitTaskStage.observe,
          CockpitTaskStage.judge,
          CockpitTaskStage.deliver,
        ]),
      );
      expect(result.isGateSatisfied(CockpitTaskGate.sessionReachable), isTrue);
      expect(result.isGateSatisfied(CockpitTaskGate.baselineCollected), isTrue);
      expect(result.isGateSatisfied(CockpitTaskGate.executionFinished), isTrue);
      expect(result.isGateSatisfied(CockpitTaskGate.bundleWritten), isTrue);
      expect(result.isGateSatisfied(CockpitTaskGate.deliveryValidated), isTrue);
      expect(result.isGateSatisfied(CockpitTaskGate.screenshotReady), isTrue);
      expect(
        result.isGateSatisfied(CockpitTaskGate.recordingReadyOrExplained),
        isTrue,
      );
      expect(
        result.isGateSatisfied(CockpitTaskGate.finalAssertionPassed),
        isTrue,
      );
      expect(
        capturedRunScriptRequest?.liveRunId,
        '20260619T120000000Z_task-orchestration-session',
      );
      expect(
        capturedRunScriptRequest?.liveRunDisplayName,
        'Task orchestration acceptance',
      );
    },
  );

  test(
    'orchestration stops a launched automation app after bundle read',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_task_orchestration_cleanup',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'macos');
      CockpitAppHandle? stoppedApp;
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: handle,
          health: _status(
            sessionId: 'task-orchestration-launch-cleanup',
            platform: 'macos',
            route: '/inbox',
          ),
        ),
        query: (_) async => throw UnimplementedError(),
        runScript: (_) async => _runScriptResult(
          bundleDir: bundleDir,
          handle: handle,
          platform: 'macos',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
        readSummary: (_) async => _summary(
          bundleDir: bundleDir,
          platform: 'macos',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          status: CockpitTaskStatus.completed,
        ),
        stopAutomationApp: (app) async {
          stoppedApp = app;
        },
      );

      final result = await service.orchestrate(
        CockpitRunTaskRequest(
          launch: const CockpitRunTaskLaunchRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            platform: 'macos',
            deviceId: 'macos',
            sessionPort: 47331,
          ),
          script: _script(platform: 'macos'),
          outputRoot: bundleDir.path,
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
            requireVideoEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(stoppedApp?.mode, CockpitAppMode.automation);
      expect(stoppedApp?.baseUrl, handle.baseUrl);
      expect(result.warnings, isEmpty);
    },
  );

  test(
    'orchestration still stops a launched automation app when execution fails',
    () async {
      final handle = _sessionHandle(platform: 'macos');
      CockpitAppHandle? stoppedApp;
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: handle,
          health: _status(
            sessionId: 'task-orchestration-launch-cleanup-failed',
            platform: 'macos',
            route: '/inbox',
          ),
        ),
        query: (_) async => throw UnimplementedError(),
        runScript: (_) async => throw const CockpitApplicationServiceException(
          code: 'remoteExecutionFailed',
          message: 'Command failed.',
        ),
        readSummary: (_) async => throw UnimplementedError(),
        stopAutomationApp: (app) async {
          stoppedApp = app;
        },
      );

      final result = await service.orchestrate(
        CockpitRunTaskRequest(
          launch: const CockpitRunTaskLaunchRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            platform: 'macos',
            deviceId: 'macos',
            sessionPort: 47331,
          ),
          script: _script(platform: 'macos'),
          outputRoot: '/tmp/out',
        ),
      );

      expect(
        result.classification,
        CockpitRunTaskClassification.blockedByEnvironment,
      );
      expect(result.blockedReason, 'Command failed.');
      expect(stoppedApp?.mode, CockpitAppMode.automation);
      expect(stoppedApp?.baseUrl, handle.baseUrl);
      expect(result.warnings, isEmpty);
    },
  );

  test(
    'orchestration preserves the primary result when launched app cleanup fails',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_task_orchestration_cleanup_warning',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'macos');
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: handle,
          health: _status(
            sessionId: 'task-orchestration-launch-cleanup-warning',
            platform: 'macos',
            route: '/inbox',
          ),
        ),
        query: (_) async => throw UnimplementedError(),
        runScript: (_) async => _runScriptResult(
          bundleDir: bundleDir,
          handle: handle,
          platform: 'macos',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
        ),
        readSummary: (_) async => _summary(
          bundleDir: bundleDir,
          platform: 'macos',
          screenshotRelativePath: 'screenshots/acceptance.png',
          recordingRelativePath: 'recordings/acceptance.mp4',
          status: CockpitTaskStatus.completed,
        ),
        stopAutomationApp: (_) async {
          throw StateError('taskkill failed');
        },
      );

      final result = await service.orchestrate(
        CockpitRunTaskRequest(
          launch: const CockpitRunTaskLaunchRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            platform: 'macos',
            deviceId: 'macos',
            sessionPort: 47331,
          ),
          script: _script(platform: 'macos'),
          outputRoot: bundleDir.path,
          requirements: const CockpitRunTaskEvidenceRequirements(
            requireScreenshotEvidence: true,
            requireVideoEvidence: true,
          ),
        ),
      );

      expect(result.classification, CockpitRunTaskClassification.completed);
      expect(
        result.warnings,
        contains(
          contains('Automation cleanup failed after task orchestration'),
        ),
      );
      expect(result.warnings, contains(contains('taskkill failed')));
    },
  );

  test(
    'orchestration reports needs_more_work when required video evidence is missing',
    () async {
      final bundleDir = await Directory.systemTemp.createTemp(
        'cockpit_task_orchestration_needs_more_work',
      );
      addTearDown(() async {
        if (bundleDir.existsSync()) {
          await bundleDir.delete(recursive: true);
        }
      });

      final handle = _sessionHandle(platform: 'ios');
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => CockpitQueryRemoteSessionResult(
          status: _status(
            sessionId: 'task-orchestration-reuse-demo',
            platform: 'ios',
            route: '/preview',
          ),
          sessionHandle: handle,
          recommendedNextStep: 'ready_for_commands',
        ),
        runScript: (_) async => _runScriptResult(
          bundleDir: bundleDir,
          handle: handle,
          platform: 'ios',
          screenshotRelativePath: 'screenshots/acceptance.png',
        ),
        readSummary: (_) async => _summary(
          bundleDir: bundleDir,
          platform: 'ios',
          screenshotRelativePath: 'screenshots/acceptance.png',
          status: CockpitTaskStatus.completed,
          deliveryVideoReady: false,
        ),
      );

      final result = await service.orchestrate(
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
      expect(result.isGateSatisfied(CockpitTaskGate.sessionReachable), isTrue);
      expect(
        result.isGateSatisfied(CockpitTaskGate.recordingReadyOrExplained),
        isFalse,
      );
      expect(
        result.isGateSatisfied(CockpitTaskGate.deliveryValidated),
        isFalse,
      );
      expect(
        result.isGateSatisfied(CockpitTaskGate.finalAssertionPassed),
        isTrue,
      );
    },
  );

  test(
    'orchestration reports blocked_by_environment when bootstrap cannot resolve a session',
    () async {
      final service = CockpitTaskOrchestrationService(
        launch: (_) async => throw UnimplementedError(),
        query: (_) async => throw const CockpitApplicationServiceException(
          code: 'missingSessionReference',
          message: 'Session reference is required.',
        ),
        runScript: (_) async => throw UnimplementedError(),
        readSummary: (_) async => throw UnimplementedError(),
      );

      final result = await service.orchestrate(
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
      expect(result.isGateSatisfied(CockpitTaskGate.sessionReachable), isFalse);
      expect(
        result.completedStages,
        containsAll(<CockpitTaskStage>[
          CockpitTaskStage.assess,
          CockpitTaskStage.bootstrap,
        ]),
      );
      expect(result.completedStages, isNot(contains(CockpitTaskStage.execute)));
    },
  );
}

CockpitRunRemoteControlScriptResult _runScriptResult({
  required Directory bundleDir,
  required CockpitRemoteSessionHandle handle,
  required String platform,
  String? screenshotRelativePath,
  String? recordingRelativePath,
}) {
  return CockpitRunRemoteControlScriptResult(
    sessionHandle: handle,
    bundleDir: bundleDir,
    manifest: CockpitRunManifest(
      sessionId: 'task-orchestration-session',
      taskId: 'task-orchestration-task',
      platform: platform,
      status: CockpitTaskStatus.completed,
      startedAt: DateTime.utc(2026, 3, 30, 0, 0),
      finishedAt: DateTime.utc(2026, 3, 30, 0, 5),
      commandCount: 2,
      screenshotCount: screenshotRelativePath == null ? 0 : 1,
      deliveryArtifactsReady: screenshotRelativePath != null,
      deliveryVideoReady: recordingRelativePath != null,
    ),
    handoff: const <String, Object?>{'status': 'completed'},
    delivery: <String, Object?>{
      'primaryScreenshotRef': ?screenshotRelativePath,
      'primaryRecordingRef': ?recordingRelativePath,
    },
    artifactPaths: CockpitBundleArtifactPaths(
      primaryScreenshotPath: screenshotRelativePath == null
          ? null
          : p.join(bundleDir.path, screenshotRelativePath),
      primaryRecordingPath: recordingRelativePath == null
          ? null
          : p.join(bundleDir.path, recordingRelativePath),
    ),
  );
}

CockpitReadTaskBundleSummaryResult _summary({
  required Directory bundleDir,
  required String platform,
  required CockpitTaskStatus status,
  String? screenshotRelativePath,
  String? recordingRelativePath,
  bool? deliveryVideoReady,
}) {
  return CockpitReadTaskBundleSummaryResult(
    bundleDir: bundleDir.path,
    manifest: CockpitRunManifest(
      sessionId: 'task-orchestration-session',
      taskId: 'task-orchestration-task',
      platform: platform,
      status: status,
      startedAt: DateTime.utc(2026, 3, 30, 0, 0),
      finishedAt: DateTime.utc(2026, 3, 30, 0, 5),
      commandCount: 2,
      screenshotCount: screenshotRelativePath == null ? 0 : 1,
      deliveryArtifactsReady: screenshotRelativePath != null,
      deliveryVideoReady: deliveryVideoReady ?? recordingRelativePath != null,
    ),
    handoff: const <String, Object?>{'status': 'completed'},
    delivery: <String, Object?>{
      'primaryScreenshotRef': ?screenshotRelativePath,
      'primaryRecordingRef': ?recordingRelativePath,
    },
    acceptanceMarkdown: '# Acceptance\n\n- Status: completed\n',
    artifactPaths: CockpitBundleArtifactPaths(
      primaryScreenshotPath: screenshotRelativePath == null
          ? null
          : p.join(bundleDir.path, screenshotRelativePath),
      primaryRecordingPath: recordingRelativePath == null
          ? null
          : p.join(bundleDir.path, recordingRelativePath),
    ),
    evidenceSummary: <String, Object?>{
      'status': 'completed',
      'commandCount': 2,
      'screenshotCount': screenshotRelativePath == null ? 0 : 1,
      'recordingCount': recordingRelativePath == null ? 0 : 1,
      'failureCount': 0,
    },
  );
}

CockpitControlScript _script({required String platform}) {
  return CockpitControlScript(
    sessionId: 'task-orchestration-session',
    taskId: 'task-orchestration-task',
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
        locator: const CockpitLocator(cockpitId: 'open_form_button'),
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
    launchedAt: DateTime.utc(2026, 3, 30, 0, 0),
  );
}

CockpitRemoteSessionStatus _status({
  required String sessionId,
  required String platform,
  required String route,
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
  );
}
