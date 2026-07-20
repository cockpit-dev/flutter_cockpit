import 'dart:async';

enum CockpitRemovalPolicy { reject, drain, force }

final class CockpitReferenceCounts {
  const CockpitReferenceCounts({
    this.workspaces = 0,
    this.activeSessions = 0,
    this.activeRuns = 0,
    this.otherActive = 0,
    this.retainedRuns = 0,
    this.retainedArtifacts = 0,
  });

  final int workspaces;
  final int activeSessions;
  final int activeRuns;
  final int otherActive;
  final int retainedRuns;
  final int retainedArtifacts;

  int get activeTotal => workspaces + activeSessions + activeRuns + otherActive;
  int get retainedTotal => retainedRuns + retainedArtifacts;

  Map<String, int> get bounded => <String, int>{
    'workspaces': _bounded(workspaces),
    'activeSessions': _bounded(activeSessions),
    'activeRuns': _bounded(activeRuns),
    'otherActive': _bounded(otherActive),
    'retainedRuns': _bounded(retainedRuns),
    'retainedArtifacts': _bounded(retainedArtifacts),
  };

  static int _bounded(int value) => value.clamp(0, 9999);
}

final class CockpitRegistryException implements Exception {
  const CockpitRegistryException({
    required this.code,
    required this.message,
    this.referenceCounts = const CockpitReferenceCounts(),
  });

  final String code;
  final String message;
  final CockpitReferenceCounts referenceCounts;

  @override
  String toString() =>
      'CockpitRegistryException($code): $message '
      '${referenceCounts.bounded}';
}

abstract interface class CockpitRegistryActivityController {
  Future<void> drainWorkspaces(Set<String> workspaceIds, Duration timeout);

  Future<void> forceWorkspaces(Set<String> workspaceIds);
}

final class CockpitPassiveRegistryActivityController
    implements CockpitRegistryActivityController {
  const CockpitPassiveRegistryActivityController();

  @override
  Future<void> drainWorkspaces(
    Set<String> workspaceIds,
    Duration timeout,
  ) async {}

  @override
  Future<void> forceWorkspaces(Set<String> workspaceIds) async {}
}

abstract interface class CockpitRegistryReferenceOwner {
  Future<int> activeReferenceCount(String workspaceId);

  /// New-reference admission must hold the same root and workspace scopes,
  /// then verify registry authority before publishing the reference.
  Future<R> withAdmissionFence<R>(
    Set<String> rootIds,
    Set<String> workspaceIds,
    Future<R> Function() action,
  );
}

abstract final class CockpitRegistryAdmissionFences {
  static Future<R> run<R>(
    List<CockpitRegistryReferenceOwner> owners,
    Set<String> rootIds,
    Set<String> workspaceIds,
    Future<R> Function() action,
  ) {
    Future<R> enter(int index) {
      if (index == owners.length) return action();
      return owners[index].withAdmissionFence(
        rootIds,
        workspaceIds,
        () => enter(index + 1),
      );
    }

    return enter(0);
  }
}

final class CockpitWorkspaceRegistrationResult {
  const CockpitWorkspaceRegistrationResult({
    required this.workspaceId,
    required this.projectId,
    required this.checkoutId,
    required this.rootId,
    required this.canonicalPath,
    required this.disposition,
  });

  final String workspaceId;
  final String projectId;
  final String checkoutId;
  final String rootId;
  final String canonicalPath;
  final CockpitWorkspaceRegistrationDisposition disposition;
}

enum CockpitWorkspaceRegistrationDisposition {
  created,
  existing,
  moved,
  copied,
  reboundProject,
}

final class CockpitRetirementResult {
  const CockpitRetirementResult({
    required this.id,
    required this.tombstoneRetained,
    required this.referenceCounts,
  });

  final String id;
  final bool tombstoneRetained;
  final CockpitReferenceCounts referenceCounts;
}
