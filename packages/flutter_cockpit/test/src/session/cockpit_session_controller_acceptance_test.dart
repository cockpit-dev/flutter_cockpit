import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delivery prefers acceptance screenshot over baseline screenshot', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 21, 8, 0, 0),
      DateTime.utc(2026, 3, 21, 8, 0, 1),
      DateTime.utc(2026, 3, 21, 8, 0, 2),
      DateTime.utc(2026, 3, 21, 8, 0, 3),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-delivery-primary',
      taskId: 'task-home',
      platform: 'android',
      now: nextTimestamp,
    );

    controller.recordCommandResult(
      CockpitCommand(
        commandId: 'cmd-baseline-shot',
        commandType: CockpitCommandType.captureScreenshot,
      ),
      CockpitCommandResult(
        success: true,
        commandId: 'cmd-baseline-shot',
        commandType: CockpitCommandType.captureScreenshot,
        durationMs: 30,
        artifacts: const [
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/baseline_home.png',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
        resolvedCaptureKind: CockpitCaptureKind.flutterView,
      ),
    );

    controller.recordCommandResult(
      CockpitCommand(
        commandId: 'cmd-acceptance-shot',
        commandType: CockpitCommandType.captureScreenshot,
      ),
      CockpitCommandResult(
        success: true,
        commandId: 'cmd-acceptance-shot',
        commandType: CockpitCommandType.captureScreenshot,
        durationMs: 40,
        artifacts: const [
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/acceptance_home.png',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.acceptance,
        resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
      ),
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['flutterViewCapture', 'nativeAcceptanceCapture'],
    );

    expect(
      bundle.delivery['primaryScreenshotRef'],
      'screenshots/acceptance_home.png',
    );
    expect(bundle.delivery['attachmentRefs'], const [
      'screenshots/baseline_home.png',
      'screenshots/acceptance_home.png',
    ]);
  });

  test('session close counts native and Flutter screenshots separately', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 12, 0, 0),
      DateTime.utc(2026, 3, 20, 12, 0, 1),
      DateTime.utc(2026, 3, 20, 12, 0, 2),
      DateTime.utc(2026, 3, 20, 12, 0, 3),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-acceptance',
      taskId: 'task-home',
      platform: 'ios',
      now: nextTimestamp,
    );

    controller.recordCommandResult(
      CockpitCommand(
        commandId: 'cmd-native-shot',
        commandType: CockpitCommandType.captureScreenshot,
      ),
      CockpitCommandResult(
        success: true,
        commandId: 'cmd-native-shot',
        commandType: CockpitCommandType.captureScreenshot,
        durationMs: 40,
        artifacts: const [
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/native_home.png',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.acceptance,
        resolvedCaptureKind: CockpitCaptureKind.nativeAcceptance,
      ),
    );

    controller.recordCommandResult(
      CockpitCommand(
        commandId: 'cmd-flutter-shot',
        commandType: CockpitCommandType.captureScreenshot,
      ),
      CockpitCommandResult(
        success: true,
        commandId: 'cmd-flutter-shot',
        commandType: CockpitCommandType.captureScreenshot,
        durationMs: 35,
        artifacts: const [
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/flutter_home.png',
          ),
        ],
        requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
        resolvedCaptureKind: CockpitCaptureKind.flutterView,
      ),
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['flutterViewCapture', 'nativeAcceptanceCapture'],
    );

    expect(bundle.manifest.screenshotCount, 2);
    expect(bundle.manifest.nativeScreenshotCount, 1);
    expect(bundle.manifest.flutterScreenshotCount, 1);
    expect(bundle.manifest.deliveryArtifactsReady, isTrue);
    expect(
      bundle.steps.first.requestedCaptureProfile,
      CockpitCaptureProfile.acceptance,
    );
    expect(
      bundle.steps.first.resolvedCaptureKind,
      CockpitCaptureKind.nativeAcceptance,
    );
    expect(
      bundle.steps.last.requestedCaptureProfile,
      CockpitCaptureProfile.diagnostic,
    );
    expect(
      bundle.steps.last.resolvedCaptureKind,
      CockpitCaptureKind.flutterView,
    );
  });
}
