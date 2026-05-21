import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_task_service.dart';

final class CockpitLatestTaskSnapshot {
  const CockpitLatestTaskSnapshot({
    required this.recordedAt,
    required this.classification,
    required this.recommendedNextStep,
    this.blockedReason,
    this.warnings = const <String>[],
    this.bundleSummary,
  });

  final DateTime recordedAt;
  final CockpitRunTaskClassification classification;
  final String recommendedNextStep;
  final String? blockedReason;
  final List<String> warnings;
  final CockpitReadTaskBundleSummaryResult? bundleSummary;

  Map<String, Object?> toJson() => <String, Object?>{
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'classification': classification.jsonValue,
        'recommendedNextStep': recommendedNextStep,
        'blockedReason': blockedReason,
        if (warnings.isNotEmpty) 'warnings': warnings,
        if (bundleSummary != null) 'bundleSummary': bundleSummary!.toJson(),
      };
}

final class CockpitLatestTaskStore {
  CockpitLatestTaskStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  CockpitLatestTaskSnapshot? _latest;

  CockpitLatestTaskSnapshot? get latest => _latest;

  void recordRunTask(CockpitRunTaskResult result) {
    _latest = CockpitLatestTaskSnapshot(
      recordedAt: _now().toUtc(),
      classification: result.classification,
      recommendedNextStep: result.recommendedNextStep,
      blockedReason: result.blockedReason,
      warnings: result.warnings,
      bundleSummary: result.bundleSummary,
    );
  }
}
