import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../foundation/cockpit_locked_json_store.dart';
import 'cockpit_registry_database.dart';
import 'cockpit_registry_invariants.dart';
import 'cockpit_registry_models.dart';
import 'cockpit_registry_records.dart';
import 'cockpit_registry_state.dart';
import 'cockpit_registry_value_reader.dart';

final class CockpitScopedReferenceIndex {
  const CockpitScopedReferenceIndex(this._database);

  final CockpitRegistryDatabase _database;

  Future<void> setSession(String workspaceId, String sessionId) async {
    _ids(workspaceId, sessionId);
    await _database.transact<void>((state) async {
      _activeWorkspace(state, workspaceId);
      final exists = state.sessions.any(
        (value) =>
            value.workspaceId == workspaceId && value.sessionId == sessionId,
      );
      if (!exists) {
        state.sessions.add(
          CockpitSessionReferenceRecord(sessionId, workspaceId),
        );
      }
      return CockpitLockedJsonUpdate.write(state, null);
    });
  }

  Future<bool> clearSession(String workspaceId, String sessionId) =>
      _database.transact<bool>((state) async {
        _ids(workspaceId, sessionId);
        final before = state.sessions.length;
        state.sessions.removeWhere(
          (value) =>
              value.workspaceId == workspaceId && value.sessionId == sessionId,
        );
        CockpitRegistryInvariants.cleanupTombstones(state);
        return CockpitLockedJsonUpdate.write(
          state,
          state.sessions.length != before,
        );
      });

  Future<CockpitSessionReferenceRecord> resolveSession(
    String workspaceId,
    String sessionId,
  ) async {
    _ids(workspaceId, sessionId);
    final state = await _database.read();
    return _resolve<CockpitSessionReferenceRecord>(
      state.sessions,
      workspaceId,
      sessionId,
      workspace: (value) => value.workspaceId,
      identifier: (value) => value.sessionId,
    );
  }

  Future<void> setRun({
    required String workspaceId,
    required String runId,
    required bool active,
    required bool retained,
    required int artifactCount,
    bool latest = true,
  }) async {
    _ids(workspaceId, runId);
    if (artifactCount < 0 || artifactCount > 1000000) {
      throw const CockpitRegistryException(
        code: 'invalidReferenceCount',
        message: 'Artifact reference count is out of bounds.',
      );
    }
    await _database.transact<void>((state) async {
      _activeWorkspace(state, workspaceId);
      final index = state.runs.indexWhere(
        (value) => value.workspaceId == workspaceId && value.runId == runId,
      );
      if (index >= 0) {
        final current = state.runs[index];
        if ((current.retained && !retained) ||
            artifactCount < current.artifactCount) {
          throw const CockpitRegistryException(
            code: 'immutableReference',
            message: 'Retained references require an explicit release.',
          );
        }
        state.runs[index] = CockpitRunReferenceRecord(
          runId: runId,
          workspaceId: workspaceId,
          active: active,
          retained: retained,
          artifactCount: artifactCount,
        );
      } else {
        state.runs.add(
          CockpitRunReferenceRecord(
            runId: runId,
            workspaceId: workspaceId,
            active: active,
            retained: retained,
            artifactCount: artifactCount,
          ),
        );
      }
      if (latest) {
        state.latestRuns.removeWhere(
          (value) => value.workspaceId == workspaceId,
        );
        state.latestRuns.add(CockpitLatestRunRecord(workspaceId, runId));
      }
      return CockpitLockedJsonUpdate.write(state, null);
    });
  }

  Future<bool> clearRun(String workspaceId, String runId) =>
      _database.transact<bool>((state) async {
        _ids(workspaceId, runId);
        final index = state.runs.indexWhere(
          (value) => value.workspaceId == workspaceId && value.runId == runId,
        );
        if (index < 0) {
          return CockpitLockedJsonUpdate.readOnly(state, false);
        }
        final current = state.runs[index];
        if (current.retained || current.artifactCount > 0) {
          state.runs[index] = CockpitRunReferenceRecord(
            runId: runId,
            workspaceId: workspaceId,
            active: false,
            retained: current.retained,
            artifactCount: current.artifactCount,
          );
        } else {
          state.runs.removeAt(index);
          state.latestRuns.removeWhere(
            (value) => value.workspaceId == workspaceId && value.runId == runId,
          );
        }
        CockpitRegistryInvariants.cleanupTombstones(state);
        return CockpitLockedJsonUpdate.write(state, true);
      });

  Future<void> releaseRunRetention(String workspaceId, String runId) =>
      _updateRetention(workspaceId, runId, releaseRun: true, artifacts: 0);

  Future<void> releaseArtifactReferences(
    String workspaceId,
    String runId,
    int count,
  ) =>
      _updateRetention(workspaceId, runId, releaseRun: false, artifacts: count);

  Future<void> _updateRetention(
    String workspaceId,
    String runId, {
    required bool releaseRun,
    required int artifacts,
  }) => _database.transact<void>((state) async {
    _ids(workspaceId, runId);
    final index = state.runs.indexWhere(
      (value) => value.workspaceId == workspaceId && value.runId == runId,
    );
    if (index < 0) {
      throw const CockpitRegistryException(
        code: 'referenceNotFound',
        message: 'Run reference was not found in this workspace.',
      );
    }
    final current = state.runs[index];
    if (artifacts < 0 || artifacts > current.artifactCount) {
      throw const CockpitRegistryException(
        code: 'invalidReferenceCount',
        message: 'Artifact release exceeds retained references.',
      );
    }
    final updated = CockpitRunReferenceRecord(
      runId: runId,
      workspaceId: workspaceId,
      active: current.active,
      retained: releaseRun ? false : current.retained,
      artifactCount: current.artifactCount - artifacts,
    );
    if (!updated.active && !updated.retained && updated.artifactCount == 0) {
      state.runs.removeAt(index);
      state.latestRuns.removeWhere(
        (value) => value.workspaceId == workspaceId && value.runId == runId,
      );
    } else {
      state.runs[index] = updated;
    }
    CockpitRegistryInvariants.cleanupTombstones(state);
    return CockpitLockedJsonUpdate.write(state, null);
  });

  Future<CockpitRunReferenceRecord> resolveRun(
    String workspaceId,
    String runId,
  ) async {
    _ids(workspaceId, runId);
    final state = await _database.read();
    return _resolve<CockpitRunReferenceRecord>(
      state.runs,
      workspaceId,
      runId,
      workspace: (value) => value.workspaceId,
      identifier: (value) => value.runId,
    );
  }

  Future<CockpitRunReferenceRecord> resolveLatestRun(String workspaceId) async {
    CockpitRegistryValueReader.id(workspaceId, r'$.workspaceId');
    final state = await _database.read();
    final latest = state.latestRuns
        .where((value) => value.workspaceId == workspaceId)
        .toList();
    if (latest.isEmpty) {
      throw const CockpitRegistryException(
        code: 'referenceNotFound',
        message: 'No latest run is indexed for this workspace.',
      );
    }
    if (latest.length != 1) {
      throw const CockpitRegistryException(
        code: 'ambiguousReference',
        message: 'Latest run index is ambiguous.',
      );
    }
    return resolveRun(workspaceId, latest.single.runId);
  }

  Future<bool> clearLatestRun(
    String workspaceId, {
    required String expectedRunId,
  }) => _database.transact<bool>((state) async {
    _ids(workspaceId, expectedRunId);
    final matches = state.latestRuns
        .where((value) => value.workspaceId == workspaceId)
        .toList();
    if (matches.isEmpty) {
      return CockpitLockedJsonUpdate.readOnly(state, false);
    }
    if (matches.single.runId != expectedRunId) {
      throw const CockpitRegistryException(
        code: 'latestRunConflict',
        message: 'Expected run does not match the scoped latest-run index.',
      );
    }
    state.latestRuns.remove(matches.single);
    return CockpitLockedJsonUpdate.write(state, true);
  });

  Future<void> setOther(String workspaceId, String owner, String referenceId) =>
      _database.transact<void>((state) async {
        _ids(workspaceId, owner, referenceId);
        _activeWorkspace(state, workspaceId);
        final exists = state.otherReferences.any(
          (value) =>
              value.workspaceId == workspaceId &&
              value.owner == owner &&
              value.referenceId == referenceId,
        );
        if (!exists) {
          state.otherReferences.add(
            CockpitOtherReferenceRecord(
              owner: owner,
              referenceId: referenceId,
              workspaceId: workspaceId,
            ),
          );
        }
        return CockpitLockedJsonUpdate.write(state, null);
      });

  Future<bool> clearOther(
    String workspaceId,
    String owner,
    String referenceId,
  ) => _database.transact<bool>((state) async {
    _ids(workspaceId, owner, referenceId);
    final before = state.otherReferences.length;
    state.otherReferences.removeWhere(
      (value) =>
          value.workspaceId == workspaceId &&
          value.owner == owner &&
          value.referenceId == referenceId,
    );
    CockpitRegistryInvariants.cleanupTombstones(state);
    return CockpitLockedJsonUpdate.write(
      state,
      before != state.otherReferences.length,
    );
  });

  T _resolve<T>(
    Iterable<T> records,
    String workspaceId,
    String id, {
    required String Function(T value) workspace,
    required String Function(T value) identifier,
  }) {
    final sameId = records.where((value) => identifier(value) == id).toList();
    final scoped = sameId
        .where((value) => workspace(value) == workspaceId)
        .toList();
    if (scoped.length == 1) {
      return scoped.single;
    }
    if (scoped.length > 1 || sameId.length > 1) {
      throw const CockpitRegistryException(
        code: 'ambiguousReference',
        message: 'Reference identifier is ambiguous.',
      );
    }
    if (sameId.length == 1) {
      throw const CockpitRegistryException(
        code: 'crossWorkspaceReference',
        message: 'Reference belongs to a different workspace.',
      );
    }
    throw const CockpitRegistryException(
      code: 'referenceNotFound',
      message: 'Reference was not found in this workspace.',
    );
  }

  void _activeWorkspace(CockpitRegistryState state, String workspaceId) {
    final matches = state.workspaces.where(
      (value) => value.workspaceId == workspaceId,
    );
    if (matches.isEmpty ||
        matches.single.state != CockpitWorkspaceState.active) {
      throw const CockpitRegistryException(
        code: 'workspaceNotActive',
        message: 'Workspace does not grant mutation authority.',
      );
    }
  }

  void _ids(String first, [String? second, String? third]) {
    CockpitRegistryValueReader.id(first, r'$.id');
    if (second != null) CockpitRegistryValueReader.id(second, r'$.id');
    if (third != null) CockpitRegistryValueReader.id(third, r'$.id');
  }
}
