import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
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
        'includeSnapshot': true,
        'attachToStep': true,
        'snapshotOptions': const CockpitSnapshotOptions.live().toJson(),
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

  final CockpitCapabilities capabilities;
  final Map<String, CockpitCommandResult>? _resultsByCommandId;
  final Map<String, CockpitCommandExecution>? _executionsByCommandId;
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
    return CockpitCommandExecution(
      result: _resultsByCommandId![command.commandId]!,
    );
  }
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
