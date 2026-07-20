import 'dart:async';

import 'package:cockpit/src/artifacts/cockpit_test_attempt_recorder.dart';
import 'package:cockpit/src/runner/cockpit_case_execution_control.dart';
import 'package:cockpit/src/runner/cockpit_case_execution_kernel.dart';
import 'package:cockpit/src/test/cockpit_test_execution_plan.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';
import 'package:cockpit/src/runner/cockpit_case_operation_lease.dart';

import '../support/cockpit_case_runtime_test_support.dart';

void main() {
  test(
    'operation lease rejects late commits and requests abort once',
    () async {
      var abortCount = 0;
      final lease = CockpitCaseOperationLease()
        ..registerAbort(() async => abortCount += 1);

      expect(lease.tryCommit(() {}), isTrue);
      lease.revoke(requestAbort: true);
      lease.revoke(requestAbort: true);
      await _pump();

      expect(lease.isActive, isFalse);
      expect(lease.tryCommit(() {}), isFalse);
      expect(abortCount, 1);
    },
  );

  test('force abort is idempotent after cancellation grace expires', () async {
    final clock = ManualCockpitClock();
    var abortCount = 0;
    final control = CockpitCaseExecutionControl(
      cancellationGrace: const Duration(milliseconds: 20),
      forceAbort: () async => abortCount += 1,
    );
    final future = cockpitRacePrimaryControl<void>(
      operation: Completer<void>().future,
      control: control,
      clock: clock,
    );
    control.cancel();
    await _pump();
    clock.elapse(const Duration(milliseconds: 20));

    await expectLater(future, throwsA(isA<CockpitCaseCancelled>()));
    await control.forceAbortActive();
    await control.forceAbortActive();
    expect(abortCount, 1);
  });

  test('cancellation grace does not wait for force abort completion', () async {
    final clock = ManualCockpitClock();
    final abort = Completer<void>();
    addTearDown(() {
      if (!abort.isCompleted) abort.complete();
    });
    final control = CockpitCaseExecutionControl(
      cancellationGrace: const Duration(milliseconds: 20),
      forceAbort: () => abort.future,
    );
    var completed = false;
    Object? completionError;
    final future = cockpitRacePrimaryControl<void>(
      operation: Completer<void>().future,
      control: control,
      clock: clock,
    );
    future.then<void>(
      (_) => completed = true,
      onError: (Object error, StackTrace _) {
        completed = true;
        completionError = error;
      },
    );
    control.cancel();
    await _pump();
    clock.elapse(const Duration(milliseconds: 20));
    await _pump();

    expect(completed, isTrue);
    expect(completionError, isA<CockpitCaseCancelled>());
  });

  test(
    'hard shutdown interrupts cleanup and records unfinished work',
    () async {
      final clock = ManualCockpitClock();
      final delegate = DeterministicCaseDelegate();
      delegate.hangingActions['cleanupHang'] =
          Completer<CockpitTestKernelOperationResult>();
      final recorder = CockpitTestAttemptRecorder(clock: clock);
      final control = CockpitCaseExecutionControl();
      final future =
          CockpitCaseExecutionKernel(
            clock: clock,
            delegate: delegate,
            recorder: recorder,
          ).run(
            plan: testExecutionPlan(
              steps: <CockpitTestExecutionNode>[actionNode('main', 'main')],
              finallySteps: <CockpitTestExecutionNode>[
                actionNode('cleanupHang', 'finally'),
              ],
            ),
            control: control,
          );
      await _pump();
      expect(delegate.events, contains('action:cleanupHang:cleanup'));
      control.hardShutdown();
      final result = await future;

      expect(result.outcome, CockpitTestOutcome.cancelled);
      expect(result.primaryError?.code, CockpitTestErrorCode.hardShutdown);
      expect(
        result.cleanupErrors.map((error) => error.code),
        contains(CockpitTestErrorCode.hardShutdown),
      );
      expect(
        recorder.steps
            .singleWhere((step) => step.stepId == 'cleanupHang')
            .status,
        CockpitTestStepStatus.cancelled,
      );
      expect(delegate.events, isNot(contains('cleanup:residual')));
    },
  );
}

Future<void> _pump() async {
  await Future<void>.value();
  await Future<void>.value();
}
