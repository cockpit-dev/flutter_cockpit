import 'dart:typed_data';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit/src/executor/in_app/cockpit_capture_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captureExplicit waits for observation readiness and applies default snapshot options',
    () async {
      var settleCount = 0;
      bool? includeNetworkIdle;
      CockpitScreenshotRequest? capturedRequest;
      final orchestrator = CockpitCaptureOrchestrator(
        captureHandler: (request) async {
          capturedRequest = request;
          return CockpitCaptureResult(
            screenshot: CockpitCapturedScreenshot(
              artifact: const CockpitArtifactRef(
                role: 'screenshot',
                relativePath: 'screenshots/acceptance.png',
              ),
              bytes: Uint8List.fromList(const <int>[137, 80, 78, 71]),
            ),
            requestedProfile: CockpitCaptureProfile.acceptance,
            resolvedCaptureKind: CockpitCaptureKind.flutterView,
          );
        },
        postActionSettler: () async {},
        settleBeforeObservation: () async {
          settleCount += 1;
        },
        bestEffortWaitForUiIdle: (
            {required bool includeNetworkIdleValue}) async {
          includeNetworkIdle = includeNetworkIdleValue;
        },
        defaultSnapshotOptionsForReason: (reason) {
          expect(reason, CockpitScreenshotReason.acceptance);
          return const CockpitSnapshotOptions.investigate();
        },
      );

      final outcome = await orchestrator.captureExplicit(
        CockpitCommand(
          commandId: 'cmd-capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'acceptance',
            includeSnapshot: true,
          ),
        ),
        waitForNetworkIdleDuringAcceptanceCapture: true,
      );

      expect(outcome, isNotNull);
      expect(settleCount, 2);
      expect(includeNetworkIdle, isTrue);
      expect(capturedRequest?.snapshotOptions,
          const CockpitSnapshotOptions.investigate());
      expect(
          outcome!.artifacts.single.relativePath, 'screenshots/acceptance.png');
      expect(
        outcome.artifactPayloads['screenshots/acceptance.png'],
        Uint8List.fromList(const <int>[137, 80, 78, 71]),
      );
    },
  );

  test(
      'captureAfterAction returns null when the command does not request capture',
      () async {
    final orchestrator = CockpitCaptureOrchestrator(
      captureHandler: (_) async => throw UnimplementedError(),
      postActionSettler: () async {},
      settleBeforeObservation: () async {},
      bestEffortWaitForUiIdle: ({required includeNetworkIdleValue}) async {},
      defaultSnapshotOptionsForReason: (_) =>
          const CockpitSnapshotOptions.live(),
    );

    final outcome = await orchestrator.captureAfterAction(
      CockpitCommand(
        commandId: 'cmd-tap',
        commandType: CockpitCommandType.tap,
        capturePolicy: CockpitCapturePolicy.none,
      ),
    );

    expect(outcome, isNull);
  });
}
