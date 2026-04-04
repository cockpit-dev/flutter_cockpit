import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_control_script.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'produces a delivery-ready Todo bundle with valid screenshot and recording artifacts',
    (tester) async {
      final outputDirectory = Directory.systemTemp.createTempSync(
        'cockpit_demo_delivery_validation_success',
      );
      addTearDown(() async => deleteDirectory(outputDirectory));

      final recordingFile = File(p.join(outputDirectory.path, 'recording.mp4'));
      recordingFile.parent.createSync(recursive: true);
      recordingFile.writeAsBytesSync(validMp4Bytes);

      var tick = 0;
      final controller = buildTestController(
        sessionId: 'todo-delivery-session',
        taskId: 'todo-delivery-task',
        platform: 'android',
        now: () => DateTime.utc(2026, 3, 21, 6, 0, tick++),
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: controller,
        database: database,
        configuration: FlutterCockpitConfiguration(
          initialRouteName: '/inbox',
          nativeRecording: FakeCockpitNativeRecording(
            sourceFilePath: recordingFile.path,
          ),
        ),
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final artifactPayloads = <String, List<int>>{};

      final baselineCapture = await tester.runAsync(() {
        return rootState.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.baseline,
            name: 'todo-baseline',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });
      recordCapture(
        controller: controller,
        actionType: 'capture_baseline',
        capture: baselineCapture!,
        artifactPayloads: artifactPayloads,
      );

      controller.recordStep(
        actionType: 'recording_start_requested',
        actionArgs: const <String, Object?>{
          'recordingName': 'todo-acceptance',
          'recordingPurpose': 'acceptance',
          'recordingState': 'starting',
        },
      );
      final session = await tester.runAsync(() {
        return rootState.startRecording(
          const CockpitRecordingRequest(
            purpose: CockpitRecordingPurpose.acceptance,
            name: 'todo-acceptance',
            attachToStep: true,
          ),
        );
      });
      controller.recordStep(
        actionType: 'recording_started',
        actionArgs: <String, Object?>{
          'recordingName': session!.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': session.state.name,
        },
      );

      await createTaskThroughUi(
        tester,
        title: 'Ship AI Todo flow',
        notes: 'Validate screenshots, recordings, and bundle summaries',
        priorityLabel: 'URGENT',
        dueLabel: 'Today',
      );

      final acceptanceCapture = await tester.runAsync(() {
        return rootState.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'todo-acceptance',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });
      recordCapture(
        controller: controller,
        actionType: 'capture_acceptance',
        capture: acceptanceCapture!,
        artifactPayloads: artifactPayloads,
      );

      final forensicSnapshot = rootState.snapshot(
        options: const CockpitSnapshotOptions.forensic(),
      );
      controller.recordCommandResult(
        CockpitCommand(
          commandId: 'investigate_success_state',
          commandType: CockpitCommandType.collectSnapshot,
          snapshotOptions: const CockpitSnapshotOptions.forensic(),
        ),
        CockpitCommandResult(
          success: true,
          commandId: 'investigate_success_state',
          commandType: CockpitCommandType.collectSnapshot,
          durationMs: 28,
          snapshot: forensicSnapshot.toJson(),
        ),
      );

      final recordingResult = await tester.runAsync(rootState.stopRecording);
      controller.recordStep(
        actionType: 'recording_stopped',
        actionArgs: <String, Object?>{
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': recordingResult!.state.name,
          'recordingDurationMs': recordingResult.durationMs,
        },
        artifactRefs: <CockpitArtifactRef>[recordingResult.artifact!],
      );

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        capabilitiesUsed: const <String>[
          'flutterViewCapture',
          'nativeRecording',
          'richDiagnostics',
        ],
      );

      final writtenBundle = await tester.runAsync(() async {
        return buildTestBundleWriter().writeBundle(
          bundle: bundle,
          outputRoot: outputDirectory.path,
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: <String, String>{
            recordingResult.artifact!.relativePath:
                recordingResult.sourceFilePath!,
          },
        );
      });

      final summary = await tester.runAsync(() {
        return const CockpitReadTaskBundleSummaryService().read(
          CockpitReadTaskBundleSummaryRequest(bundleDir: writtenBundle!.path),
        );
      });
      final comparisonReadySummary = CockpitReadTaskBundleSummaryResult(
        bundleDir: summary!.bundleDir,
        manifest: summary.manifest,
        handoff: summary.handoff,
        delivery: summary.delivery,
        acceptanceMarkdown: summary.acceptanceMarkdown,
        artifactPaths: summary.artifactPaths,
        evidenceSummary: <String, Object?>{
          ...summary.evidenceSummary,
          'acceptanceComparisonReady': true,
        },
        baselineEvidence: CockpitBundleAcceptanceEvidence(
          routeName: '/editor',
          diagnosticLevel: 'baseline',
          diagnosticsArtifactPath: summary.diagnosticsArtifactPaths.single,
          visibleTextPreviews: const <String>['New task', 'Details'],
          visibleSemanticIds: const <String>['task-editor-screen'],
          interactiveLabels: const <String>['Save task'],
          accessibilityLabels: const <String>['Task editor'],
          visibleTargetCount: 3,
          accessibilityEntryCount: 1,
          hasAccessibilitySummary: true,
          networkEntryCount: 0,
          networkFailureCount: 0,
          networkFailureSignals: const <CockpitBundleAcceptanceNetworkSignal>[],
          runtimeEntryCount: 0,
          runtimeErrorCount: 0,
          runtimeWarningCount: 0,
          runtimeErrorSignals: const <CockpitBundleAcceptanceRuntimeSignal>[],
          rebuildTotalCount: 0,
          rebuildUniqueElementCount: 0,
          rebuildHotspots: const <CockpitBundleAcceptanceRebuildHotspot>[],
        ),
        acceptanceEvidence: CockpitBundleAcceptanceEvidence(
          routeName: '/inbox',
          diagnosticLevel: 'investigate',
          diagnosticsArtifactPath: summary.diagnosticsArtifactPaths.single,
          visibleTextPreviews: const <String>[
            'Ship AI Todo flow',
            'Validate screenshots, recordings, and bundle summaries',
          ],
          visibleSemanticIds: const <String>['todo-inbox-screen', 'task-list'],
          interactiveLabels: const <String>['Open'],
          accessibilityLabels: const <String>['Todo inbox'],
          visibleTargetCount: 4,
          accessibilityEntryCount: 1,
          hasAccessibilitySummary: true,
          networkEntryCount: 1,
          networkFailureCount: 0,
          networkFailureSignals: const <CockpitBundleAcceptanceNetworkSignal>[],
          runtimeEntryCount: 0,
          runtimeErrorCount: 0,
          runtimeWarningCount: 0,
          runtimeErrorSignals: const <CockpitBundleAcceptanceRuntimeSignal>[],
          rebuildTotalCount: 0,
          rebuildUniqueElementCount: 0,
          rebuildHotspots: const <CockpitBundleAcceptanceRebuildHotspot>[],
        ),
        acceptanceDelta: CockpitBundleAcceptanceDelta(
          baselineRouteName: '/editor',
          acceptanceRouteName: '/inbox',
          routeChanged: true,
          addedVisibleTextPreviews: const <String>[
            'Ship AI Todo flow',
            'Validate screenshots, recordings, and bundle summaries',
          ],
          removedVisibleTextPreviews: const <String>['New task', 'Details'],
          addedSemanticIds: const <String>['todo-inbox-screen', 'task-list'],
          removedSemanticIds: const <String>['task-editor-screen'],
          addedInteractiveLabels: const <String>['Open'],
          removedInteractiveLabels: const <String>['Save task'],
          addedAccessibilityLabels: const <String>['Todo inbox'],
          removedAccessibilityLabels: const <String>['Task editor'],
          networkFailureDeltaCount: 0,
          newNetworkFailureSignals: const <CockpitBundleAcceptanceNetworkSignal>[],
          runtimeErrorDeltaCount: 0,
          newRuntimeErrorSignals: const <CockpitBundleAcceptanceRuntimeSignal>[],
          rebuildTotalDeltaCount: 0,
          rebuildUniqueElementDeltaCount: 0,
          newRebuildHotspots: const <CockpitBundleAcceptanceRebuildHotspot>[],
        ),
        diagnosticsArtifactPaths: summary.diagnosticsArtifactPaths,
        networkSummary: summary.networkSummary,
        runtimeSummary: summary.runtimeSummary,
        rebuildSummary: summary.rebuildSummary,
      );
      final consistencyValidator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            final path = arguments.last;
            if (path.endsWith('.png')) {
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"png","codec_type":"video","width":1280,"height":720}],"format":{"format_name":"png_pipe"}}',
                '',
              );
            }
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":1280,"height":720}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(acceptanceCapture.screenshot.bytes);
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );
      final validation = await tester.runAsync(() {
        return CockpitValidateTaskService(
          artifactValidator: consistencyValidator,
          runTask: (_) async => CockpitRunTaskResult(
            classification: CockpitRunTaskClassification.completed,
            recommendedNextStep: 'delivery_ready',
            bundleSummary: comparisonReadySummary,
          ),
        ).validate(
          CockpitValidateTaskRequest(
            runTask: _runTaskRequest(platform: 'android'),
            validation: const CockpitValidateTaskRequirements(
              expectedClassification: CockpitRunTaskClassification.completed,
              requireAcceptanceMarkdown: true,
              requireEnvironmentSnapshot: true,
              requirePrimaryScreenshot: true,
              requirePrimaryRecording: true,
              requireArtifactFiles: true,
            ),
          ),
        );
      });

      final artifactValidator = CockpitBundleArtifactValidator();
      final screenshotValidation = await tester.runAsync(() {
        return artifactValidator.validateScreenshot(
          summary.artifactPaths.primaryScreenshotPath!,
        );
      });
      final recordingValidation = await tester.runAsync(() {
        return artifactValidator.validateRecording(
          summary.artifactPaths.primaryRecordingPath!,
        );
      });
      final consistencyValidation = await tester.runAsync(() {
        return consistencyValidator.validateDeliveryConsistency(
          screenshotPath: summary.artifactPaths.primaryScreenshotPath!,
          recordingPath: summary.artifactPaths.primaryRecordingPath!,
        );
      });

      expect(find.text('Ship AI Todo flow'), findsWidgets);
      expect(
        validation!.classification,
        CockpitValidationClassification.completed,
      );
      expect(comparisonReadySummary.manifest.deliveryArtifactsReady, isTrue);
      expect(comparisonReadySummary.manifest.deliveryVideoReady, isTrue);
      expect(comparisonReadySummary.diagnosticsArtifactPaths, hasLength(1));
      expect(
        File(
          comparisonReadySummary.diagnosticsArtifactPaths.single,
        ).existsSync(),
        isTrue,
      );
      expect(
        comparisonReadySummary.delivery['primaryScreenshotRef'],
        acceptanceCapture.screenshot.artifact.relativePath,
      );
      expect(screenshotValidation!.isValid, isTrue);
      expect(recordingValidation!.isValid, isTrue);
      expect(consistencyValidation!.isValid, isTrue);
    },
  );

  testWidgets(
    'preserves Todo failure evidence and failed-with-evidence classification',
    (tester) async {
      final outputDirectory = Directory.systemTemp.createTempSync(
        'cockpit_demo_delivery_validation_failure',
      );
      addTearDown(() async => deleteDirectory(outputDirectory));

      var tick = 0;
      final controller = buildTestController(
        sessionId: 'todo-failure-session',
        taskId: 'todo-failure-task',
        platform: 'ios',
        now: () => DateTime.utc(2026, 3, 21, 6, 30, tick++),
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(tester, controller: controller, database: database);

      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save task'));
      await tester.pump();

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final artifactPayloads = <String, List<int>>{};

      final failureCapture = await tester.runAsync(() {
        return rootState.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.assertionFailure,
            name: 'todo-failure',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });
      recordCapture(
        controller: controller,
        actionType: 'capture_failure',
        capture: failureCapture!,
        artifactPayloads: artifactPayloads,
      );

      final forensicSnapshot = rootState.snapshot(
        options: const CockpitSnapshotOptions.forensic(),
      );
      controller.recordCommandResult(
        CockpitCommand(
          commandId: 'investigate_validation_failure',
          commandType: CockpitCommandType.collectSnapshot,
          snapshotOptions: const CockpitSnapshotOptions.forensic(),
        ),
        CockpitCommandResult(
          success: true,
          commandId: 'investigate_validation_failure',
          commandType: CockpitCommandType.collectSnapshot,
          durationMs: 24,
          snapshot: forensicSnapshot.toJson(),
        ),
      );

      final bundle = controller.finishWithFailure(
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        failureSummary: 'Task title validation failed.',
        capabilitiesUsed: const <String>[
          'flutterViewCapture',
          'richDiagnostics',
        ],
      );

      final writtenBundle = await tester.runAsync(() async {
        return buildTestBundleWriter().writeBundle(
          bundle: bundle,
          outputRoot: outputDirectory.path,
          artifactPayloads: artifactPayloads,
        );
      });

      final summary = await tester.runAsync(() {
        return const CockpitReadTaskBundleSummaryService().read(
          CockpitReadTaskBundleSummaryRequest(bundleDir: writtenBundle!.path),
        );
      });
      final validation = await tester.runAsync(() {
        return CockpitValidateTaskService(
          runTask: (_) async => CockpitRunTaskResult(
            classification: CockpitRunTaskClassification.failedWithEvidence,
            recommendedNextStep: 'inspect_bundle',
            bundleSummary: summary,
          ),
        ).validate(
          CockpitValidateTaskRequest(runTask: _runTaskRequest(platform: 'ios')),
        );
      });

      final screenshotValidation = await tester.runAsync(() {
        return CockpitBundleArtifactValidator().validateScreenshot(
          summary!.artifactPaths.primaryScreenshotPath!,
        );
      });

      expect(find.text('Task title is required.'), findsOneWidget);
      expect(
        validation!.classification,
        CockpitValidationClassification.failedWithEvidence,
      );
      expect(summary!.manifest.status, CockpitTaskStatus.failed);
      expect(
        summary.acceptanceMarkdown,
        contains('Task title validation failed.'),
      );
      expect(summary.diagnosticsArtifactPaths, hasLength(1));
      expect(screenshotValidation!.isValid, isTrue);
    },
  );
}

CockpitRunTaskRequest _runTaskRequest({required String platform}) {
  return CockpitRunTaskRequest(
    sessionHandle: CockpitRemoteSessionHandle(
      platform: platform,
      deviceId: platform == 'android' ? 'emulator-5554' : 'ios-simulator',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: platform == 'android'
          ? 'dev.cockpit.cockpit_demo'
          : 'dev.cockpit.cockpitDemo',
      host: '127.0.0.1',
      hostPort: 48331,
      devicePort: 48331,
      baseUrl: 'http://127.0.0.1:48331',
      launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
    ),
    script: CockpitControlScript(
      sessionId: 'example-validate-session',
      taskId: 'example-validate-task',
      platform: platform,
      commands: const <CockpitCommand>[],
      failFast: true,
    ),
    outputRoot: '/tmp/flutter_cockpit_example_validate',
  );
}
