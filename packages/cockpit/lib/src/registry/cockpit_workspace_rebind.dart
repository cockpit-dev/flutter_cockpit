part of 'cockpit_workspace_registry.dart';

extension CockpitWorkspaceRebindOperations on CockpitWorkspaceRegistry {
  Future<CockpitWorkspaceRegistrationResult> explicitRebind({
    required String workspaceId,
    required String expectedCheckoutId,
    required String rootId,
    required String path,
    bool allowIdentityChange = false,
  }) async {
    await _recoverMarkerMutations();
    CockpitRegistryValueReader.id(workspaceId, r'$.workspaceId');
    CockpitRegistryValueReader.id(expectedCheckoutId, r'$.expectedCheckoutId');
    final target = await _attestDirectory(path);
    final rootAuthority = await _attestActiveRoot(
      rootId,
      target.directory.path,
    );
    return _database.transact<CockpitWorkspaceRegistrationResult>((
      state,
    ) async {
      _confirmAttestedRoot(state, rootAuthority, target.directory.path);
      final source = _workspace(state, workspaceId);
      if (source.checkoutId != expectedCheckoutId) {
        throw const CockpitRegistryException(
          code: 'workspaceRebindConflict',
          message: 'Expected checkout does not match the registry record.',
        );
      }
      if (source.state != CockpitWorkspaceState.active) {
        throw const CockpitRegistryException(
          code: 'workspaceNotActive',
          message: 'Workspace does not grant mutation authority.',
        );
      }
      var freshTarget = await _reattestMatching(
        target,
        CockpitDirectoryAttestationScope.workspace,
      );
      final marker = await _markerStore.read(freshTarget.directory.path);
      freshTarget = await _reattestMatching(
        freshTarget,
        CockpitDirectoryAttestationScope.workspace,
      );
      if (marker == null || !_markerMatches(source, marker)) {
        throw const CockpitRegistryException(
          code: 'workspaceRebindConflict',
          message: 'Rebind target marker does not match the expected checkout.',
        );
      }
      if (_lexicalPaths.equals(
        source.canonicalPath,
        freshTarget.directory.path,
      )) {
        if (source.identityQuality.isStrong &&
            !_isStrongSameIdentity(source, freshTarget.identity)) {
          if (!allowIdentityChange) {
            throw const CockpitRegistryException(
              code: 'workspaceRebindIdentityMismatch',
              message:
                  'Explicit rebind target identity does not match the source.',
            );
          }
          final rebound = source.copyWith(
            filesystemIdentity: freshTarget.identity.value,
            identityQuality: freshTarget.identity.quality,
            updatedAt: _clock.now().toUtc(),
          );
          state.workspaces[state.workspaces.indexOf(source)] = rebound;
          return CockpitLockedJsonUpdate.write(
            state,
            _result(rebound, CockpitWorkspaceRegistrationDisposition.existing),
          );
        }
        return CockpitLockedJsonUpdate.readOnly(
          state,
          _result(source, CockpitWorkspaceRegistrationDisposition.existing),
        );
      }
      if (state.workspaces.any(
        (value) =>
            value.workspaceId != workspaceId &&
            _lexicalPaths.equals(
              value.canonicalPath,
              freshTarget.directory.path,
            ),
      )) {
        throw const CockpitRegistryException(
          code: 'workspacePathConflict',
          message: 'Rebind target is already registered.',
        );
      }
      final sourceType = await FileSystemEntity.type(
        source.canonicalPath,
        followLinks: true,
      );
      if (sourceType == FileSystemEntityType.notFound) {
        if (!_isStrongSameIdentity(source, freshTarget.identity) &&
            !allowIdentityChange) {
          throw const CockpitRegistryException(
            code: 'workspaceRebindIdentityMismatch',
            message:
                'Explicit rebind target identity does not match the source.',
          );
        }
        final moved = source.copyWith(
          rootId: rootId,
          canonicalPath: freshTarget.directory.path,
          filesystemIdentity: freshTarget.identity.value,
          identityQuality: freshTarget.identity.quality,
          updatedAt: _clock.now().toUtc(),
        );
        state.workspaces[state.workspaces.indexOf(source)] = moved;
        return CockpitLockedJsonUpdate.write(
          state,
          _result(moved, CockpitWorkspaceRegistrationDisposition.moved),
        );
      }
      if (sourceType != FileSystemEntityType.directory) {
        throw const CockpitRegistryException(
          code: 'workspaceSourceConflict',
          message: 'Rebind source is not a directory.',
        );
      }
      final sourceAttestation = await _attestDirectory(source.canonicalPath);
      _verifyStoredWorkspace(
        source,
        sourceAttestation,
        code: 'workspaceSourceIdentityChanged',
      );
      if (sourceAttestation.identity.value == freshTarget.identity.value) {
        throw const CockpitRegistryException(
          code: 'ambiguousWorkspaceIdentity',
          message: 'Two live paths report the same filesystem identity.',
        );
      }
      return _copy(state, rootId, freshTarget, source.projectId);
    });
  }

  Future<CockpitWorkspaceRegistrationResult> rebindProject({
    required String workspaceId,
    required String expectedProjectId,
    required String projectId,
  }) async {
    await _recoverMarkerMutations();
    for (final entry in <String, String>{
      r'$.workspaceId': workspaceId,
      r'$.expectedProjectId': expectedProjectId,
      r'$.projectId': projectId,
    }.entries) {
      CockpitRegistryValueReader.id(entry.value, entry.key);
    }
    final snapshot = await _database.read();
    final snapshotSource = _workspace(snapshot, workspaceId);
    if (snapshotSource.state != CockpitWorkspaceState.active) {
      throw const CockpitRegistryException(
        code: 'workspaceNotActive',
        message: 'Workspace does not grant mutation authority.',
      );
    }
    if (snapshotSource.projectId != expectedProjectId) {
      throw const CockpitRegistryException(
        code: 'projectRebindConflict',
        message: 'Expected project identifier does not match.',
      );
    }
    final authority = await _attestWorkspaceAuthority(snapshot, snapshotSource);
    final preparation = await _database.transact<_ProjectRebindPreparation>((
      state,
    ) async {
      _confirmWorkspaceAuthority(state, authority);
      final source = _workspace(state, workspaceId);
      final marker = await _markerStore.read(source.canonicalPath);
      final freshAuthority = await _reattestWorkspaceAuthority(authority);
      _confirmWorkspaceAuthority(state, freshAuthority);
      if (marker == null || !_markerMatches(source, marker)) {
        throw const CockpitRegistryException(
          code: 'workspaceMarkerConflict',
          message: 'Workspace marker does not match its registry record.',
        );
      }
      if (projectId == expectedProjectId) {
        return CockpitLockedJsonUpdate.readOnly(
          state,
          _ProjectRebindPreparation(source, requiresMutation: false),
        );
      }
      state.markerMutations.add(
        CockpitMarkerMutationRecord(
          workspaceId: workspaceId,
          expectedProjectId: expectedProjectId,
          projectId: projectId,
        ),
      );
      return CockpitLockedJsonUpdate.write(
        state,
        _ProjectRebindPreparation(source, requiresMutation: true),
      );
    });
    if (!preparation.requiresMutation) {
      return _result(
        preparation.workspace,
        CockpitWorkspaceRegistrationDisposition.existing,
      );
    }
    await _recoverMarkerMutations();
    final rebound = _workspace(await _database.read(), workspaceId);
    return _result(
      rebound,
      CockpitWorkspaceRegistrationDisposition.reboundProject,
    );
  }

  Future<void> _recoverMarkerMutations() async {
    while (true) {
      final snapshot = await _database.read();
      if (snapshot.markerMutations.isEmpty) return;
      final mutation = snapshot.markerMutations.first;
      final workspace = _workspace(snapshot, mutation.workspaceId);
      var authority = await _attestWorkspaceAuthority(snapshot, workspace);
      var marker = await _markerStore.read(workspace.canonicalPath);
      authority = await _reattestWorkspaceAuthority(authority);
      _validateRecoverableMarker(workspace, mutation, marker);
      if (marker!.projectId != mutation.projectId) {
        authority = await _reattestWorkspaceAuthority(authority);
        marker = await _markerStore.read(workspace.canonicalPath);
        authority = await _reattestWorkspaceAuthority(authority);
        _validateRecoverableMarker(workspace, mutation, marker);
        if (marker!.projectId != mutation.projectId) {
          await _markerStore.write(
            workspace.canonicalPath,
            CockpitWorkspaceMarker(
              workspaceId: marker.workspaceId,
              projectId: mutation.projectId,
              checkoutId: marker.checkoutId,
              createdAt: marker.createdAt,
            ),
          );
          authority = await _reattestWorkspaceAuthority(authority);
        }
      }
      await _database.transact<void>((state) async {
        final mutationIndex = state.markerMutations.indexWhere(
          (value) =>
              value.workspaceId == mutation.workspaceId &&
              value.expectedProjectId == mutation.expectedProjectId &&
              value.projectId == mutation.projectId,
        );
        if (mutationIndex < 0) {
          return CockpitLockedJsonUpdate.readOnly(state, null);
        }
        _confirmWorkspaceAuthority(state, authority);
        final current = _workspace(state, mutation.workspaceId);
        if (current.projectId == mutation.expectedProjectId) {
          state.workspaces[state.workspaces.indexOf(current)] = current
              .copyWith(
                projectId: mutation.projectId,
                updatedAt: _clock.now().toUtc(),
              );
        } else if (current.projectId != mutation.projectId) {
          throw const CockpitRegistryException(
            code: 'markerMutationConflict',
            message: 'Registry changed during marker mutation recovery.',
          );
        }
        state.markerMutations.removeAt(mutationIndex);
        return CockpitLockedJsonUpdate.write(state, null);
      });
    }
  }

  void _validateRecoverableMarker(
    CockpitWorkspaceRecord workspace,
    CockpitMarkerMutationRecord mutation,
    CockpitWorkspaceMarker? marker,
  ) {
    if (marker == null ||
        marker.workspaceId != workspace.workspaceId ||
        marker.checkoutId != workspace.checkoutId ||
        marker.createdAt != workspace.createdAt ||
        (workspace.projectId != mutation.expectedProjectId &&
            workspace.projectId != mutation.projectId) ||
        (marker.projectId != mutation.expectedProjectId &&
            marker.projectId != mutation.projectId)) {
      throw const CockpitRegistryException(
        code: 'markerMutationConflict',
        message: 'Pending marker mutation cannot be recovered safely.',
      );
    }
  }
}

final class _ProjectRebindPreparation {
  const _ProjectRebindPreparation(
    this.workspace, {
    required this.requiresMutation,
  });

  final CockpitWorkspaceRecord workspace;
  final bool requiresMutation;
}
