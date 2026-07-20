import 'dart:async';
import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';

import '../support/cockpit_case_runner_test_support.dart';
import '../support/cockpit_case_runtime_test_support.dart';

void main() {
  test('residual recording is stopped and indexed inside cleanup', () async {
    final root = await Directory.systemTemp.createTemp('cockpit-v2-recording-');
    addTearDown(() => root.delete(recursive: true));
    final recording = _RecordingAdapter();
    final compiled = const CockpitTestDocumentCompiler()
        .compile(_recordingCase())
        .requireCompiled();
    final context = CockpitTestRunContext(
      projectId: 'projectOne',
      workspaceId: 'workspaceOne',
      runId: 'runOne',
      caseId: 'recordingCase',
      attemptId: 'attemptOne',
      engineVersion: '2.0.0',
    );
    final result =
        await CockpitCaseRunner(
          automationAdapter: RecordingAutomationAdapter(),
          recordingAdapter: recording,
          secretResolver: RecordingSecretResolver('unused'),
          safetyPolicy: RecordingSafetyPolicy(),
          clock: ManualCockpitClock(),
        ).run(
          compiled: compiled,
          context: context,
          targetId: 'emulatorOne',
          targetEnvironment: CockpitTestTargetEnvironment.test,
          reportRoot: root.path,
        );

    expect(result.outcome, CockpitTestOutcome.passed);
    expect(recording.startRequests.single.allowFallback, isFalse);
    expect(recording.startRequests.single.attachToStep, isFalse);
    expect(recording.stopCount, 1);
    final residual = result.steps.singleWhere(
      (step) => step.stepId == 'residualRecording',
    );
    expect(residual.section, 'finally');
    expect(residual.status, CockpitTestStepStatus.passed);
    expect(residual.evidence, hasLength(1));
    final manifest = await const CockpitTestAttemptBundleReader().readAndVerify(
      path: result.bundlePath!,
    );
    expect(manifest.artifacts.single.stepExecutionId, residual.executionId);
  });

  test(
    'residual recording timeout still publishes a complete report',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cockpit-v2-recording-timeout-',
      );
      addTearDown(() => root.delete(recursive: true));
      final clock = ManualCockpitClock();
      final recording = _HangingRecordingAdapter();
      addTearDown(recording.completeStop);
      final future =
          CockpitCaseRunner(
            automationAdapter: RecordingAutomationAdapter(),
            recordingAdapter: recording,
            secretResolver: RecordingSecretResolver('unused'),
            safetyPolicy: RecordingSafetyPolicy(),
            clock: clock,
          ).run(
            compiled: const CockpitTestDocumentCompiler()
                .compile(_recordingCase(cleanupTimeoutMs: 50))
                .requireCompiled(),
            context: CockpitTestRunContext(
              projectId: 'projectOne',
              workspaceId: 'workspaceOne',
              runId: 'runOne',
              caseId: 'recordingCase',
              attemptId: 'attemptOne',
              engineVersion: '2.0.0',
            ),
            targetId: 'emulatorOne',
            targetEnvironment: CockpitTestTargetEnvironment.test,
            reportRoot: root.path,
          );
      for (var index = 0; index < 20 && recording.stopCount == 0; index += 1) {
        await Future<void>.value();
      }
      expect(recording.stopCount, 1);

      clock.elapse(const Duration(milliseconds: 50));
      final result = await future;

      expect(result.outcome, CockpitTestOutcome.failed);
      final residual = result.steps.singleWhere(
        (step) => step.stepId == 'residualRecording',
      );
      expect(residual.status, CockpitTestStepStatus.failed);
      expect(residual.error?.code, CockpitTestErrorCode.timeout);
      final manifest = await const CockpitTestAttemptBundleReader()
          .readAndVerify(path: result.bundlePath!);
      expect(manifest.artifacts, isEmpty);
    },
  );
}

final class _RecordingAdapter implements CockpitRecordingAdapter {
  final List<CockpitRecordingRequest> startRequests =
      <CockpitRecordingRequest>[];
  var stopCount = 0;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    startRequests.add(request);
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    stopCount += 1;
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/acceptance.mp4',
      ),
      bytes: const <int>[0, 1, 2, 3],
    );
  }
}

final class _HangingRecordingAdapter implements CockpitRecordingAdapter {
  final Completer<CockpitRecordingResult> _stop =
      Completer<CockpitRecordingResult>();
  var stopCount = 0;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async => CockpitRecordingSession(
    request: request,
    state: CockpitRecordingState.recording,
  );

  @override
  Future<CockpitRecordingResult> stopRecording() {
    stopCount += 1;
    return _stop.future;
  }

  void completeStop() {
    if (!_stop.isCompleted) {
      _stop.complete(
        CockpitRecordingResult(state: CockpitRecordingState.completed),
      );
    }
  }
}

String _recordingCase({int? cleanupTimeoutMs}) =>
    '''
schemaVersion: cockpit.test/v2
kind: case
id: recordingCase
target: {platform: android, targetKind: flutterApp, plane: semantic}
${cleanupTimeoutMs == null ? '' : 'defaults: {cleanupTimeoutMs: $cleanupTimeoutMs}'}
setup:
  - stepId: startRecording
    startRecording:
      name: acceptanceRun
      purpose: acceptance
      mode: auto
      allowFallback: false
      attachToStep: false
steps:
  - {stepId: goBack, action: {type: back}}
''';
