import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_registry_models.dart';
import 'cockpit_registry_records.dart';
import 'cockpit_registry_state.dart';

abstract final class CockpitRegistryInvariants {
  static CockpitReferenceCounts workspaceCounts(
    CockpitRegistryState state,
    String workspaceId, {
    int externalActive = 0,
  }) {
    final runs = state.runs.where((value) => value.workspaceId == workspaceId);
    return CockpitReferenceCounts(
      activeSessions: state.sessions
          .where((value) => value.workspaceId == workspaceId)
          .length,
      activeRuns: runs.where((value) => value.active).length,
      otherActive:
          state.otherReferences
              .where((value) => value.workspaceId == workspaceId)
              .length +
          externalActive,
      retainedRuns: runs.where((value) => value.retained).length,
      retainedArtifacts: runs.fold<int>(
        0,
        (total, value) => total + value.artifactCount,
      ),
    );
  }

  static CockpitReferenceCounts rootCounts(
    CockpitRegistryState state,
    String rootId, {
    Map<String, int> externalActive = const <String, int>{},
  }) {
    final workspaces = state.workspaces
        .where((value) => value.rootId == rootId)
        .toList();
    var sessions = 0;
    var activeRuns = 0;
    var other = 0;
    var retainedRuns = 0;
    var retainedArtifacts = 0;
    for (final workspace in workspaces) {
      final counts = workspaceCounts(
        state,
        workspace.workspaceId,
        externalActive: externalActive[workspace.workspaceId] ?? 0,
      );
      sessions += counts.activeSessions;
      activeRuns += counts.activeRuns;
      other += counts.otherActive;
      retainedRuns += counts.retainedRuns;
      retainedArtifacts += counts.retainedArtifacts;
    }
    return CockpitReferenceCounts(
      workspaces: workspaces
          .where((value) => value.state != CockpitWorkspaceState.retired)
          .length,
      activeSessions: sessions,
      activeRuns: activeRuns,
      otherActive: other,
      retainedRuns: retainedRuns,
      retainedArtifacts: retainedArtifacts,
    );
  }

  static void clearActiveReferences(
    CockpitRegistryState state,
    Set<String> workspaceIds,
  ) {
    state.sessions.removeWhere(
      (value) => workspaceIds.contains(value.workspaceId),
    );
    state.otherReferences.removeWhere(
      (value) => workspaceIds.contains(value.workspaceId),
    );
    for (var index = 0; index < state.runs.length; index += 1) {
      final run = state.runs[index];
      if (workspaceIds.contains(run.workspaceId) && run.active) {
        state.runs[index] = CockpitRunReferenceRecord(
          runId: run.runId,
          workspaceId: run.workspaceId,
          active: false,
          retained: run.retained,
          artifactCount: run.artifactCount,
        );
      }
    }
  }

  static void retireWorkspace(
    CockpitRegistryState state,
    String workspaceId,
    DateTime now,
  ) {
    final index = state.workspaces.indexWhere(
      (value) => value.workspaceId == workspaceId,
    );
    if (index < 0) {
      return;
    }
    final current = state.workspaces[index];
    if (!state.retiredWorkspaceIdentities.any(
      (value) => value.workspaceId == current.workspaceId,
    )) {
      state.retiredWorkspaceIdentities.add(
        CockpitRetiredWorkspaceIdentityRecord(
          workspaceId: current.workspaceId,
          checkoutId: current.checkoutId,
        ),
      );
    }
    state.workspaces[index] = current.copyWith(
      state: CockpitWorkspaceState.retired,
      updatedAt: now,
      retiredAt: now,
    );
    state.sessions.removeWhere((value) => value.workspaceId == workspaceId);
    state.otherReferences.removeWhere(
      (value) => value.workspaceId == workspaceId,
    );
    state.runs.removeWhere(
      (value) =>
          value.workspaceId == workspaceId &&
          !value.retained &&
          value.artifactCount == 0,
    );
    state.latestRuns.removeWhere(
      (latest) =>
          latest.workspaceId == workspaceId &&
          !state.runs.any(
            (run) =>
                run.workspaceId == workspaceId && run.runId == latest.runId,
          ),
    );
  }

  static void cleanupTombstones(CockpitRegistryState state) {
    final removableWorkspaces = <String>{};
    for (final workspace in state.workspaces) {
      if (workspace.state == CockpitWorkspaceState.retired &&
          workspaceCounts(state, workspace.workspaceId).retainedTotal == 0) {
        removableWorkspaces.add(workspace.workspaceId);
      }
    }
    state.workspaces.removeWhere(
      (value) => removableWorkspaces.contains(value.workspaceId),
    );
    state.runs.removeWhere(
      (value) => removableWorkspaces.contains(value.workspaceId),
    );
    state.latestRuns.removeWhere(
      (value) => removableWorkspaces.contains(value.workspaceId),
    );
    state.roots.removeWhere(
      (root) =>
          root.state == CockpitRootState.retired &&
          !state.workspaces.any((workspace) => workspace.rootId == root.rootId),
    );
  }
}
