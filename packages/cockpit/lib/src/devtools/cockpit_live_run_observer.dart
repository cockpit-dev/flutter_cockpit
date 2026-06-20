import 'dart:async';

import 'cockpit_live_run_store.dart';

abstract interface class CockpitLiveRunObserver {
  void record(CockpitLiveRunEventDraft event);

  Future<void> flush();
}

final class CockpitLiveRunEventDraft {
  const CockpitLiveRunEventDraft({
    required this.type,
    required this.status,
    this.stage,
    this.workflowStepId,
    this.workflowStepType,
    this.description,
    this.commandId,
    this.commandType,
    this.artifactRefs = const <Map<String, Object?>>[],
    this.captureRefs = const <Map<String, Object?>>[],
    this.error,
    this.bundleDir,
    this.recommendedNextStep,
    this.details = const <String, Object?>{},
  });

  final String type;
  final String status;
  final String? stage;
  final String? workflowStepId;
  final String? workflowStepType;
  final String? description;
  final String? commandId;
  final String? commandType;
  final List<Map<String, Object?>> artifactRefs;
  final List<Map<String, Object?>> captureRefs;
  final Map<String, Object?>? error;
  final String? bundleDir;
  final String? recommendedNextStep;
  final Map<String, Object?> details;
}

final class CockpitLiveRunStoreObserver implements CockpitLiveRunObserver {
  CockpitLiveRunStoreObserver({
    required CockpitLiveRunStore store,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _store = store,
       _onError = onError;

  final CockpitLiveRunStore _store;
  final void Function(Object error, StackTrace stackTrace)? _onError;
  Future<void> _pending = Future<void>.value();

  @override
  void record(CockpitLiveRunEventDraft event) {
    _pending = _pending
        .then(
          (_) => _store.appendEvent(
            type: event.type,
            status: event.status,
            stage: event.stage,
            workflowStepId: event.workflowStepId,
            workflowStepType: event.workflowStepType,
            description: event.description,
            commandId: event.commandId,
            commandType: event.commandType,
            artifactRefs: event.artifactRefs,
            captureRefs: event.captureRefs,
            error: event.error,
            bundleDir: event.bundleDir,
            recommendedNextStep: event.recommendedNextStep,
            details: event.details,
          ),
        )
        .then<void>((_) {})
        .catchError((Object error, StackTrace stackTrace) {
          _onError?.call(error, stackTrace);
        });
  }

  @override
  Future<void> flush() => _pending;
}
