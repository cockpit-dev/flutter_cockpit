part of 'cockpit_workspace_registry.dart';

extension CockpitWorkspaceLifecycleOperations on CockpitWorkspaceRegistry {
  Future<CockpitRetirementResult> unregister(
    String workspaceId, {
    CockpitRemovalPolicy policy = CockpitRemovalPolicy.reject,
    Duration drainTimeout = const Duration(seconds: 30),
  }) {
    _validateTimeout(drainTimeout);
    return CockpitRegistryAdmissionFences.run(
      _referenceOwners,
      const <String>{},
      <String>{workspaceId},
      () => _unregisterWithinAdmissionFence(
        workspaceId,
        policy: policy,
        drainTimeout: drainTimeout,
      ),
    );
  }

  Future<CockpitRetirementResult> _unregisterWithinAdmissionFence(
    String workspaceId, {
    required CockpitRemovalPolicy policy,
    required Duration drainTimeout,
  }) async {
    await _recoverMarkerMutations();
    final initialState = await _database.read();
    final workspace = _workspace(initialState, workspaceId);
    final external = await _externalCount(workspaceId);
    final counts = CockpitRegistryInvariants.workspaceCounts(
      initialState,
      workspaceId,
      externalActive: external,
    );
    if (workspace.state == CockpitWorkspaceState.retired) {
      return CockpitRetirementResult(
        id: workspaceId,
        tombstoneRetained: true,
        referenceCounts: counts,
      );
    }
    if (policy == CockpitRemovalPolicy.reject && counts.activeTotal > 0) {
      throw CockpitRegistryException(
        code: 'workspaceInUse',
        message: 'Workspace still has live references.',
        referenceCounts: counts,
      );
    }
    if (policy != CockpitRemovalPolicy.reject) {
      await _markDraining(workspaceId);
      if (policy == CockpitRemovalPolicy.drain) {
        await _drainWithTimeout(
          _activityController.drainWorkspaces(<String>{
            workspaceId,
          }, drainTimeout),
          drainTimeout,
        );
      } else {
        await _activityController.forceWorkspaces(<String>{workspaceId});
      }
    }
    final currentExternal = await _externalCount(workspaceId);
    return _database.transact<CockpitRetirementResult>((state) async {
      _workspace(state, workspaceId);
      if (policy == CockpitRemovalPolicy.force) {
        CockpitRegistryInvariants.clearActiveReferences(state, <String>{
          workspaceId,
        });
      }
      final currentCounts = CockpitRegistryInvariants.workspaceCounts(
        state,
        workspaceId,
        externalActive: currentExternal,
      );
      if (currentCounts.activeTotal > 0) {
        throw CockpitRegistryException(
          code: 'workspaceInUse',
          message: 'Workspace still has live references after draining.',
          referenceCounts: currentCounts,
        );
      }
      final now = _clock.now().toUtc();
      CockpitRegistryInvariants.retireWorkspace(state, workspaceId, now);
      final retainedCounts = CockpitRegistryInvariants.workspaceCounts(
        state,
        workspaceId,
      );
      CockpitRegistryInvariants.cleanupTombstones(state);
      return CockpitLockedJsonUpdate.write(
        state,
        CockpitRetirementResult(
          id: workspaceId,
          tombstoneRetained: state.workspaces.any(
            (value) => value.workspaceId == workspaceId,
          ),
          referenceCounts: retainedCounts,
        ),
      );
    });
  }

  Future<List<CockpitWorkspaceResource>> list() async {
    await _recoverMarkerMutations();
    final state = await _database.read();
    return state.workspaces.map((value) => value.toResource()).toList();
  }

  Future<CockpitWorkspaceResource> get(String workspaceId) async {
    await _recoverMarkerMutations();
    final state = await _database.read();
    return _workspace(state, workspaceId).toResource();
  }

  Future<void> _markDraining(String workspaceId) =>
      _database.transact<void>((state) async {
        final workspace = _workspace(state, workspaceId);
        if (workspace.state == CockpitWorkspaceState.active) {
          state.workspaces[state.workspaces.indexOf(workspace)] = workspace
              .copyWith(
                state: CockpitWorkspaceState.draining,
                updatedAt: _clock.now().toUtc(),
              );
        }
        return CockpitLockedJsonUpdate.write(state, null);
      });

  Future<int> _externalCount(String workspaceId) async {
    var result = 0;
    for (final owner in _referenceOwners) {
      final count = await owner.activeReferenceCount(workspaceId);
      if (count < 0) {
        throw const CockpitRegistryException(
          code: 'invalidReferenceCount',
          message: 'Reference owner returned a negative count.',
        );
      }
      result += count;
    }
    return result;
  }

  void _validateTimeout(Duration timeout) {
    if (timeout.isNegative || timeout > const Duration(minutes: 5)) {
      throw const CockpitRegistryException(
        code: 'invalidDrainTimeout',
        message: 'Drain timeout must be between zero and five minutes.',
      );
    }
  }

  Future<void> _drainWithTimeout(Future<void> operation, Duration timeout) =>
      operation.timeout(
        timeout,
        onTimeout: () => throw const CockpitRegistryException(
          code: 'drainTimeout',
          message: 'Activity drain exceeded its bounded timeout.',
        ),
      );
}
