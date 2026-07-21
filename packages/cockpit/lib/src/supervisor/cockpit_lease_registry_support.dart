part of 'cockpit_lease_registry.dart';

extension _CockpitLeaseRegistrySupport on CockpitLeaseRegistry {
  DateTime get _now => _clock.utcNow.toUtc();

  Future<R> _readCurrentState<R>(
    R Function(CockpitLeaseStateDocument state) read,
  ) => _database.transact<R>((state) async {
    final now = _now;
    _pruneReleased(state, now);
    _expireDue(state, now);
    _grantAvailable(state, now);
    return CockpitLockedJsonUpdate.write(state, read(state));
  });

  CockpitLeaseResource _resource(
    CockpitLeaseStateDocument state,
    CockpitLeaseRecord record,
  ) {
    if (record.state != CockpitLeaseState.queued) {
      return record.toResource();
    }
    final queue =
        state.leases
            .where(
              (candidate) =>
                  candidate.state == CockpitLeaseState.queued &&
                  candidate.sameResource(record),
            )
            .toList()
          ..sort((left, right) => left.sequence.compareTo(right.sequence));
    return record.toResource(queuePosition: queue.indexOf(record));
  }

  CockpitDurablePortReservation _portReservation(
    CockpitLeaseStateDocument state,
    CockpitLeaseRecord record,
  ) {
    if (record.handoffToken == null || record.portPhase == null) {
      throw const CockpitLeaseException(
        code: 'portReservationInvalid',
        message: 'Lease does not contain durable port reservation state.',
      );
    }
    return CockpitDurablePortReservation(
      lease: _resource(state, record),
      handoffToken: record.handoffToken!,
      ttlMs: record.ttlMs,
      phase: record.portPhase!,
      expectedOwner: record.portOwner,
    );
  }

  void _expireDue(CockpitLeaseStateDocument state, DateTime now) {
    for (var index = 0; index < state.leases.length; index += 1) {
      final record = state.leases[index];
      if (record.state == CockpitLeaseState.active &&
          !record.expiresAt!.isAfter(now)) {
        state.leases[index] = record.copyWith(
          state: CockpitLeaseState.expired,
          cleanupReason: CockpitLeaseCleanupReason.expiry,
          cleanupClaimId: null,
          cleanupClaimExpiresAt: null,
        );
      }
    }
  }

  void _grantAvailable(CockpitLeaseStateDocument state, DateTime now) {
    _expireQueueWaiters(state, now);
    final queues = <String, List<CockpitLeaseRecord>>{};
    final blocked = <String>{};
    for (final record in state.leases) {
      final key = _resourceKey(record.resourceKind, record.resourceId);
      if (record.blocksResource) blocked.add(key);
      if (record.state == CockpitLeaseState.queued) {
        queues.putIfAbsent(key, () => <CockpitLeaseRecord>[]).add(record);
      }
    }
    for (final entry in queues.entries) {
      if (blocked.contains(entry.key)) continue;
      entry.value.sort(
        (left, right) => left.sequence.compareTo(right.sequence),
      );
      final record = entry.value.first;
      _replace(
        state,
        record.copyWith(
          state: CockpitLeaseState.active,
          acquiredAt: now,
          lastHeartbeatAt: now,
          expiresAt: now.add(Duration(milliseconds: record.ttlMs)),
        ),
      );
    }
  }

  void _expireQueueWaiters(CockpitLeaseStateDocument state, DateTime now) {
    for (var index = 0; index < state.leases.length; index += 1) {
      final record = state.leases[index];
      if (record.state != CockpitLeaseState.queued) continue;
      final deadline = record.requestedAt.add(
        Duration(milliseconds: record.waitTimeoutMs),
      );
      if (now.isAfter(deadline)) {
        state.leases[index] = record.copyWith(
          state: CockpitLeaseState.released,
          releasedAt: now,
        );
      }
    }
  }

  void _pruneReleased(CockpitLeaseStateDocument state, DateTime now) {
    final cutoff = now.subtract(_idempotencyRetention);
    state.leases.removeWhere(
      (record) =>
          record.state == CockpitLeaseState.released &&
          record.releasedAt!.isBefore(cutoff),
    );
  }

  CockpitLeaseRecord _replace(
    CockpitLeaseStateDocument state,
    CockpitLeaseRecord replacement,
  ) {
    final index = state.leases.indexWhere(
      (record) => record.leaseId == replacement.leaseId,
    );
    if (index < 0) {
      throw const CockpitLeaseException(
        code: 'leaseNotFound',
        message: 'Lease disappeared during a state transition.',
      );
    }
    state.leases[index] = replacement;
    return replacement;
  }

  String _newId(CockpitLeaseStateDocument state, CockpitIdKind kind) {
    for (var attempt = 0; attempt < 32; attempt += 1) {
      final candidate = _idGenerator.next(kind);
      final collision = state.leases.any(
        (record) =>
            record.leaseId == candidate || record.cleanupClaimId == candidate,
      );
      if (!collision) return candidate;
    }
    throw const CockpitLeaseException(
      code: 'idGenerationFailed',
      message: 'Could not generate a unique secure lease identifier.',
    );
  }

  CockpitLeaseRecord _requireHolder(
    CockpitLeaseStateDocument state,
    String leaseId,
    String holderId,
  ) {
    final record = state.byId(leaseId);
    if (record.holderId != holderId) {
      throw const CockpitLeaseException(
        code: 'leaseHolderMismatch',
        message: 'Lease belongs to a different holder.',
      );
    }
    return record;
  }

  String _resourceKey(
    CockpitLeaseResourceKind resourceKind,
    String resourceId,
  ) => '${resourceKind.name}\u0000$resourceId';

  CockpitFailure _cleanupFailure(String code, String message) => CockpitFailure(
    primary: CockpitApiError(
      code: code,
      category: CockpitErrorCategory.resource,
      message: message,
      retryable: true,
      responsibleLayer: CockpitResponsibleLayer.supervisor,
    ),
  );
}

final class _CockpitLeaseAdmissionLocks {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<R> run<R>(
    Set<String> rootIds,
    Set<String> workspaceIds,
    Future<R> Function() action,
  ) {
    final keys = <String>[
      for (final rootId in rootIds) 'root:$rootId',
      for (final workspaceId in workspaceIds) 'workspace:$workspaceId',
    ]..sort();
    return _enter(keys, 0, action);
  }

  Future<R> _enter<R>(
    List<String> keys,
    int index,
    Future<R> Function() action,
  ) async {
    if (index == keys.length) return action();
    final key = keys[index];
    final previous = _tails[key] ?? Future<void>.value();
    final turn = Completer<void>();
    _tails[key] = turn.future;
    await previous;
    try {
      return await _enter(keys, index + 1, action);
    } finally {
      turn.complete();
      if (identical(_tails[key], turn.future)) _tails.remove(key);
    }
  }
}
