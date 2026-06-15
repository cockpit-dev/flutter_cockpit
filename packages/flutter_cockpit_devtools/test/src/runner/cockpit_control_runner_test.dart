import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  group('control script workflow parsing', () {
    test(
      'parses workflow steps and keeps legacy commands for compatibility',
      () {
        final script = CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'script-session',
          'taskId': 'script-task',
          'platform': 'android',
          'commands': <Object?>[
            <String, Object?>{
              'commandId': 'legacy-open',
              'commandType': 'tap',
              'locator': <String, Object?>{'text': 'Open'},
            },
          ],
          'steps': <Object?>[
            <String, Object?>{
              'stepId': 'if-dialog',
              'stepType': 'if',
              'condition': <String, Object?>{
                'commandId': 'has-dialog',
                'commandType': 'assertText',
                'parameters': <String, Object?>{'text': 'Allow'},
              },
              'thenSteps': <Object?>[
                <String, Object?>{
                  'stepId': 'accept-dialog',
                  'stepType': 'command',
                  'command': <String, Object?>{
                    'commandId': 'tap-allow',
                    'commandType': 'tap',
                    'locator': <String, Object?>{'text': 'Allow'},
                  },
                },
              ],
            },
            <String, Object?>{
              'stepId': 'retry-ready',
              'stepType': 'retry',
              'maxAttempts': 4,
              'delayMs': 25,
              'step': <String, Object?>{
                'stepId': 'assert-ready-step',
                'stepType': 'command',
                'command': <String, Object?>{
                  'commandId': 'assert-ready',
                  'commandType': 'assertText',
                  'parameters': <String, Object?>{'text': 'Ready'},
                },
              },
            },
            <String, Object?>{
              'stepId': 'drain-items',
              'stepType': 'loop',
              'maxIterations': 3,
              'condition': <String, Object?>{
                'commandId': 'has-item',
                'commandType': 'assertText',
                'parameters': <String, Object?>{'text': 'Delete'},
              },
              'steps': <Object?>[
                <String, Object?>{
                  'stepId': 'delete-item',
                  'stepType': 'command',
                  'command': <String, Object?>{
                    'commandId': 'tap-delete',
                    'commandType': 'tap',
                    'locator': <String, Object?>{'text': 'Delete'},
                  },
                },
              ],
            },
          ],
        });

        expect(script.commands.single.commandId, 'legacy-open');
        expect(script.workflowSteps, hasLength(3));
        expect(script.workflowSteps.first, isA<CockpitIfWorkflowStep>());
        expect(script.workflowSteps[1], isA<CockpitRetryWorkflowStep>());
        expect(script.workflowSteps[2], isA<CockpitLoopWorkflowStep>());
        expect(script.toJson(), contains('steps'));
        expect(script.toJson(), containsPair('schemaVersion', 1));
      },
    );

    test('decodes YAML control scripts through the same workflow schema', () {
      final script = cockpitControlScriptFromText('''
schemaVersion: 1
sessionId: yaml-session
taskId: yaml-task
platform: ios
failFast: true
steps:
  - stepId: open-settings
    stepType: command
    command:
      commandId: tap-settings
      commandType: tap
      locator:
        text: Settings
  - stepId: wait-ready
    stepType: retry
    maxAttempts: 2
    delayMs: 0
    step:
      stepType: command
      command:
        commandId: assert-ready
        commandType: assertText
        parameters:
          text: Ready
''');

      expect(script.sessionId, 'yaml-session');
      expect(script.schemaVersion, 1);
      expect(script.commands, isEmpty);
      expect(script.workflowSteps, hasLength(2));
      expect(
        (script.workflowSteps.first as CockpitCommandWorkflowStep)
            .command
            .locator
            ?.text,
        'Settings',
      );
    });

    test('rejects unsupported workflow schema versions', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'schemaVersion': 2,
          'sessionId': 'future-script',
          'taskId': 'future-task',
          'platform': 'android',
          'commands': <Object?>[
            <String, Object?>{
              'commandId': 'tap-open',
              'commandType': 'tap',
              'locator': <String, Object?>{'text': 'Open'},
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('schemaVersion must be 1'),
          ),
        ),
      );
    });

    test('rejects non-integer workflow schema versions', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'schemaVersion': '1',
          'sessionId': 'bad-version-script',
          'taskId': 'bad-version-task',
          'platform': 'android',
          'commands': <Object?>[
            <String, Object?>{
              'commandId': 'tap-open',
              'commandType': 'tap',
              'locator': <String, Object?>{'text': 'Open'},
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('schemaVersion must be 1'),
          ),
        ),
      );
    });

    test('rejects malformed workflow steps with a clear format error', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'bad-script',
          'taskId': 'bad-task',
          'platform': 'android',
          'steps': <String, Object?>{'stepType': 'command'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('steps must be a list'),
          ),
        ),
      );
    });

    test('rejects non-object command entries with a clear format error', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'bad-command-script',
          'taskId': 'bad-command-task',
          'platform': 'android',
          'commands': <Object?>['tap-open'],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Control script command at commands[0] must be an object'),
          ),
        ),
      );
    });

    test('rejects non-boolean failFast with a clear format error', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'bad-fail-fast-script',
          'taskId': 'bad-fail-fast-task',
          'platform': 'android',
          'failFast': 'yes',
          'commands': <Object?>[
            <String, Object?>{
              'commandId': 'tap-open',
              'commandType': 'tap',
              'locator': <String, Object?>{'text': 'Open'},
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Control script failFast must be a boolean'),
          ),
        ),
      );
    });

    test('rejects retry steps that wrap non-command workflow nodes', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'bad-retry-script',
          'taskId': 'bad-retry-task',
          'platform': 'android',
          'steps': <Object?>[
            <String, Object?>{
              'stepId': 'retry-branch',
              'stepType': 'retry',
              'step': <String, Object?>{
                'stepType': 'if',
                'condition': <String, Object?>{
                  'commandId': 'has-dialog',
                  'commandType': 'assertText',
                  'parameters': <String, Object?>{'text': 'Allow'},
                },
              },
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('retry step must wrap a command step'),
          ),
        ),
      );
    });

    test('rejects empty command and workflow lists', () {
      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'empty-commands',
          'taskId': 'empty-commands-task',
          'platform': 'android',
          'commands': <Object?>[],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('commands must not be empty'),
          ),
        ),
      );

      expect(
        () => CockpitControlScript.fromJson(<String, Object?>{
          'sessionId': 'empty-steps',
          'taskId': 'empty-steps-task',
          'platform': 'android',
          'steps': <Object?>[],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('steps must not be empty'),
          ),
        ),
      );
    });
  });

  group('workflow steps', () {
    test(
      'executes the matching if branch without recording probe failures as command failures',
      () async {
        final adapter = _FakeAutomationAdapter(
          capabilities: _capabilities(),
          resultsByCommandId: <String, CockpitCommandResult>{
            'probe-dialog': _result(
              commandId: 'probe-dialog',
              commandType: CockpitCommandType.assertText,
              success: false,
            ),
            'tap-fallback': _result(commandId: 'tap-fallback'),
          },
        );
        final runner = CockpitControlRunner(
          automationAdapter: adapter,
          sessionController: CockpitSessionController(
            sessionId: 'workflow-if',
            taskId: 'workflow-if-task',
            platform: 'android',
            now: () => DateTime.utc(2026, 6, 15, 8),
          ),
        );

        final runResult = await runner.run(
          environment: _environment(),
          workflowSteps: <CockpitWorkflowStep>[
            CockpitIfWorkflowStep(
              stepId: 'dismiss-dialog-if-present',
              condition: CockpitCommand(
                commandId: 'probe-dialog',
                commandType: CockpitCommandType.assertText,
                parameters: const <String, Object?>{'text': 'Allow'},
              ),
              thenSteps: <CockpitWorkflowStep>[
                CockpitCommandWorkflowStep(
                  stepId: 'tap-allow',
                  command: CockpitCommand(
                    commandId: 'tap-allow',
                    commandType: CockpitCommandType.tap,
                    locator: const CockpitLocator(text: 'Allow'),
                  ),
                ),
              ],
              elseSteps: <CockpitWorkflowStep>[
                CockpitCommandWorkflowStep(
                  stepId: 'tap-fallback-step',
                  command: CockpitCommand(
                    commandId: 'tap-fallback',
                    commandType: CockpitCommandType.tap,
                    locator: const CockpitLocator(text: 'Continue'),
                  ),
                ),
              ],
            ),
          ],
        );

        expect(adapter.executedCommandIds, <String>[
          'probe-dialog',
          'tap-fallback',
        ]);
        expect(runResult.bundle.manifest.status, CockpitTaskStatus.completed);
        expect(runResult.bundle.manifest.failureCount, 0);
        final workflowStep = runResult.bundle.steps.first;
        expect(workflowStep.actionType, 'workflow_if');
        expect(
          workflowStep.actionArgs,
          containsPair('conditionSuccess', false),
        );
        expect(workflowStep.actionArgs, containsPair('selectedBranch', 'else'));
        expect(
          workflowStep.actionArgs,
          containsPair('conditionCommandId', 'probe-dialog'),
        );
        expect(
          runResult.bundle.steps.last.actionArgs['workflowStepId'],
          'tap-fallback-step',
        );
      },
    );

    test(
      'loops while the probe succeeds and stops at the first failed probe',
      () async {
        final adapter = _FakeAutomationAdapter.sequence(
          capabilities: _capabilities(),
          resultsByCommandId: <String, List<CockpitCommandResult>>{
            'has-item': <CockpitCommandResult>[
              _result(
                commandId: 'has-item',
                commandType: CockpitCommandType.assertText,
              ),
              _result(
                commandId: 'has-item',
                commandType: CockpitCommandType.assertText,
              ),
              _result(
                commandId: 'has-item',
                commandType: CockpitCommandType.assertText,
                success: false,
              ),
            ],
            'tap-delete': <CockpitCommandResult>[
              _result(commandId: 'tap-delete'),
              _result(commandId: 'tap-delete'),
            ],
          },
        );
        final runner = CockpitControlRunner(
          automationAdapter: adapter,
          sessionController: CockpitSessionController(
            sessionId: 'workflow-loop',
            taskId: 'workflow-loop-task',
            platform: 'android',
            now: () => DateTime.utc(2026, 6, 15, 9),
          ),
        );

        final runResult = await runner.run(
          environment: _environment(),
          workflowSteps: <CockpitWorkflowStep>[
            CockpitLoopWorkflowStep(
              stepId: 'delete-items',
              maxIterations: 5,
              condition: CockpitCommand(
                commandId: 'has-item',
                commandType: CockpitCommandType.assertText,
                parameters: const <String, Object?>{'text': 'Delete'},
              ),
              steps: <CockpitWorkflowStep>[
                CockpitCommandWorkflowStep(
                  stepId: 'delete-current',
                  command: CockpitCommand(
                    commandId: 'tap-delete',
                    commandType: CockpitCommandType.tap,
                    locator: const CockpitLocator(text: 'Delete'),
                  ),
                ),
              ],
            ),
          ],
        );

        expect(adapter.executedCommandIds, <String>[
          'has-item',
          'tap-delete',
          'has-item',
          'tap-delete',
          'has-item',
        ]);
        expect(runResult.bundle.manifest.status, CockpitTaskStatus.completed);
        final loopRecords = runResult.bundle.steps
            .where((step) => step.actionType == 'workflow_loop_iteration')
            .toList(growable: false);
        expect(loopRecords, hasLength(3));
        expect(loopRecords.last.actionArgs['conditionSuccess'], false);
        expect(loopRecords.last.actionArgs['iteration'], 3);
      },
    );

    test('retries a failing child step until it succeeds', () async {
      final adapter = _FakeAutomationAdapter.sequence(
        capabilities: _capabilities(),
        resultsByCommandId: <String, List<CockpitCommandResult>>{
          'assert-ready': <CockpitCommandResult>[
            _result(
              commandId: 'assert-ready',
              commandType: CockpitCommandType.assertText,
              success: false,
              message: 'Not ready yet.',
            ),
            _result(
              commandId: 'assert-ready',
              commandType: CockpitCommandType.assertText,
            ),
          ],
        },
      );
      final runner = CockpitControlRunner(
        automationAdapter: adapter,
        sessionController: CockpitSessionController(
          sessionId: 'workflow-retry',
          taskId: 'workflow-retry-task',
          platform: 'android',
          now: () => DateTime.utc(2026, 6, 15, 10),
        ),
      );

      final runResult = await runner.run(
        environment: _environment(),
        workflowSteps: <CockpitWorkflowStep>[
          CockpitRetryWorkflowStep(
            stepId: 'wait-ready',
            maxAttempts: 3,
            delayMs: 0,
            step: CockpitCommandWorkflowStep(
              stepId: 'assert-ready-step',
              command: CockpitCommand(
                commandId: 'assert-ready',
                commandType: CockpitCommandType.assertText,
                parameters: const <String, Object?>{'text': 'Ready'},
              ),
            ),
          ),
        ],
      );

      expect(adapter.executedCommandIds, <String>[
        'assert-ready',
        'assert-ready',
      ]);
      expect(runResult.bundle.manifest.status, CockpitTaskStatus.completed);
      final attempts = runResult.bundle.steps
          .where((step) => step.actionType == 'workflow_retry_attempt')
          .toList(growable: false);
      expect(attempts, hasLength(2));
      expect(attempts.first.actionArgs['success'], false);
      expect(attempts.last.actionArgs['success'], true);
      expect(
        runResult.bundle.steps.last.status,
        CockpitCommandStatus.succeeded,
      );
    });

    test(
      'fails a bounded retry after the final unsuccessful attempt',
      () async {
        final adapter = _FakeAutomationAdapter.sequence(
          capabilities: _capabilities(),
          resultsByCommandId: <String, List<CockpitCommandResult>>{
            'assert-ready': <CockpitCommandResult>[
              _result(
                commandId: 'assert-ready',
                commandType: CockpitCommandType.assertText,
                success: false,
                message: 'Not ready 1.',
              ),
              _result(
                commandId: 'assert-ready',
                commandType: CockpitCommandType.assertText,
                success: false,
                message: 'Not ready 2.',
              ),
            ],
          },
        );
        final runner = CockpitControlRunner(
          automationAdapter: adapter,
          sessionController: CockpitSessionController(
            sessionId: 'workflow-retry-fail',
            taskId: 'workflow-retry-fail-task',
            platform: 'android',
            now: () => DateTime.utc(2026, 6, 15, 11),
          ),
        );

        final runResult = await runner.run(
          environment: _environment(),
          workflowSteps: <CockpitWorkflowStep>[
            CockpitRetryWorkflowStep(
              stepId: 'wait-ready',
              maxAttempts: 2,
              delayMs: 0,
              step: CockpitCommandWorkflowStep(
                stepId: 'assert-ready-step',
                command: CockpitCommand(
                  commandId: 'assert-ready',
                  commandType: CockpitCommandType.assertText,
                  parameters: const <String, Object?>{'text': 'Ready'},
                ),
              ),
            ),
          ],
        );

        expect(adapter.executedCommandIds, <String>[
          'assert-ready',
          'assert-ready',
        ]);
        expect(runResult.bundle.manifest.status, CockpitTaskStatus.failed);
        expect(
          runResult.bundle.manifest.failureSummary,
          contains('Not ready 2.'),
        );
        expect(runResult.bundle.manifest.failureCount, 1);
        final commandRecords = runResult.bundle.steps
            .where((step) => step.commandType == CockpitCommandType.assertText)
            .toList(growable: false);
        expect(commandRecords, hasLength(1));
        expect(commandRecords.single.status, CockpitCommandStatus.failed);
      },
    );
  });

  test(
    'queries capabilities, records results, and returns a completed bundle',
    () async {
      final adapter = _FakeAutomationAdapter(
        capabilities: CockpitCapabilities(
          platform: 'android',
          transportType: 'inApp',
          supportsInAppControl: true,
          supportsFlutterViewCapture: true,
          supportsNativeScreenCapture: false,
          supportsHostAutomation: false,
          supportedCommands: const [
            CockpitCommandType.tap,
            CockpitCommandType.captureScreenshot,
          ],
          supportedLocatorStrategies: const [CockpitLocatorKind.cockpitId],
        ),
        resultsByCommandId: <String, CockpitCommandResult>{
          'cmd-open': CockpitCommandResult(
            success: true,
            commandId: 'cmd-open',
            commandType: CockpitCommandType.tap,
            locatorResolution: const CockpitLocatorResolution(
              matchedKind: CockpitLocatorKind.cockpitId,
              matchedValue: 'open_form_button',
            ),
            durationMs: 25,
            snapshot: const {'routeName': '/home', 'visibleTargets': []},
          ),
        },
      );
      final captureAdapter = _FakeCaptureAdapter(
        executionByCommandId: <String, CockpitCommandExecution>{
          'cmd-capture': CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: 'cmd-capture',
              commandType: CockpitCommandType.captureScreenshot,
              durationMs: 12,
              artifacts: const [
                CockpitArtifactRef(
                  role: 'screenshot',
                  relativePath: 'screenshots/home_acceptance.png',
                ),
              ],
              snapshot: const {'routeName': '/home', 'visibleTargets': []},
            ),
            artifactPayloads: const <String, List<int>>{
              'screenshots/home_acceptance.png': <int>[1, 2, 3],
            },
          ),
        },
      );
      var tick = 0;
      final sessionController = CockpitSessionController(
        sessionId: 'runner-session',
        taskId: 'runner-task',
        platform: 'android',
        now: () => DateTime.utc(2026, 3, 20, 10, 0, tick++),
      );
      final runner = CockpitControlRunner(
        automationAdapter: adapter,
        captureAdapter: captureAdapter,
        sessionController: sessionController,
      );

      final runResult = await runner.run(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        commands: <CockpitCommand>[
          CockpitCommand(
            commandId: 'cmd-open',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(cockpitId: 'open_form_button'),
          ),
          CockpitCommand(
            commandId: 'cmd-capture',
            commandType: CockpitCommandType.captureScreenshot,
            screenshotRequest: const CockpitScreenshotRequest(
              reason: CockpitScreenshotReason.acceptance,
              name: 'home',
              includeSnapshot: true,
              attachToStep: true,
            ),
          ),
        ],
      );
      final bundle = runResult.bundle;

      expect(adapter.describeCapabilitiesCallCount, 1);
      expect(adapter.executedCommandIds, <String>['cmd-open']);
      expect(captureAdapter.capturedCommandIds, <String>['cmd-capture']);
      expect(
        runResult.artifactPayloads['screenshots/home_acceptance.png'],
        <int>[1, 2, 3],
      );
      expect(bundle.manifest.status, CockpitTaskStatus.completed);
      expect(bundle.manifest.commandCount, 2);
      expect(bundle.manifest.screenshotCount, 1);
      expect(
        bundle.manifest.capabilitiesUsed,
        containsAll(<String>['inAppControl', 'flutterViewCapture']),
      );
      expect(bundle.steps, hasLength(2));
      expect(
        bundle.steps.last.captureRefs.single.relativePath,
        contains('.png'),
      );
    },
  );

  test('applies AI evidence defaults before executing key commands', () async {
    final adapter = _FakeAutomationAdapter(
      capabilities: CockpitCapabilities(
        platform: 'android',
        transportType: 'remoteHttp',
        supportsInAppControl: true,
        supportsFlutterViewCapture: true,
        supportsNativeScreenCapture: false,
        supportsHostAutomation: false,
        supportedCommands: const [
          CockpitCommandType.tap,
          CockpitCommandType.assertText,
        ],
        supportedLocatorStrategies: const [CockpitLocatorKind.cockpitId],
      ),
      resultsByCommandId: <String, CockpitCommandResult>{
        'cmd-open': CockpitCommandResult(
          success: true,
          commandId: 'cmd-open',
          commandType: CockpitCommandType.tap,
          durationMs: 12,
          artifacts: const [
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/cmd-open_afterAction.png',
            ),
          ],
          requestedCaptureProfile: CockpitCaptureProfile.flutterPreferred,
          resolvedCaptureKind: CockpitCaptureKind.flutterView,
        ),
        'cmd-assert': CockpitCommandResult(
          success: true,
          commandId: 'cmd-assert',
          commandType: CockpitCommandType.assertText,
          durationMs: 8,
        ),
      },
    );
    final runner = CockpitControlRunner(
      automationAdapter: adapter,
      sessionController: CockpitSessionController(
        sessionId: 'runner-evidence-defaults',
        taskId: 'runner-evidence-defaults-task',
        platform: 'android',
        now: () => DateTime.utc(2026, 3, 24, 12),
      ),
    );

    final runResult = await runner.run(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      commands: <CockpitCommand>[
        CockpitCommand(
          commandId: 'cmd-open',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(cockpitId: 'open_form_button'),
        ),
        CockpitCommand(
          commandId: 'cmd-assert',
          commandType: CockpitCommandType.assertText,
          parameters: const <String, Object?>{'text': 'Ready'},
        ),
      ],
    );

    expect(adapter.executedCommands, hasLength(2));
    expect(
      adapter.executedCommands.first.capturePolicy,
      CockpitCapturePolicy.afterAction,
    );
    expect(
      adapter.executedCommands.first.captureFailurePolicy,
      CockpitCaptureFailurePolicy.degradeCommand,
    );
    expect(
      adapter.executedCommands.first.screenshotRequest?.toJson(),
      <String, Object?>{
        'reason': 'after_action',
        'name': 'cmd-open',
        'includeSnapshot': false,
        'attachToStep': true,
      },
    );
    expect(
      adapter.executedCommands.last.capturePolicy,
      CockpitCapturePolicy.none,
    );
    expect(
      adapter.executedCommands.last.captureFailurePolicy,
      CockpitCaptureFailurePolicy.failCommand,
    );
    expect(runResult.bundle.manifest.screenshotCount, 1);
    expect(
      runResult.bundle.steps.first.captureRefs.single.relativePath,
      'screenshots/cmd-open_afterAction.png',
    );
  });

  test('stops on the first hard failure when failFast is enabled', () async {
    final adapter = _FakeAutomationAdapter(
      capabilities: CockpitCapabilities(
        platform: 'ios',
        transportType: 'inApp',
        supportsInAppControl: true,
        supportsFlutterViewCapture: false,
        supportsNativeScreenCapture: false,
        supportsHostAutomation: false,
        supportedCommands: const [CockpitCommandType.tap],
        supportedLocatorStrategies: const [CockpitLocatorKind.cockpitId],
      ),
      resultsByCommandId: <String, CockpitCommandResult>{
        'cmd-first': CockpitCommandResult(
          success: false,
          commandId: 'cmd-first',
          commandType: CockpitCommandType.tap,
          durationMs: 10,
          error: CockpitCommandError.targetNotFound(
            message: 'open_form_button was not found.',
          ),
        ),
        'cmd-second': CockpitCommandResult(
          success: true,
          commandId: 'cmd-second',
          commandType: CockpitCommandType.tap,
          durationMs: 10,
        ),
      },
    );
    var tick = 0;
    final runner = CockpitControlRunner(
      automationAdapter: adapter,
      sessionController: CockpitSessionController(
        sessionId: 'runner-session-fail',
        taskId: 'runner-task-fail',
        platform: 'ios',
        now: () => DateTime.utc(2026, 3, 20, 10, 10, tick++),
      ),
      failFast: true,
    );

    final runResult = await runner.run(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      commands: <CockpitCommand>[
        CockpitCommand(
          commandId: 'cmd-first',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(cockpitId: 'open_form_button'),
        ),
        CockpitCommand(
          commandId: 'cmd-second',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(cockpitId: 'submit_button'),
        ),
      ],
    );
    final bundle = runResult.bundle;

    expect(adapter.executedCommandIds, <String>['cmd-first']);
    expect(bundle.manifest.status, CockpitTaskStatus.failed);
    expect(bundle.steps, hasLength(1));
    expect(bundle.manifest.failureSummary, contains('open_form_button'));
  });

  test('imports runtime steps emitted by the running app', () async {
    final adapter = _FakeAutomationAdapter(
      capabilities: CockpitCapabilities(
        platform: 'android',
        transportType: 'remoteHttp',
        supportsInAppControl: true,
        supportsFlutterViewCapture: true,
        supportsNativeScreenCapture: false,
        supportsHostAutomation: false,
        supportedCommands: const [CockpitCommandType.tap],
        supportedLocatorStrategies: const [CockpitLocatorKind.text],
      ),
      executionsByCommandId: <String, CockpitCommandExecution>{
        'cmd-save': CockpitCommandExecution(
          result: CockpitCommandResult(
            success: false,
            commandId: 'cmd-save',
            commandType: CockpitCommandType.tap,
            durationMs: 48,
            error: CockpitCommandError.assertionFailed(
              message: 'Task title is required.',
            ),
          ),
          runtimeSteps: <CockpitStepRecord>[
            CockpitStepRecord(
              index: 0,
              actionType: 'validation_error',
              actionArgs: const <String, Object?>{
                'message': 'Task title is required.',
                'field': 'title',
              },
              observedAt: DateTime.utc(2026, 3, 21, 13, 0, 0),
            ),
          ],
        ),
      },
    );
    final sessionController = CockpitSessionController(
      sessionId: 'runner-runtime-steps',
      taskId: 'runner-runtime-steps-task',
      platform: 'android',
      now: () => DateTime.utc(2026, 3, 21, 13, 0, 30),
    );
    final runner = CockpitControlRunner(
      automationAdapter: adapter,
      sessionController: sessionController,
      failFast: true,
    );

    final runResult = await runner.run(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      commands: <CockpitCommand>[
        CockpitCommand(
          commandId: 'cmd-save',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(text: 'Save task'),
        ),
      ],
    );

    expect(runResult.bundle.steps, hasLength(2));
    expect(runResult.bundle.steps.first.actionType, 'validation_error');
    expect(runResult.bundle.steps.last.actionType, 'tap');
    expect(runResult.bundle.manifest.failureSummary, contains('required'));
  });

  test(
    'uses the recording request tail stabilization delay before stopping capture',
    () async {
      final adapter = _FakeAutomationAdapter(
        capabilities: CockpitCapabilities(
          platform: 'android',
          transportType: 'remoteHttp',
          supportsInAppControl: true,
          supportsFlutterViewCapture: true,
          supportsNativeScreenCapture: true,
          supportsHostAutomation: false,
          supportedCommands: const [CockpitCommandType.tap],
          supportedLocatorStrategies: const [CockpitLocatorKind.key],
        ),
        resultsByCommandId: <String, CockpitCommandResult>{
          'cmd-finish': CockpitCommandResult(
            success: true,
            commandId: 'cmd-finish',
            commandType: CockpitCommandType.tap,
            durationMs: 10,
          ),
        },
      );
      final recordingAdapter = _FakeRecordingAdapter();
      final configuredTailDelay = const Duration(milliseconds: 80);
      final fallbackTailDelay = const Duration(milliseconds: 12);
      final stopwatch = Stopwatch()..start();
      final runner = CockpitControlRunner(
        automationAdapter: adapter,
        recordingAdapter: recordingAdapter,
        sessionController: CockpitSessionController(
          sessionId: 'runner-recording-tail',
          taskId: 'runner-recording-tail-task',
          platform: 'android',
          now: () => DateTime.utc(2026, 3, 22, 0, 0),
        ),
        recordingStopSettleDelay: fallbackTailDelay,
      );

      await runner.run(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        commands: <CockpitCommand>[
          CockpitCommand(
            commandId: 'cmd-finish',
            commandType: CockpitCommandType.tap,
            locator: const CockpitLocator(key: 'settings-save-button'),
          ),
        ],
        recording: CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'acceptance-tail',
          tailStabilizationDelay: configuredTailDelay,
        ),
      );

      stopwatch.stop();
      expect(recordingAdapter.startCallCount, 1);
      expect(recordingAdapter.stopCallCount, 1);
      expect(
        recordingAdapter.stopElapsed,
        isNotNull,
        reason: 'stopRecording should have been invoked.',
      );
      expect(
        recordingAdapter.stopElapsed!,
        greaterThanOrEqualTo(configuredTailDelay),
      );
      expect(stopwatch.elapsed, greaterThanOrEqualTo(configuredTailDelay));
    },
  );
}

final class _FakeAutomationAdapter implements CockpitAutomationAdapter {
  _FakeAutomationAdapter({
    required this.capabilities,
    Map<String, CockpitCommandResult>? resultsByCommandId,
    Map<String, CockpitCommandExecution>? executionsByCommandId,
  }) : _resultsByCommandId = resultsByCommandId,
       _executionsByCommandId = executionsByCommandId;

  _FakeAutomationAdapter.sequence({
    required this.capabilities,
    required Map<String, List<CockpitCommandResult>> resultsByCommandId,
  }) : _resultsByCommandId = null,
       _executionsByCommandId = null,
       _resultSequencesByCommandId = resultsByCommandId.map(
         (key, value) => MapEntry<String, List<CockpitCommandResult>>(
           key,
           value.toList(growable: true),
         ),
       );

  final CockpitCapabilities capabilities;
  final Map<String, CockpitCommandResult>? _resultsByCommandId;
  final Map<String, CockpitCommandExecution>? _executionsByCommandId;
  Map<String, List<CockpitCommandResult>>? _resultSequencesByCommandId;
  final List<String> executedCommandIds = <String>[];
  final List<CockpitCommand> executedCommands = <CockpitCommand>[];
  int describeCapabilitiesCallCount = 0;

  @override
  Future<CockpitCapabilities> describeCapabilities() async {
    describeCapabilitiesCallCount += 1;
    return capabilities;
  }

  @override
  Future<CockpitCommandExecution> execute(CockpitCommand command) async {
    executedCommandIds.add(command.commandId);
    executedCommands.add(command);
    final execution = _executionsByCommandId?[command.commandId];
    if (execution != null) {
      return execution;
    }
    final sequence = _resultSequencesByCommandId?[command.commandId];
    if (sequence != null && sequence.isNotEmpty) {
      return CockpitCommandExecution(result: sequence.removeAt(0));
    }
    return CockpitCommandExecution(
      result: _resultsByCommandId![command.commandId]!,
    );
  }
}

CockpitCapabilities _capabilities() {
  return CockpitCapabilities(
    platform: 'android',
    transportType: 'remoteHttp',
    supportsInAppControl: true,
    supportsFlutterViewCapture: true,
    supportsNativeScreenCapture: true,
    supportsHostAutomation: false,
    supportedCommands: const <CockpitCommandType>[
      CockpitCommandType.tap,
      CockpitCommandType.assertText,
      CockpitCommandType.captureScreenshot,
    ],
    supportedLocatorStrategies: const <CockpitLocatorKind>[
      CockpitLocatorKind.text,
      CockpitLocatorKind.cockpitId,
      CockpitLocatorKind.key,
    ],
  );
}

CockpitEnvironment _environment() {
  return const CockpitEnvironment(
    platform: 'android',
    flutterVersion: '3.38.9',
    dartVersion: '3.10.8',
  );
}

CockpitCommandResult _result({
  required String commandId,
  CockpitCommandType commandType = CockpitCommandType.tap,
  bool success = true,
  String? message,
}) {
  return CockpitCommandResult(
    success: success,
    commandId: commandId,
    commandType: commandType,
    durationMs: 10,
    error: success
        ? null
        : CockpitCommandError.assertionFailed(
            message: message ?? '$commandId did not match.',
          ),
  );
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  _FakeCaptureAdapter({
    required Map<String, CockpitCommandExecution> executionByCommandId,
  }) : _executionByCommandId = executionByCommandId;

  final Map<String, CockpitCommandExecution> _executionByCommandId;
  final List<String> capturedCommandIds = <String>[];

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    capturedCommandIds.add(command.commandId);
    return _executionByCommandId[command.commandId]!;
  }
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  int startCallCount = 0;
  int stopCallCount = 0;
  Stopwatch? _stopwatch;
  Duration? stopElapsed;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    startCallCount += 1;
    _stopwatch = Stopwatch()..start();
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    stopCallCount += 1;
    _stopwatch?.stop();
    stopElapsed = _stopwatch?.elapsed;
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: CockpitRecordingPurpose.acceptance,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: cockpitRecordingArtifactForName('acceptance-tail'),
      sourceFilePath: '/tmp/acceptance-tail.mp4',
    );
  }
}
