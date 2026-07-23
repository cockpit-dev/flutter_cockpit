import 'dart:async';

enum CockpitWorkerCaseCompletionPhase {
  intentPersisted,
  eventsReconciled,
  completionCommitted,
}

final class CockpitWorkerCaseCompletionObservation {
  const CockpitWorkerCaseCompletionObservation({
    required this.phase,
    required this.idempotencyKey,
    required this.runId,
    required this.caseId,
    required this.attemptId,
    required this.intentId,
    required this.recovering,
  });

  final CockpitWorkerCaseCompletionPhase phase;
  final String idempotencyKey;
  final String runId;
  final String caseId;
  final String attemptId;
  final String intentId;
  final bool recovering;
}

typedef CockpitWorkerCaseCompletionObserver =
    FutureOr<void> Function(CockpitWorkerCaseCompletionObservation observation);

Future<void> notifyCockpitWorkerCaseCompletion(
  CockpitWorkerCaseCompletionObserver? observer,
  CockpitWorkerCaseCompletionObservation observation,
) async {
  if (observer == null) return;
  try {
    await observer(observation);
  } on Object {
    // Telemetry cannot change the durable completion state machine.
  }
}
