import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../application/cockpit_application_service_exception.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import 'cockpit_worker_run_ownership_authority.dart';
import 'cockpit_worker_value_reader.dart';

enum CockpitWorkerCaseAttemptStatus {
  prepared,
  running,
  interrupted,
  completed,
}

final class CockpitWorkerCaseAttemptReservation {
  const CockpitWorkerCaseAttemptReservation({
    required this.runId,
    required this.attemptId,
    required this.replayed,
    this.completedOutput,
  });

  final String runId;
  final String attemptId;
  final bool replayed;
  final Map<String, Object?>? completedOutput;
}

final class CockpitWorkerCaseRunStore
    implements CockpitWorkerRunOwnershipAuthority {
  static const int maximumCachedRunOwners = 100000;

  CockpitWorkerCaseRunStore.memory({required this.workspaceId})
    : _transactions = _MemoryCaseRunTransactions();

  CockpitWorkerCaseRunStore.file({
    required this.workspaceId,
    required String path,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
  }) : _transactions = _FileCaseRunTransactions(
         root: path,
         permissionHardener: permissionHardener,
         directorySyncer: directorySyncer,
       );

  final String workspaceId;
  final _CaseRunTransactions _transactions;
  final Map<String, String> _ownedRunKeys = <String, String>{};

  @override
  Future<Set<String>> findOwnedRunIds({
    required String workspaceId,
    required Set<String> candidateRunIds,
  }) async {
    if (workspaceId != this.workspaceId) return const <String>{};
    for (final runId in candidateRunIds) {
      workerId(runId, r'$.runId');
    }
    final unresolved = candidateRunIds
        .where((runId) => !_ownedRunKeys.containsKey(runId))
        .toSet();
    if (unresolved.isNotEmpty) {
      final discovered = <String, String>{};
      await for (final stored in _transactions.records()) {
        final record = _record(
          stored.value,
          expectedRecordHash: stored.recordHash,
        );
        final runId = record['runId']! as String;
        if (!unresolved.contains(runId)) continue;
        final idempotencyKey = record['idempotencyKey']! as String;
        if (discovered.putIfAbsent(runId, () => idempotencyKey) !=
            idempotencyKey) {
          throw FormatException('Duplicate case run identity $runId.');
        }
      }
      for (final entry in discovered.entries) {
        _cacheOwnedRun(entry.key, entry.value);
      }
    }
    final owned = <String>{};
    for (final runId in candidateRunIds) {
      final idempotencyKey = _ownedRunKeys[runId];
      if (idempotencyKey == null) continue;
      final stored = await _transactions.read(idempotencyKey);
      if (stored == null) continue;
      final record = _record(
        stored.value,
        expectedIdempotencyKey: idempotencyKey,
        expectedRecordHash: stored.recordHash,
      );
      if (record['runId'] == runId) owned.add(runId);
    }
    return Set<String>.unmodifiable(owned);
  }

  void _cacheOwnedRun(String runId, String idempotencyKey) {
    _ownedRunKeys.remove(runId);
    _ownedRunKeys[runId] = idempotencyKey;
    while (_ownedRunKeys.length > maximumCachedRunOwners) {
      _ownedRunKeys.remove(_ownedRunKeys.keys.first);
    }
  }

  Future<int> recover({required DateTime now}) =>
      _transactions.recover((current, recordHash) {
        final document = _record(current, expectedRecordHash: recordHash);
        var recovered = 0;
        for (final attemptValue in document['attempts']! as List<Object?>) {
          final attempt = attemptValue! as Map<String, Object?>;
          final status = CockpitWorkerCaseAttemptStatus.values.byName(
            attempt['status']! as String,
          );
          if (status != CockpitWorkerCaseAttemptStatus.prepared &&
              status != CockpitWorkerCaseAttemptStatus.running) {
            continue;
          }
          attempt['status'] = CockpitWorkerCaseAttemptStatus.interrupted.name;
          attempt['updatedAt'] = now.toUtc().toIso8601String();
          document['updatedAt'] = attempt['updatedAt'];
          recovered += 1;
        }
        return recovered > 0
            ? CockpitLockedJsonUpdate.write(document, recovered)
            : CockpitLockedJsonUpdate.readOnly(document, recovered);
      });

  Future<CockpitWorkerCaseAttemptReservation> reserve({
    required String idempotencyKey,
    required String requestFingerprint,
    required String caseId,
    required String proposedRunId,
    required String proposedAttemptId,
    required DateTime now,
  }) async {
    await _transactions.markActive(idempotencyKey);
    final reservation = await _transact<CockpitWorkerCaseAttemptReservation>(
      idempotencyKey,
      (current) {
        workerId(idempotencyKey, r'$.idempotencyKey');
        _fingerprint(requestFingerprint, r'$.requestFingerprint');
        workerId(caseId, r'$.caseId');
        workerId(proposedRunId, r'$.proposedRunId');
        workerId(proposedAttemptId, r'$.proposedAttemptId');
        final run = current.isEmpty
            ? null
            : _record(current, expectedIdempotencyKey: idempotencyKey);
        if (run != null && run['requestFingerprint'] != requestFingerprint) {
          throw const CockpitApplicationServiceException(
            code: 'idempotencyConflict',
            message:
                'Case run idempotency key was reused with different input.',
          );
        }
        if (run != null) {
          final attempts = run['attempts']! as List<Object?>;
          for (final value in attempts.reversed) {
            final attempt = value! as Map<String, Object?>;
            if (attempt['status'] ==
                CockpitWorkerCaseAttemptStatus.completed.name) {
              return CockpitLockedJsonUpdate.readOnly(
                run,
                CockpitWorkerCaseAttemptReservation(
                  runId: run['runId']! as String,
                  attemptId: attempt['attemptId']! as String,
                  replayed: true,
                  completedOutput: _deepCopy(
                    attempt['completedOutput']! as Map<String, Object?>,
                  ),
                ),
              );
            }
          }
        }
        final timestamp = now.toUtc().toIso8601String();
        final attempt = <String, Object?>{
          'attemptId': proposedAttemptId,
          'status': CockpitWorkerCaseAttemptStatus.prepared.name,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        };
        if (run == null) {
          final created = <String, Object?>{
            'schemaVersion': 'cockpit.worker.case-run/v2',
            'workspaceId': workspaceId,
            'idempotencyKey': idempotencyKey,
            'requestFingerprint': requestFingerprint,
            'runId': proposedRunId,
            'caseId': caseId,
            'createdAt': timestamp,
            'updatedAt': timestamp,
            'attempts': <Object?>[attempt],
          };
          return CockpitLockedJsonUpdate.write(
            created,
            CockpitWorkerCaseAttemptReservation(
              runId: proposedRunId,
              attemptId: proposedAttemptId,
              replayed: false,
            ),
          );
        } else {
          (run['attempts']! as List<Object?>).add(attempt);
          run['updatedAt'] = timestamp;
        }
        return CockpitLockedJsonUpdate.write(
          run,
          CockpitWorkerCaseAttemptReservation(
            runId: run['runId']! as String,
            attemptId: proposedAttemptId,
            replayed: false,
          ),
        );
      },
    );
    _cacheOwnedRun(reservation.runId, idempotencyKey);
    if (reservation.replayed) {
      await _transactions.markInactive(idempotencyKey);
    }
    return reservation;
  }

  Future<void> markRunning({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required DateTime now,
  }) async {
    await _transactions.markActive(idempotencyKey);
    await _transition(
      idempotencyKey: idempotencyKey,
      runId: runId,
      attemptId: attemptId,
      expected: CockpitWorkerCaseAttemptStatus.prepared,
      next: CockpitWorkerCaseAttemptStatus.running,
      now: now,
    );
  }

  Future<void> markInterrupted({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required DateTime now,
  }) async {
    await _transact<void>(idempotencyKey, (current) {
      final record = _record(current, expectedIdempotencyKey: idempotencyKey);
      final transition = _attempt(record, runId, attemptId);
      final status = CockpitWorkerCaseAttemptStatus.values.byName(
        transition.attempt['status']! as String,
      );
      if (status == CockpitWorkerCaseAttemptStatus.completed ||
          status == CockpitWorkerCaseAttemptStatus.interrupted) {
        return CockpitLockedJsonUpdate.readOnly(record, null);
      }
      _setStatus(transition, CockpitWorkerCaseAttemptStatus.interrupted, now);
      return CockpitLockedJsonUpdate.write(record, null);
    });
    await _transactions.markInactive(idempotencyKey);
  }

  Future<void> markCompleted({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required Map<String, Object?> output,
    required DateTime now,
  }) async {
    await _transact<void>(idempotencyKey, (current) {
      workerValidateJsonValue(output, r'$.output');
      final record = _record(current, expectedIdempotencyKey: idempotencyKey);
      final transition = _attempt(record, runId, attemptId);
      if (transition.attempt['status'] !=
          CockpitWorkerCaseAttemptStatus.running.name) {
        throw StateError('Only a running case attempt can complete.');
      }
      transition.attempt['completedOutput'] = _deepCopy(output);
      _setStatus(transition, CockpitWorkerCaseAttemptStatus.completed, now);
      return CockpitLockedJsonUpdate.write(record, null);
    });
    await _transactions.markInactive(idempotencyKey);
  }

  Future<void> _transition({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required CockpitWorkerCaseAttemptStatus expected,
    required CockpitWorkerCaseAttemptStatus next,
    required DateTime now,
  }) => _transact<void>(idempotencyKey, (current) {
    final record = _record(current, expectedIdempotencyKey: idempotencyKey);
    final transition = _attempt(record, runId, attemptId);
    if (transition.attempt['status'] != expected.name) {
      throw StateError(
        'Case attempt $attemptId cannot transition from '
        '${transition.attempt['status']} to ${next.name}.',
      );
    }
    _setStatus(transition, next, now);
    return CockpitLockedJsonUpdate.write(record, null);
  });

  Future<R> _transact<R>(
    String idempotencyKey,
    CockpitLockedJsonTransaction<Map<String, Object?>, R> transaction,
  ) {
    workerId(idempotencyKey, r'$.idempotencyKey');
    return _transactions.transact(idempotencyKey, transaction);
  }

  Map<String, Object?> _record(
    Map<String, Object?> current, {
    String? expectedIdempotencyKey,
    String? expectedRecordHash,
  }) {
    if (current.isEmpty) {
      throw const FormatException('Case run record is missing.');
    }
    final record = _deepCopy(current);
    workerKeys(
      record,
      const <String>{
        'schemaVersion',
        'workspaceId',
        'idempotencyKey',
        'requestFingerprint',
        'runId',
        'caseId',
        'createdAt',
        'updatedAt',
        'attempts',
      },
      r'$',
      required: const <String>{
        'schemaVersion',
        'workspaceId',
        'idempotencyKey',
        'requestFingerprint',
        'runId',
        'caseId',
        'createdAt',
        'updatedAt',
        'attempts',
      },
    );
    if (record['schemaVersion'] != 'cockpit.worker.case-run/v2' ||
        record['workspaceId'] != workspaceId) {
      throw const FormatException('Case run state identity is invalid.');
    }
    final idempotencyKey = workerId(
      record['idempotencyKey'],
      r'$.idempotencyKey',
    );
    if (expectedIdempotencyKey != null &&
        idempotencyKey != expectedIdempotencyKey) {
      throw const FormatException('Case run record identity is invalid.');
    }
    if (expectedRecordHash != null &&
        _recordHash(idempotencyKey) != expectedRecordHash) {
      throw const FormatException('Case run record hash is invalid.');
    }
    _fingerprint(record['requestFingerprint'], r'$.requestFingerprint');
    workerId(record['runId'], r'$.runId');
    workerId(record['caseId'], r'$.caseId');
    workerUtcDateTime(record['createdAt'], r'$.createdAt');
    workerUtcDateTime(record['updatedAt'], r'$.updatedAt');
    final attempts = workerList(
      record['attempts'],
      r'$.attempts',
      maximum: 10000,
    );
    if (attempts.isEmpty) {
      throw const FormatException('Case run has no attempts.');
    }
    final attemptIds = <String>{};
    for (var index = 0; index < attempts.length; index += 1) {
      _validateAttempt(attempts[index], '\$.attempts[$index]', attemptIds);
    }
    record['attempts'] = attempts;
    return record;
  }
}

final class _CaseAttemptTransition {
  const _CaseAttemptTransition({required this.run, required this.attempt});

  final Map<String, Object?> run;
  final Map<String, Object?> attempt;
}

_CaseAttemptTransition _attempt(
  Map<String, Object?> run,
  String runId,
  String attemptId,
) {
  workerId(runId, r'$.runId');
  workerId(attemptId, r'$.attemptId');
  if (run['runId'] != runId) {
    throw StateError('Case run $runId was not found.');
  }
  for (final attemptValue in run['attempts']! as List<Object?>) {
    final attempt = attemptValue! as Map<String, Object?>;
    if (attempt['attemptId'] == attemptId) {
      return _CaseAttemptTransition(run: run, attempt: attempt);
    }
  }
  throw StateError('Case attempt $runId/$attemptId was not found.');
}

void _setStatus(
  _CaseAttemptTransition transition,
  CockpitWorkerCaseAttemptStatus status,
  DateTime now,
) {
  final timestamp = now.toUtc().toIso8601String();
  transition.attempt['status'] = status.name;
  transition.attempt['updatedAt'] = timestamp;
  transition.run['updatedAt'] = timestamp;
}

void _validateAttempt(Object? value, String path, Set<String> attemptIds) {
  final attempt = workerObject(value, path);
  workerKeys(
    attempt,
    const <String>{
      'attemptId',
      'status',
      'createdAt',
      'updatedAt',
      'completedOutput',
    },
    path,
    required: const <String>{'attemptId', 'status', 'createdAt', 'updatedAt'},
  );
  if (!attemptIds.add(workerId(attempt['attemptId'], '$path.attemptId'))) {
    throw FormatException('Duplicate case attempt identity at $path.');
  }
  final status = workerString(attempt['status'], '$path.status', maximum: 32);
  final parsedStatus = CockpitWorkerCaseAttemptStatus.values
      .where((candidate) => candidate.name == status)
      .firstOrNull;
  if (parsedStatus == null) {
    throw FormatException('Invalid case attempt status at $path.status.');
  }
  workerUtcDateTime(attempt['createdAt'], '$path.createdAt');
  workerUtcDateTime(attempt['updatedAt'], '$path.updatedAt');
  if (parsedStatus == CockpitWorkerCaseAttemptStatus.completed) {
    if (!attempt.containsKey('completedOutput')) {
      throw FormatException('Completed case attempt has no output at $path.');
    }
    attempt['completedOutput'] = workerObject(
      attempt['completedOutput'],
      '$path.completedOutput',
    );
  } else if (attempt.containsKey('completedOutput')) {
    throw FormatException('Incomplete case attempt has output at $path.');
  }
}

String _fingerprint(Object? value, String path) {
  final fingerprint = workerString(value, path, minimum: 64, maximum: 64);
  if (!_isLowercaseHex(fingerprint, length: 64)) {
    throw FormatException('Invalid request fingerprint at $path.');
  }
  return fingerprint;
}

abstract interface class _CaseRunTransactions {
  Future<int> recover(_CaseRunRecoveryTransaction transaction);

  Future<void> markActive(String idempotencyKey);

  Future<void> markInactive(String idempotencyKey);

  Future<R> transact<R>(
    String idempotencyKey,
    CockpitLockedJsonTransaction<Map<String, Object?>, R> transaction,
  );

  Future<_StoredCaseRunRecord?> read(String idempotencyKey);

  Stream<_StoredCaseRunRecord> records();
}

final class _StoredCaseRunRecord {
  const _StoredCaseRunRecord({required this.value, required this.recordHash});

  final Map<String, Object?> value;
  final String recordHash;
}

typedef _CaseRunRecoveryTransaction =
    FutureOr<CockpitLockedJsonUpdate<Map<String, Object?>, int>> Function(
      Map<String, Object?> current,
      String recordHash,
    );

final class _MemoryCaseRunTransactions implements _CaseRunTransactions {
  final Map<String, Map<String, Object?>> _states =
      <String, Map<String, Object?>>{};
  final Set<String> _activeKeys = <String>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<int> recover(_CaseRunRecoveryTransaction transaction) =>
      _exclusive(() async {
        var recovered = 0;
        final keys = _activeKeys.toList()..sort();
        for (final key in keys) {
          final state = _states[key];
          if (state == null) continue;
          final update = await transaction(_deepCopy(state), _recordHash(key));
          if (update.shouldWrite) {
            _states[key] = _deepCopy(update.value);
          }
          recovered += update.result;
        }
        _activeKeys.clear();
        return recovered;
      });

  @override
  Future<void> markActive(String idempotencyKey) => _exclusive(() async {
    _activeKeys.add(idempotencyKey);
  });

  @override
  Future<void> markInactive(String idempotencyKey) => _exclusive(() async {
    _activeKeys.remove(idempotencyKey);
  });

  @override
  Future<R> transact<R>(
    String idempotencyKey,
    CockpitLockedJsonTransaction<Map<String, Object?>, R> transaction,
  ) => _exclusive(() async {
    final current = _states[idempotencyKey] ?? const <String, Object?>{};
    final update = await transaction(_deepCopy(current));
    if (update.shouldWrite) {
      _states[idempotencyKey] = _deepCopy(update.value);
    }
    return update.result;
  });

  @override
  Future<_StoredCaseRunRecord?> read(String idempotencyKey) =>
      _exclusive(() async {
        final value = _states[idempotencyKey];
        if (value == null) return null;
        return _StoredCaseRunRecord(
          value: _deepCopy(value),
          recordHash: _recordHash(idempotencyKey),
        );
      });

  @override
  Stream<_StoredCaseRunRecord> records() async* {
    final values = await _exclusive(
      () async => <_StoredCaseRunRecord>[
        for (final entry in _states.entries)
          _StoredCaseRunRecord(
            value: _deepCopy(entry.value),
            recordHash: _recordHash(entry.key),
          ),
      ],
    );
    yield* Stream<_StoredCaseRunRecord>.fromIterable(values);
  }

  Future<R> _exclusive<R>(Future<R> Function() action) {
    final previous = _tail;
    final turn = Completer<void>();
    _tail = turn.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        turn.complete();
      }
    })();
  }
}

final class _FileCaseRunTransactions implements _CaseRunTransactions {
  _FileCaseRunTransactions({
    required String root,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
  }) : _root = p.normalize(p.absolute(root)),
       _permissionHardener = permissionHardener,
       _directorySyncer = directorySyncer;

  static const int maximumRecordBytes = 2 * 1024 * 1024;

  final String _root;
  final CockpitPermissionHardener _permissionHardener;
  final CockpitDirectorySyncer _directorySyncer;

  String get _activeRoot => p.join(_root, 'active');

  @override
  Future<int> recover(_CaseRunRecoveryTransaction transaction) async {
    await _prepareRoot();
    await _prepareActiveRoot();
    await _scanActiveDirectory();
    final active = await _readActiveManifest();
    var recovered = 0;
    for (final entry in active.entries) {
      final hash = entry.key;
      final key = entry.value;
      final recordDirectory = _recordDirectoryForHash(hash);
      final directoryType = await FileSystemEntity.type(
        recordDirectory,
        followLinks: false,
      );
      if (directoryType == FileSystemEntityType.notFound) {
        continue;
      }
      if (directoryType != FileSystemEntityType.directory) {
        throw FileSystemException(
          'Case run active record directory is invalid.',
          recordDirectory,
        );
      }
      await _validateRecordDirectory(recordDirectory, expectedHash: hash);
      final hasRecordTemporary = await _scanRecordDirectory(
        recordDirectory,
        expectedHash: hash,
      );
      final recordPath = p.join(recordDirectory, 'record.json');
      final recordType = await FileSystemEntity.type(
        recordPath,
        followLinks: false,
      );
      if (recordType == FileSystemEntityType.notFound && !hasRecordTemporary) {
        continue;
      }
      if (recordType != FileSystemEntityType.file &&
          recordType != FileSystemEntityType.notFound) {
        throw FileSystemException(
          'Case run active record is invalid.',
          recordPath,
        );
      }
      recovered += await _storeAt(recordPath).transact<int>((current) {
        final record = workerObject(current, r'$');
        if (record['idempotencyKey'] != key || _recordHash(key) != hash) {
          throw const FormatException(
            'Case run active manifest identity is invalid.',
          );
        }
        return transaction(current, hash);
      });
    }
    await _writeActiveManifest(const <String, String>{});
    return recovered;
  }

  @override
  Future<void> markActive(String idempotencyKey) async {
    workerId(idempotencyKey, r'$.idempotencyKey');
    await _prepareActiveRoot();
    final hash = _recordHash(idempotencyKey);
    await _activeManifestStore().transact<void>((raw) {
      final active = _decodeCaseActiveManifest(raw);
      final existing = active[hash];
      if (existing != null && existing != idempotencyKey) {
        throw const FormatException('Case run active identity is invalid.');
      }
      if (existing == idempotencyKey) {
        return CockpitLockedJsonUpdate.readOnly(raw, null);
      }
      active[hash] = idempotencyKey;
      return CockpitLockedJsonUpdate.write(
        _encodeCaseActiveManifest(active),
        null,
      );
    });
  }

  @override
  Future<void> markInactive(String idempotencyKey) async {
    final hash = _recordHash(idempotencyKey);
    await _activeManifestStore().transact<void>((raw) {
      final active = _decodeCaseActiveManifest(raw);
      if (active[hash] != idempotencyKey) {
        return CockpitLockedJsonUpdate.readOnly(raw, null);
      }
      active.remove(hash);
      return CockpitLockedJsonUpdate.write(
        _encodeCaseActiveManifest(active),
        null,
      );
    });
  }

  @override
  Future<R> transact<R>(
    String idempotencyKey,
    CockpitLockedJsonTransaction<Map<String, Object?>, R> transaction,
  ) async => (await _storeForKey(idempotencyKey)).transact(transaction);

  @override
  Future<_StoredCaseRunRecord?> read(String idempotencyKey) async {
    final hash = _recordHash(idempotencyKey);
    final recordDirectory = _recordDirectoryForHash(hash);
    final directoryType = await FileSystemEntity.type(
      recordDirectory,
      followLinks: false,
    );
    if (directoryType == FileSystemEntityType.notFound) return null;
    if (directoryType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Case run record directory is invalid.',
        recordDirectory,
      );
    }
    await _validateRecordDirectory(recordDirectory, expectedHash: hash);
    final hasTemporary = await _scanRecordDirectory(
      recordDirectory,
      expectedHash: hash,
    );
    final recordPath = p.join(recordDirectory, 'record.json');
    final recordType = await FileSystemEntity.type(
      recordPath,
      followLinks: false,
    );
    if (recordType == FileSystemEntityType.notFound && !hasTemporary) {
      return null;
    }
    if (recordType != FileSystemEntityType.file &&
        recordType != FileSystemEntityType.notFound) {
      throw FileSystemException('Case run record is invalid.', recordPath);
    }
    if (recordType == FileSystemEntityType.file) {
      await _validateStoreFiles(recordPath);
    }
    return _StoredCaseRunRecord(
      value: await _storeAt(recordPath).read(),
      recordHash: hash,
    );
  }

  @override
  Stream<_StoredCaseRunRecord> records() async* {
    final recordsPath = p.join(_root, 'records');
    final recordsType = await FileSystemEntity.type(
      recordsPath,
      followLinks: false,
    );
    if (recordsType == FileSystemEntityType.notFound) return;
    if (recordsType != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Case run records root is invalid.',
        recordsPath,
      );
    }
    await _validateCanonicalDirectory(recordsPath);
    await for (final shard in Directory(recordsPath).list(followLinks: false)) {
      final shardName = p.basename(shard.path);
      final shardType = await FileSystemEntity.type(
        shard.path,
        followLinks: false,
      );
      if (!_isLowercaseHex(shardName, length: 2) ||
          shardType != FileSystemEntityType.directory) {
        throw FileSystemException('Case run shard is invalid.', shard.path);
      }
      await _validateCanonicalDirectory(shard.path);
      await for (final recordDirectory in Directory(
        shard.path,
      ).list(followLinks: false)) {
        final hash = p.basename(recordDirectory.path);
        final directoryType = await FileSystemEntity.type(
          recordDirectory.path,
          followLinks: false,
        );
        if (!_isLowercaseHex(hash, length: 64) ||
            !hash.startsWith(shardName) ||
            directoryType != FileSystemEntityType.directory) {
          throw FileSystemException(
            'Case run record shard entry is invalid.',
            recordDirectory.path,
          );
        }
        final hasTemporary = await _scanRecordDirectory(
          recordDirectory.path,
          expectedHash: hash,
        );
        final recordPath = p.join(recordDirectory.path, 'record.json');
        final recordType = await FileSystemEntity.type(
          recordPath,
          followLinks: false,
        );
        if (recordType == FileSystemEntityType.notFound && !hasTemporary) {
          throw FileSystemException('Case run record is missing.', recordPath);
        }
        if (recordType != FileSystemEntityType.file &&
            recordType != FileSystemEntityType.notFound) {
          throw FileSystemException('Case run record is invalid.', recordPath);
        }
        if (recordType == FileSystemEntityType.file) {
          await _validateStoreFiles(recordPath);
        }
        yield _StoredCaseRunRecord(
          value: await _storeAt(recordPath).read(),
          recordHash: hash,
        );
      }
    }
  }

  Future<CockpitLockedJsonStore<Map<String, Object?>>> _storeForKey(
    String idempotencyKey,
  ) async {
    final hash = _recordHash(idempotencyKey);
    final directory = await _prepareRecordDirectory(hash);
    await _scanRecordDirectory(directory.path, expectedHash: hash);
    final path = p.join(directory.path, 'record.json');
    await _validateStoreFiles(path);
    return _storeAt(path);
  }

  CockpitLockedJsonStore<Map<String, Object?>> _storeAt(String path) =>
      CockpitLockedJsonStore<Map<String, Object?>>(
        path: path,
        codec: const _CaseRunJsonCodec(),
        createInitial: () => const <String, Object?>{},
        permissionHardener: _permissionHardener,
        directorySyncer: _directorySyncer,
        maximumBytes: maximumRecordBytes,
      );

  CockpitLockedJsonStore<Map<String, Object?>> _activeManifestStore() =>
      CockpitLockedJsonStore<Map<String, Object?>>(
        path: p.join(_activeRoot, 'manifest.json'),
        codec: const _CaseRunJsonCodec(),
        createInitial: () =>
            _encodeCaseActiveManifest(const <String, String>{}),
        permissionHardener: _permissionHardener,
        directorySyncer: _directorySyncer,
        maximumBytes: 2 * 1024 * 1024,
      );

  Future<Map<String, String>> _readActiveManifest() async =>
      _decodeCaseActiveManifest(await _activeManifestStore().read());

  Future<void> _writeActiveManifest(Map<String, String> active) async {
    await _activeManifestStore().transact<void>(
      (_) => CockpitLockedJsonUpdate.write(
        _encodeCaseActiveManifest(active),
        null,
      ),
    );
  }

  Future<Directory> _prepareRecordDirectory(String hash) async {
    await _prepareRoot();
    final records = await _prepareOwnedDirectory(
      p.join(_root, 'records'),
      parentPath: _root,
    );
    final shard = await _prepareOwnedDirectory(
      p.join(records.path, hash.substring(0, 2)),
      parentPath: records.path,
    );
    final directory = await _prepareOwnedDirectory(
      p.join(shard.path, hash),
      parentPath: shard.path,
    );
    await _validateRecordDirectory(directory.path, expectedHash: hash);
    return directory;
  }

  Future<Directory> _prepareOwnedDirectory(
    String path, {
    required String parentPath,
  }) async {
    final directory = Directory(path);
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await directory.create();
      await _permissionHardener.hardenDirectory(directory);
      await _directorySyncer.sync(parentPath);
      return directory;
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Case run record path is invalid.', path);
    }
    await _validateCanonicalDirectory(path);
    await _permissionHardener.hardenDirectory(directory);
    return directory;
  }

  String _recordDirectoryForHash(String hash) =>
      p.join(_root, 'records', hash.substring(0, 2), hash);

  Future<void> _validateRecordDirectory(
    String path, {
    required String expectedHash,
  }) async {
    if (!_isLowercaseHex(expectedHash, length: 64) ||
        !p.equals(path, _recordDirectoryForHash(expectedHash))) {
      throw FileSystemException(
        'Case run record directory identity is invalid.',
        path,
      );
    }
    await _validateCanonicalDirectory(path);
  }

  Future<bool> _scanRecordDirectory(
    String directoryPath, {
    required String expectedHash,
  }) async {
    await _validateRecordDirectory(directoryPath, expectedHash: expectedHash);
    var hasRecordTemporary = false;
    await for (final entity in Directory(
      directoryPath,
    ).list(followLinks: false)) {
      final name = p.basename(entity.path);
      final temporaryTarget = cockpitAtomicJsonTemporaryTargetName(name);
      if (temporaryTarget != null) {
        if (temporaryTarget != 'record.json') {
          throw FileSystemException(
            'Case run record contains an unknown temporary file.',
            entity.path,
          );
        }
        hasRecordTemporary = true;
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Case run record directory contains an invalid entry.',
          entity.path,
        );
      }
      await cockpitValidateCanonicalRegularFile(
        entity.path,
        diagnostic: 'Case run record file is not canonical.',
      );
      if (name != 'record.json' && name != 'record.json.lock') {
        throw FileSystemException(
          'Case run record contains an unknown file.',
          entity.path,
        );
      }
    }
    return hasRecordTemporary;
  }

  Future<void> _scanActiveDirectory() async {
    await for (final entity in Directory(
      _activeRoot,
    ).list(followLinks: false)) {
      final name = p.basename(entity.path);
      final temporaryTarget = cockpitAtomicJsonTemporaryTargetName(name);
      if (temporaryTarget != null) {
        if (temporaryTarget != 'manifest.json') {
          throw FileSystemException(
            'Case run active set contains an unknown temporary file.',
            entity.path,
          );
        }
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Case run active set contains an invalid entry.',
          entity.path,
        );
      }
      await cockpitValidateCanonicalRegularFile(
        entity.path,
        diagnostic: 'Case run active manifest is not canonical.',
      );
      if (name != 'manifest.json' && name != 'manifest.json.lock') {
        throw FileSystemException(
          'Case run active set contains an unknown file.',
          entity.path,
        );
      }
    }
  }

  Future<void> _prepareActiveRoot() async {
    await _prepareRoot();
    final directory = Directory(_activeRoot);
    final type = await FileSystemEntity.type(_activeRoot, followLinks: false);
    var created = false;
    if (type == FileSystemEntityType.notFound) {
      if (!await Directory(_root).list(followLinks: false).isEmpty) {
        throw FileSystemException(
          'Case run active manifest directory is missing.',
          _activeRoot,
        );
      }
      await directory.create();
      await _permissionHardener.hardenDirectory(directory);
      await _directorySyncer.sync(_root);
      created = true;
    } else if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Case run active set is invalid.', _activeRoot);
    } else {
      await _validateCanonicalDirectory(_activeRoot);
      await _permissionHardener.hardenDirectory(directory);
    }
    final manifestPath = p.join(_activeRoot, 'manifest.json');
    final manifestType = await FileSystemEntity.type(
      manifestPath,
      followLinks: false,
    );
    if (manifestType == FileSystemEntityType.notFound) {
      if (!created && !await _canInitializeMissingManifest()) {
        throw FileSystemException(
          'Case run active manifest is missing.',
          manifestPath,
        );
      }
      await _activeManifestStore().transact<void>(
        (raw) => CockpitLockedJsonUpdate.write(raw, null),
      );
    } else {
      await cockpitValidateCanonicalRegularFile(
        manifestPath,
        diagnostic: 'Case run active manifest is not canonical.',
      );
    }
  }

  Future<bool> _canInitializeMissingManifest() async {
    await _scanActiveDirectory();
    final recordsPath = p.join(_root, 'records');
    final recordsType = await FileSystemEntity.type(
      recordsPath,
      followLinks: false,
    );
    if (recordsType == FileSystemEntityType.notFound) return true;
    if (recordsType != FileSystemEntityType.directory) return false;
    await _validateCanonicalDirectory(recordsPath);
    return Directory(
      recordsPath,
    ).list(recursive: true, followLinks: false).isEmpty;
  }

  Future<void> _validateCanonicalDirectory(String path) async {
    final canonical = p.normalize(await Directory(path).resolveSymbolicLinks());
    if (!p.equals(canonical, p.normalize(path)) ||
        (!p.equals(path, _root) && !p.isWithin(_root, path))) {
      throw FileSystemException('Case run directory is not canonical.', path);
    }
  }

  Future<void> _prepareRoot() async {
    final root = Directory(_root);
    final type = await FileSystemEntity.type(_root, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await root.create(recursive: true);
      await _permissionHardener.hardenDirectory(root);
      await _directorySyncer.sync(root.parent.path);
      return;
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Case run store root is invalid.', _root);
    }
    final canonical = p.normalize(await root.resolveSymbolicLinks());
    if (!p.equals(canonical, _root)) {
      throw FileSystemException('Case run store root is not canonical.', _root);
    }
    await _permissionHardener.hardenDirectory(root);
  }

  Future<void> _validateStoreFiles(String path) async {
    for (final candidate in <String>[path, '$path.lock']) {
      final type = await FileSystemEntity.type(candidate, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw FileSystemException(
          'Case run store record has an invalid file type.',
          candidate,
        );
      }
      final canonical = p.normalize(
        await File(candidate).resolveSymbolicLinks(),
      );
      if (!p.equals(canonical, candidate)) {
        throw FileSystemException(
          'Case run store record is not canonical.',
          candidate,
        );
      }
    }
  }
}

final class _CaseRunJsonCodec
    implements CockpitJsonCodec<Map<String, Object?>> {
  const _CaseRunJsonCodec();

  @override
  Map<String, Object?> decode(Object? json) => workerObject(json, r'$');

  @override
  Object? encode(Map<String, Object?> value) => value;
}

Map<String, Object?> _encodeCaseActiveManifest(Map<String, String> active) =>
    <String, Object?>{
      'schemaVersion': 'cockpit.worker.case-run-active/v1',
      'records': <String, Object?>{
        for (final entry in active.entries) entry.key: entry.value,
      },
    };

Map<String, String> _decodeCaseActiveManifest(Map<String, Object?> value) {
  final json = workerObject(value, r'$');
  workerKeys(
    json,
    const <String>{'schemaVersion', 'records'},
    r'$',
    required: const <String>{'schemaVersion', 'records'},
  );
  if (json['schemaVersion'] != 'cockpit.worker.case-run-active/v1') {
    throw const FormatException('Unsupported case run active manifest.');
  }
  final records = workerObject(json['records'], r'$.records');
  if (records.length > 10000) {
    throw const FormatException('Case run active manifest exceeds bounds.');
  }
  final result = <String, String>{};
  for (final entry in records.entries) {
    final hash = entry.key;
    final key = workerId(entry.value, '\$.records.$hash');
    if (!_isLowercaseHex(hash, length: 64) || hash != _recordHash(key)) {
      throw const FormatException('Case run active manifest hash is invalid.');
    }
    result[hash] = key;
  }
  return result;
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    workerObject(_copyValue(value), r'$');

Object? _copyValue(Object? value) => switch (value) {
  Map<Object?, Object?> map => <String, Object?>{
    for (final entry in map.entries)
      entry.key! as String: _copyValue(entry.value),
  },
  List<Object?> list => list.map(_copyValue).toList(),
  _ => value,
};

String _recordHash(String idempotencyKey) =>
    sha256.convert(utf8.encode(idempotencyKey)).toString();

bool _isLowercaseHex(String value, {required int length}) {
  if (value.length != length) return false;
  for (final codeUnit in value.codeUnits) {
    if ((codeUnit < 48 || codeUnit > 57) && (codeUnit < 97 || codeUnit > 102)) {
      return false;
    }
  }
  return true;
}
