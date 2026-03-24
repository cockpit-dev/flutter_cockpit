import '../capture/cockpit_capture_kind.dart';
import '../capture/cockpit_capture_profile.dart';
import '../control/cockpit_command_status.dart';
import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../model/cockpit_artifact_ref.dart';
import '../model/cockpit_observation.dart';
import '../model/cockpit_step_record.dart';
import 'cockpit_snapshot.dart';

typedef CockpitRuntimeStepTimestampProvider = DateTime Function();

final class CockpitRuntimeStepBuffer {
  CockpitRuntimeStepBuffer({CockpitRuntimeStepTimestampProvider? now})
      : _now = now ?? _systemNow;

  final CockpitRuntimeStepTimestampProvider _now;
  final List<CockpitStepRecord> _steps = <CockpitStepRecord>[];

  void recordStep({
    required String actionType,
    required Map<String, Object?> actionArgs,
    CockpitObservation? observation,
    CockpitSnapshot? snapshot,
    List<CockpitArtifactRef> artifactRefs = const [],
    CockpitCommandType? commandType,
    CockpitLocator? locator,
    CockpitLocatorResolution? locatorResolution,
    int? durationMs,
    CockpitCommandStatus? status,
    CockpitCaptureProfile? requestedCaptureProfile,
    CockpitCaptureKind? resolvedCaptureKind,
    bool usedCaptureFallback = false,
    String? degradationReason,
    List<CockpitArtifactRef> captureRefs = const [],
  }) {
    _steps.add(
      CockpitStepRecord(
        index: _steps.length,
        actionType: actionType,
        actionArgs: actionArgs,
        observedAt: _now().toUtc(),
        observation: observation,
        snapshot: snapshot,
        artifactRefs: artifactRefs,
        commandType: commandType,
        locator: locator,
        locatorResolution: locatorResolution,
        durationMs: durationMs,
        status: status,
        requestedCaptureProfile: requestedCaptureProfile,
        resolvedCaptureKind: resolvedCaptureKind,
        usedCaptureFallback: usedCaptureFallback,
        degradationReason: degradationReason,
        captureRefs: captureRefs,
      ),
    );
  }

  List<CockpitStepRecord> drain({bool clear = true}) {
    final drained = List<CockpitStepRecord>.unmodifiable(
      _steps.map(_copyStepRecord),
    );
    if (clear) {
      _steps.clear();
    }
    return drained;
  }

  void clear() {
    _steps.clear();
  }

  static DateTime _systemNow() => DateTime.now();

  static CockpitStepRecord _copyStepRecord(CockpitStepRecord step) {
    return CockpitStepRecord(
      index: step.index,
      actionType: step.actionType,
      actionArgs: step.actionArgs,
      observedAt: step.observedAt,
      observation: step.observation,
      snapshot: step.snapshot,
      artifactRefs: step.artifactRefs,
      commandType: step.commandType,
      locator: step.locator,
      locatorResolution: step.locatorResolution,
      durationMs: step.durationMs,
      status: step.status,
      requestedCaptureProfile: step.requestedCaptureProfile,
      resolvedCaptureKind: step.resolvedCaptureKind,
      usedCaptureFallback: step.usedCaptureFallback,
      degradationReason: step.degradationReason,
      captureRefs: step.captureRefs,
    );
  }
}
