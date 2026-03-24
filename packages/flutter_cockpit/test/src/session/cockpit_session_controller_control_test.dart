import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session close aggregates command and screenshot counters', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 9, 0, 0),
      DateTime.utc(2026, 3, 20, 9, 0, 1),
      DateTime.utc(2026, 3, 20, 9, 0, 4),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-200',
      taskId: 'task-payment',
      platform: 'ios',
      now: nextTimestamp,
    );

    controller.recordStep(
      actionType: 'control_command',
      actionArgs: const {'target': 'submit_button'},
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
      durationMs: 90,
      status: CockpitCommandStatus.succeeded,
      captureRefs: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-01-after_action.png',
        ),
      ],
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['inAppControl', 'flutterViewCapture'],
    );

    expect(bundle.manifest.commandCount, 1);
    expect(bundle.manifest.screenshotCount, 1);
    expect(bundle.manifest.failureCount, 0);
    expect(bundle.manifest.capabilitiesUsed, [
      'inAppControl',
      'flutterViewCapture',
    ]);
  });

  test('recordCommandResult preserves structured command outcomes', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 9, 10, 0),
      DateTime.utc(2026, 3, 20, 9, 10, 1),
      DateTime.utc(2026, 3, 20, 9, 10, 2),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-201',
      taskId: 'task-command-result',
      platform: 'android',
      now: nextTimestamp,
    );
    final command = CockpitCommand(
      commandId: 'cmd-submit',
      commandType: CockpitCommandType.tap,
      locator: const CockpitLocator(
        kind: CockpitLocatorKind.cockpitId,
        value: 'submit_button',
      ),
    );
    final result = CockpitCommandResult(
      success: false,
      commandId: 'cmd-submit',
      commandType: CockpitCommandType.tap,
      locatorResolution: const CockpitLocatorResolution(
        matchedKind: CockpitLocatorKind.cockpitId,
        matchedValue: 'submit_button',
      ),
      durationMs: 80,
      artifacts: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-01-assertion_failure.png',
        ),
      ],
      snapshot: const {
        'routeName': '/checkout',
        'visibleTargets': [
          {
            'registrationId': 'submit',
            'cockpitId': 'submit_button',
            'routeName': '/checkout',
            'supportedCommands': ['tap'],
          },
        ],
      },
      error: CockpitCommandError.assertionFailed(
        message: 'Submit button is not visible.',
      ),
    );

    controller.recordCommandResult(command, result);

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      capabilitiesUsed: const ['inAppControl', 'flutterViewCapture'],
    );

    expect(bundle.steps, hasLength(1));
    expect(bundle.steps.single.commandType, CockpitCommandType.tap);
    expect(bundle.steps.single.status, CockpitCommandStatus.failed);
    expect(bundle.steps.single.captureRefs, hasLength(1));
    expect(bundle.steps.single.locator, command.locator);
    expect(bundle.steps.single.locatorResolution, result.locatorResolution);
    expect(bundle.observations.single.routeName, '/checkout');
    expect(bundle.observations.single.interactiveElements, const [
      'submit_button',
    ]);
    expect(bundle.manifest.commandCount, 1);
    expect(bundle.manifest.screenshotCount, 1);
    expect(bundle.manifest.failureCount, 1);
  });

  test(
    'recordCommandResult assigns diagnostics artifacts for forensic snapshots',
    () {
      final timestamps = <DateTime>[
        DateTime.utc(2026, 3, 20, 9, 20, 0),
        DateTime.utc(2026, 3, 20, 9, 20, 1),
        DateTime.utc(2026, 3, 20, 9, 20, 2),
      ].iterator;

      DateTime nextTimestamp() {
        final didMove = timestamps.moveNext();
        if (!didMove) {
          throw StateError('No more timestamps available.');
        }
        return timestamps.current;
      }

      final controller = CockpitSessionController(
        sessionId: 'session-202',
        taskId: 'task-diagnostics',
        platform: 'android',
        now: nextTimestamp,
      );
      final command = CockpitCommand(
        commandId: 'cmd-collect',
        commandType: CockpitCommandType.collectSnapshot,
      );
      final result = CockpitCommandResult(
        success: true,
        commandId: 'cmd-collect',
        commandType: CockpitCommandType.collectSnapshot,
        durationMs: 40,
        snapshot: CockpitSnapshot(
          routeName: '/checkout',
          diagnosticLevel: CockpitSnapshotProfile.forensic,
          truncated: true,
          summary: const CockpitSnapshotSummary(
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
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              diagnosticProperties: const <CockpitDiagnosticProperty>[
                CockpitDiagnosticProperty(
                  name: 'label',
                  value: 'Submit',
                  category: CockpitDiagnosticCategory.basic,
                ),
              ],
            ),
          ],
        ).toJson(),
      );

      controller.recordCommandResult(command, result);

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
      );

      expect(
        bundle.steps.single.snapshot?.diagnosticsArtifactRef?.relativePath,
        'diagnostics/step_000_cmd_collect_snapshot.json',
      );
      expect(
        bundle.steps.single.artifactRefs,
        contains(
          const CockpitArtifactRef(
            role: 'diagnostics',
            relativePath: 'diagnostics/step_000_cmd_collect_snapshot.json',
          ),
        ),
      );
      expect(
        bundle.observations.single.diagnosticsArtifactRef?.relativePath,
        'diagnostics/step_000_cmd_collect_snapshot.json',
      );
      expect(
        bundle.observations.single.diagnosticLevel,
        CockpitSnapshotProfile.forensic,
      );
    },
  );
}
