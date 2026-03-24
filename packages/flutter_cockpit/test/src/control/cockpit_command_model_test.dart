import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CockpitStepRecord preserves control metadata through json', () {
    final record = CockpitStepRecord(
      index: 1,
      actionType: 'control_command',
      actionArgs: const {'target': 'submit_button'},
      observedAt: DateTime.utc(2026, 3, 20, 9, 0, 1),
      observation: CockpitObservation(
        routeName: '/checkout',
        interactiveElements: const ['submit_button'],
        phase: CockpitObservationPhase.afterAction,
      ),
      artifactRefs: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-01-after_action.png',
        ),
      ],
      commandType: CockpitCommandType.tap,
      locator: const CockpitLocator(
        kind: CockpitLocatorKind.cockpitId,
        value: 'submit_button',
      ),
      locatorResolution: const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.cockpitId,
        matchedValue: 'submit_button',
      ),
      durationMs: 120,
      status: CockpitCommandStatus.succeeded,
      captureRefs: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-01-after_action.png',
        ),
      ],
    );

    expect(CockpitStepRecord.fromJson(record.toJson()), record);
  });

  test('CockpitRunManifest preserves execution summary metadata', () {
    final manifest = CockpitRunManifest(
      sessionId: 'session-100',
      taskId: 'task-payment',
      platform: 'android',
      status: CockpitTaskStatus.completed,
      startedAt: DateTime.utc(2026, 3, 20, 9, 0),
      finishedAt: DateTime.utc(2026, 3, 20, 9, 3),
      artifactRefs: const [],
      capabilitiesUsed: const ['inAppControl', 'flutterViewCapture'],
      commandCount: 3,
      screenshotCount: 2,
      failureCount: 0,
    );

    expect(CockpitRunManifest.fromJson(manifest.toJson()), manifest);
  });

  test('CockpitObservation preserves phase metadata', () {
    final observation = CockpitObservation(
      routeName: '/checkout',
      interactiveElements: const ['submit_button'],
      phase: CockpitObservationPhase.baseline,
    );

    expect(CockpitObservation.fromJson(observation.toJson()), observation);
  });

  test('CockpitCommand preserves transport-ready control metadata', () {
    final command = CockpitCommand(
      commandId: 'cmd-001',
      commandType: CockpitCommandType.enterText,
      locator: const CockpitLocator(
        kind: CockpitLocatorKind.cockpitId,
        value: 'email_field',
        fallbacks: [
          CockpitLocator(
            kind: CockpitLocatorKind.semanticId,
            value: 'email_input',
          ),
          CockpitLocator(kind: CockpitLocatorKind.text, value: 'Email'),
        ],
      ),
      parameters: const {'text': 'cockpit@example.com'},
      capturePolicy: CockpitCapturePolicy.afterActionAndFailure,
      timeoutMs: 3000,
      snapshotOptions: const CockpitSnapshotOptions(
        profile: CockpitSnapshotProfile.investigate,
        maxTargets: 40,
        maxAncestorsPerTarget: 3,
        maxPropertiesPerTarget: 12,
        includeStyleDetails: true,
        includeDiagnosticProperties: true,
        includeNetworkActivity: true,
        networkQuery: CockpitNetworkQuery(
          method: 'POST',
          uriContains: '/sync',
          onlyFailures: true,
          statusCodeAtLeast: 500,
        ),
      ),
      screenshotRequest: const CockpitScreenshotRequest(
        reason: CockpitScreenshotReason.afterAction,
        name: 'email-entered',
        includeSnapshot: true,
        attachToStep: true,
        snapshotOptions: CockpitSnapshotOptions.baseline(),
      ),
    );

    expect(CockpitCommand.fromJson(command.toJson()), command);
  });

  test('CockpitCommand preserves multi-touch gesture payloads', () {
    final command = CockpitCommand(
      commandId: 'cmd-gesture',
      commandType: CockpitCommandType.multiTouch,
      locator: const CockpitLocator(
        kind: CockpitLocatorKind.text,
        value: 'Canvas',
      ),
      parameters: <String, Object?>{
        'sequence': CockpitMultiTouchSequence(
          steps: const <CockpitMultiTouchStep>[
            CockpitMultiTouchStep(
              pointer: 1,
              phase: CockpitMultiTouchPhase.down,
              atMs: 0,
              dx: -18,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 2,
              phase: CockpitMultiTouchPhase.down,
              atMs: 0,
              dx: 18,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 1,
              phase: CockpitMultiTouchPhase.move,
              atMs: 120,
              dx: -48,
              dy: 0,
            ),
            CockpitMultiTouchStep(
              pointer: 2,
              phase: CockpitMultiTouchPhase.move,
              atMs: 120,
              dx: 48,
              dy: 0,
            ),
          ],
        ).toJson(),
      },
    );

    expect(CockpitCommand.fromJson(command.toJson()), command);
  });

  test('CockpitLocator preserves fallback chains through json', () {
    const locator = CockpitLocator(
      kind: CockpitLocatorKind.cockpitId,
      value: 'submit_button',
      fallbacks: [
        CockpitLocator(
          kind: CockpitLocatorKind.semanticId,
          value: 'checkout_submit',
          fallbacks: [
            CockpitLocator(
              kind: CockpitLocatorKind.text,
              value: 'Submit order',
            ),
          ],
        ),
      ],
    );

    expect(CockpitLocator.fromJson(locator.toJson()), locator);
  });

  test('CockpitLocator supports widget key locators through json', () {
    const locator = CockpitLocator(
      kind: CockpitLocatorKind.key,
      value: 'task-item:42',
      fallbacks: [
        CockpitLocator(kind: CockpitLocatorKind.text, value: 'Review docs'),
      ],
    );

    expect(CockpitLocator.fromJson(locator.toJson()), locator);
  });

  test('CockpitCommandResult preserves artifacts, snapshot, and errors', () {
    final result = CockpitCommandResult(
      success: false,
      commandId: 'cmd-002',
      commandType: CockpitCommandType.assertVisible,
      locatorResolution: const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.text,
        matchedValue: 'Submit order',
      ),
      durationMs: 450,
      artifacts: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-02-assertion_failure.png',
        ),
      ],
      snapshot: const {
        'routeName': '/checkout',
        'interactiveElements': ['submit_button'],
      },
      error: CockpitCommandError.assertionFailed(
        message: 'Submit order is not visible.',
        details: const {'expectedText': 'Submit order'},
      ),
    );

    expect(CockpitCommandResult.fromJson(result.toJson()), result);
  });

  test('CockpitCommandError factories use stable protocol codes', () {
    expect(
      CockpitCommandError.ambiguousTarget(
        message: 'Multiple buttons matched.',
      ).code,
      'ambiguousTarget',
    );
    expect(
      CockpitCommandError.unsupportedCapability(
        message: 'enterText is not supported.',
      ).code,
      'unsupportedCapability',
    );
    expect(
      CockpitCommandError.invalidGestureParameters(
        message: 'durationMs must be positive.',
      ).code,
      'invalidGestureParameters',
    );
    expect(
      CockpitCommandError.gestureExecutionFailed(
        message: 'Gesture engine could not resolve target bounds.',
      ).code,
      'gestureExecutionFailed',
    );
  });
}
