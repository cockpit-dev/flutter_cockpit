import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'captures an acceptance screenshot from FlutterCockpitRoot for the Todo inbox',
    (tester) async {
      final controller = buildTestController(
        sessionId: 'root-capture-session',
        taskId: 'root-capture-task',
        platform: 'android',
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(tester, controller: controller, database: database);
      await createTaskThroughUi(
        tester,
        title: 'Capture inbox acceptance',
        notes: 'Verify screenshot evidence from the root surface',
        priorityLabel: 'HIGH',
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final capture = await tester.runAsync(() {
        return rootState.captureScreenshot(
          const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'todo-inbox-acceptance',
            includeSnapshot: true,
            attachToStep: true,
          ),
        );
      });

      controller.recordStep(
        actionType: 'capture_acceptance',
        actionArgs: const <String, Object?>{'target': 'root'},
        observation: CockpitObservation(
          routeName: capture!.screenshot.snapshot?.routeName,
          interactiveElements:
              capture.screenshot.snapshot?.visibleTargets
                  .map((target) => target.displayLabel)
                  .whereType<String>()
                  .toList(growable: false) ??
              const <String>[],
          phase: CockpitObservationPhase.afterAction,
        ),
        artifactRefs: <CockpitArtifactRef>[capture.screenshot.artifact],
        captureRefs: <CockpitArtifactRef>[capture.screenshot.artifact],
        commandType: CockpitCommandType.captureScreenshot,
        status: CockpitCommandStatus.succeeded,
        requestedCaptureProfile: capture.requestedProfile,
        resolvedCaptureKind: capture.resolvedCaptureKind,
        usedCaptureFallback: capture.usedFallback,
        degradationReason: capture.degradationReason,
      );

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        capabilitiesUsed: const <String>['flutterViewCapture'],
      );
      final captureStep = bundle.steps.lastWhere(
        (step) => step.actionType == 'capture_acceptance',
      );

      expect(find.text('Capture inbox acceptance'), findsWidgets);
      expect(bundle.manifest.screenshotCount, 1);
      expect(
        captureStep.requestedCaptureProfile,
        CockpitCaptureProfile.acceptance,
      );
      expect(captureStep.resolvedCaptureKind, CockpitCaptureKind.flutterView);
      expect(captureStep.usedCaptureFallback, isFalse);
      expect(capture.screenshot.snapshot?.routeName, '/inbox');
      expect(
        capture.screenshot.snapshot?.visibleTargets.any(
          (target) => target.tooltip == 'Settings' || target.text == 'Settings',
        ),
        isTrue,
      );
    },
  );
}
