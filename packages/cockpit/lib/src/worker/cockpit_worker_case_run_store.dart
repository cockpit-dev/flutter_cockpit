import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import '../application/cockpit_application_service_exception.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import 'cockpit_worker_case_completion.dart';
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

final class CockpitWorkerCaseRecoveryAttempt {
  const CockpitWorkerCaseRecoveryAttempt({
    required this.runId,
    required this.caseId,
    required this.attemptId,
  });

  final String runId;
  final String caseId;
  final String attemptId;
}

final class CockpitWorkerCaseCompletionIntent {
  CockpitWorkerCaseCompletionIntent({
    required this.idempotencyKey,
    required this.runId,
    required this.caseId,
    required this.attemptId,
    required this.intentId,
    required this.intentVersion,
    required Map<String, Object?> output,
    required Iterable<CockpitRunEvent> events,
    required this.eventsSha256,
    required this.createdAt,
  }) : output = _deepCopy(output),
       events = List<CockpitRunEvent>.unmodifiable(events);

  final String idempotencyKey;
  final String runId;
  final String caseId;
  final String attemptId;
  final String intentId;
  final int intentVersion;
  final Map<String, Object?> output;
  final List<CockpitRunEvent> events;
  final String eventsSha256;
  final DateTime createdAt;
}

typedef CockpitWorkerCaseBeforeInterrupt =
    Future<void> Function(CockpitWorkerCaseRecoveryAttempt attempt);
typedef CockpitWorkerCaseCompletionReconciler =
    Future<void> Function(CockpitWorkerCaseCompletionIntent intent);

final class CockpitWorkerCaseRunStore
    implements CockpitWorkerRunOwnershipAuthority {
  static const int maximumCachedRunOwners = 100000;

  CockpitWorkerCaseRunStore.memory({
    required this.workspaceId,
    CockpitWorkerCaseCompletionObserver? completionObserver,
  }) : _completionObserver = completionObserver,
       _transactions = _MemoryCaseRunTransactions();

  CockpitWorkerCaseRunStore.file({
    required this.workspaceId,
    required String path,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
    CockpitWorkerCaseCompletionObserver? completionObserver,
  }) : _completionObserver = completionObserver,
       _transactions = _FileCaseRunTransactions(
         root: path,
         permissionHardener: permissionHardener,
         directorySyncer: directorySyncer,
       );

  final String workspaceId;
  final CockpitWorkerCaseCompletionObserver? _completionObserver;
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

  Future<int> recover({
    required DateTime now,
    CockpitWorkerCaseCompletionReconciler? reconcileCompletion,
    CockpitWorkerCaseBeforeInterrupt? beforeInterrupt,
  }) async {
    var recovered = 0;
    for (final stored in await _transactions.activeRecords()) {
      final current = stored.value;
      if (current == null) {
        await _transactions.markInactive(stored.idempotencyKey);
        continue;
      }
      final document = _record(
        current,
        expectedIdempotencyKey: stored.idempotencyKey,
        expectedRecordHash: stored.recordHash,
      );
      final runId = document['runId']! as String;
      final caseId = document['caseId']! as String;
      for (final attemptValue in document['attempts']! as List<Object?>) {
        final attempt = attemptValue! as Map<String, Object?>;
        final attemptId = attempt['attemptId']! as String;
        final intentValue = attempt['completionIntent'];
        if (intentValue != null) {
          if (reconcileCompletion == null) {
            throw StateError(
              'Case completion recovery requires an event reconciler.',
            );
          }
          final intent = _completionIntent(
            intentValue,
            workspaceId: workspaceId,
            idempotencyKey: stored.idempotencyKey,
            runId: runId,
            caseId: caseId,
            attemptId: attemptId,
          );
          await reconcileCompletion(intent);
          if (await _commitCompletionIntent(
            idempotencyKey: stored.idempotencyKey,
            runId: runId,
            attemptId: attemptId,
            intentId: intent.intentId,
            intentVersion: intent.intentVersion,
            eventsSha256: intent.eventsSha256,
            now: now,
          )) {
            recovered += 1;
          }
          await _observe(
            CockpitWorkerCaseCompletionPhase.completionCommitted,
            intent,
            recovering: true,
          );
          continue;
        }
        final status = CockpitWorkerCaseAttemptStatus.values.byName(
          attempt['status']! as String,
        );
        if (status != CockpitWorkerCaseAttemptStatus.prepared &&
            status != CockpitWorkerCaseAttemptStatus.running) {
          continue;
        }
        final recoveryAttempt = CockpitWorkerCaseRecoveryAttempt(
          runId: runId,
          caseId: caseId,
          attemptId: attemptId,
        );
        if (beforeInterrupt != null) {
          await beforeInterrupt(recoveryAttempt);
        }
        if (await _markRecoveryInterrupted(
          idempotencyKey: stored.idempotencyKey,
          recoveryAttempt: recoveryAttempt,
          expected: status,
          now: now,
        )) {
          recovered += 1;
        }
      }
      await _transactions.markInactive(stored.idempotencyKey);
    }
    return recovered;
  }

  Future<bool> _markRecoveryInterrupted({
    required String idempotencyKey,
    required CockpitWorkerCaseRecoveryAttempt recoveryAttempt,
    required CockpitWorkerCaseAttemptStatus expected,
    required DateTime now,
  }) => _transact<bool>(idempotencyKey, (current) {
    final record = _record(current, expectedIdempotencyKey: idempotencyKey);
    final transition = _attempt(
      record,
      recoveryAttempt.runId,
      recoveryAttempt.attemptId,
    );
    if (transition.attempt['status'] != expected.name ||
        transition.attempt.containsKey('completionIntent')) {
      return CockpitLockedJsonUpdate.readOnly(record, false);
    }
    _setStatus(transition, CockpitWorkerCaseAttemptStatus.interrupted, now);
    return CockpitLockedJsonUpdate.write(record, true);
  });

  Future<void> _observe(
    CockpitWorkerCaseCompletionPhase phase,
    CockpitWorkerCaseCompletionIntent intent, {
    required bool recovering,
  }) => notifyCockpitWorkerCaseCompletion(
    _completionObserver,
    CockpitWorkerCaseCompletionObservation(
      phase: phase,
      idempotencyKey: intent.idempotencyKey,
      runId: intent.runId,
      caseId: intent.caseId,
      attemptId: intent.attemptId,
      intentId: intent.intentId,
      recovering: recovering,
    ),
  );

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
            if (attempt.containsKey('completionIntent')) {
              throw StateError('Case completion is pending durable recovery.');
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
            'schemaVersion': 'cockpit.worker.case-run/v3',
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

  Future<CockpitWorkerCaseCompletionIntent> prepareCompletionIntent({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required String intentId,
    required Map<String, Object?> output,
    required List<CockpitRunEvent> events,
    required DateTime now,
  }) async {
    if (events.isEmpty) {
      throw const FormatException('Case completion event batch is empty.');
    }
    workerValidateJsonValue(output, r'$.output');
    final eventsSha256 = _eventsSha256(events);
    late CockpitWorkerCaseCompletionIntent intent;
    await _transact<void>(idempotencyKey, (current) {
      final record = _record(current, expectedIdempotencyKey: idempotencyKey);
      final transition = _attempt(record, runId, attemptId);
      if (transition.attempt['status'] !=
          CockpitWorkerCaseAttemptStatus.running.name) {
        throw StateError('Only a running case attempt can prepare completion.');
      }
      intent = CockpitWorkerCaseCompletionIntent(
        idempotencyKey: idempotencyKey,
        runId: runId,
        caseId: record['caseId']! as String,
        attemptId: attemptId,
        intentId: intentId,
        intentVersion: 1,
        output: output,
        events: events,
        eventsSha256: eventsSha256,
        createdAt: now.toUtc(),
      );
      final encoded = _encodeCompletionIntent(intent);
      final existingValue = transition.attempt['completionIntent'];
      if (existingValue != null) {
        final existing = _completionIntent(
          existingValue,
          workspaceId: workspaceId,
          idempotencyKey: idempotencyKey,
          runId: runId,
          caseId: record['caseId']! as String,
          attemptId: attemptId,
        );
        if (_canonicalJson(_encodeCompletionIntent(existing)) !=
            _canonicalJson(encoded)) {
          throw const FormatException(
            'Case completion intent conflicts with durable state.',
          );
        }
        intent = existing;
        return CockpitLockedJsonUpdate.readOnly(record, null);
      }
      transition.attempt['completionIntent'] = encoded;
      record['schemaVersion'] = 'cockpit.worker.case-run/v3';
      record['updatedAt'] = now.toUtc().toIso8601String();
      transition.attempt['updatedAt'] = record['updatedAt'];
      return CockpitLockedJsonUpdate.write(record, null);
    });
    await _observe(
      CockpitWorkerCaseCompletionPhase.intentPersisted,
      intent,
      recovering: false,
    );
    return intent;
  }

  Future<void> commitCompletionIntent({
    required CockpitWorkerCaseCompletionIntent intent,
    required DateTime now,
  }) async {
    await _commitCompletionIntent(
      idempotencyKey: intent.idempotencyKey,
      runId: intent.runId,
      attemptId: intent.attemptId,
      intentId: intent.intentId,
      intentVersion: intent.intentVersion,
      eventsSha256: intent.eventsSha256,
      now: now,
    );
    await _observe(
      CockpitWorkerCaseCompletionPhase.completionCommitted,
      intent,
      recovering: false,
    );
    await _transactions.markInactive(intent.idempotencyKey);
  }

  Future<bool> _commitCompletionIntent({
    required String idempotencyKey,
    required String runId,
    required String attemptId,
    required String intentId,
    required int intentVersion,
    required String eventsSha256,
    required DateTime now,
  }) => _transact<bool>(idempotencyKey, (current) {
    final record = _record(current, expectedIdempotencyKey: idempotencyKey);
    final transition = _attempt(record, runId, attemptId);
    final receiptValue = transition.attempt['completionReceipt'];
    if (transition.attempt['status'] ==
            CockpitWorkerCaseAttemptStatus.completed.name &&
        receiptValue != null) {
      final receipt = _completionReceipt(receiptValue);
      if (receipt.intentId != intentId ||
          receipt.intentVersion != intentVersion ||
          receipt.eventsSha256 != eventsSha256) {
        throw const FormatException(
          'Completed case intent conflicts with durable state.',
        );
      }
      return CockpitLockedJsonUpdate.readOnly(record, false);
    }
    if (transition.attempt['status'] !=
        CockpitWorkerCaseAttemptStatus.running.name) {
      throw StateError('Only a running case attempt can commit completion.');
    }
    final intent = _completionIntent(
      transition.attempt['completionIntent'],
      workspaceId: workspaceId,
      idempotencyKey: idempotencyKey,
      runId: runId,
      caseId: record['caseId']! as String,
      attemptId: attemptId,
    );
    if (intent.intentId != intentId ||
        intent.intentVersion != intentVersion ||
        intent.eventsSha256 != eventsSha256) {
      throw const FormatException(
        'Case completion intent changed before commit.',
      );
    }
    transition.attempt['completedOutput'] = _deepCopy(intent.output);
    transition.attempt['completionReceipt'] = _encodeCompletionReceipt(intent);
    transition.attempt.remove('completionIntent');
    _setStatus(transition, CockpitWorkerCaseAttemptStatus.completed, now);
    record['schemaVersion'] = 'cockpit.worker.case-run/v3';
    return CockpitLockedJsonUpdate.write(record, true);
  });

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
      if (transition.attempt.containsKey('completionIntent')) {
        throw StateError('Pending completion intent must be committed.');
      }
      transition.attempt['completedOutput'] = _deepCopy(output);
      _setStatus(transition, CockpitWorkerCaseAttemptStatus.completed, now);
      record['schemaVersion'] = 'cockpit.worker.case-run/v3';
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
    if (!const <String>{
          'cockpit.worker.case-run/v2',
          'cockpit.worker.case-run/v3',
        }.contains(record['schemaVersion']) ||
        record['workspaceId'] != workspaceId) {
      throw const FormatException('Case run state identity is invalid.');
    }
    record['schemaVersion'] = 'cockpit.worker.case-run/v3';
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
      _validateAttempt(
        attempts[index],
        '\$.attempts[$index]',
        attemptIds,
        workspaceId: workspaceId,
        idempotencyKey: idempotencyKey,
        runId: record['runId']! as String,
        caseId: record['caseId']! as String,
      );
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

void _validateAttempt(
  Object? value,
  String path,
  Set<String> attemptIds, {
  required String workspaceId,
  required String idempotencyKey,
  required String runId,
  required String caseId,
}) {
  final attempt = workerObject(value, path);
  workerKeys(
    attempt,
    const <String>{
      'attemptId',
      'status',
      'createdAt',
      'updatedAt',
      'completedOutput',
      'completionIntent',
      'completionReceipt',
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
    if (attempt.containsKey('completionIntent')) {
      throw FormatException('Completed case attempt has an intent at $path.');
    }
    if (attempt.containsKey('completionReceipt')) {
      _completionReceipt(attempt['completionReceipt']);
    }
  } else if (attempt.containsKey('completedOutput')) {
    throw FormatException('Incomplete case attempt has output at $path.');
  } else {
    if (attempt.containsKey('completionReceipt')) {
      throw FormatException(
        'Incomplete case attempt has a completion receipt at $path.',
      );
    }
    if (attempt.containsKey('completionIntent')) {
      if (parsedStatus != CockpitWorkerCaseAttemptStatus.running) {
        throw FormatException(
          'Only a running case attempt may have an intent at $path.',
        );
      }
      _completionIntent(
        attempt['completionIntent'],
        workspaceId: workspaceId,
        idempotencyKey: idempotencyKey,
        runId: runId,
        caseId: caseId,
        attemptId: attempt['attemptId']! as String,
      );
    }
  }
}

final class _CaseCompletionReceipt {
  const _CaseCompletionReceipt({
    required this.intentId,
    required this.intentVersion,
    required this.eventsSha256,
  });

  final String intentId;
  final int intentVersion;
  final String eventsSha256;
}

Map<String, Object?> _encodeCompletionIntent(
  CockpitWorkerCaseCompletionIntent intent,
) => <String, Object?>{
  'schemaVersion': 'cockpit.worker.case-completion/v1',
  'intentId': intent.intentId,
  'intentVersion': intent.intentVersion,
  'output': _deepCopy(intent.output),
  'events': intent.events.map((event) => event.toJson()).toList(),
  'eventsSha256': intent.eventsSha256,
  'createdAt': intent.createdAt.toUtc().toIso8601String(),
};

Map<String, Object?> _encodeCompletionReceipt(
  CockpitWorkerCaseCompletionIntent intent,
) => <String, Object?>{
  'schemaVersion': 'cockpit.worker.case-completion-receipt/v1',
  'intentId': intent.intentId,
  'intentVersion': intent.intentVersion,
  'eventsSha256': intent.eventsSha256,
};

CockpitWorkerCaseCompletionIntent _completionIntent(
  Object? value, {
  required String workspaceId,
  required String idempotencyKey,
  required String runId,
  required String caseId,
  required String attemptId,
}) {
  final json = workerObject(value, r'$.completionIntent');
  workerKeys(
    json,
    const <String>{
      'schemaVersion',
      'intentId',
      'intentVersion',
      'output',
      'events',
      'eventsSha256',
      'createdAt',
    },
    r'$.completionIntent',
    required: const <String>{
      'schemaVersion',
      'intentId',
      'intentVersion',
      'output',
      'events',
      'eventsSha256',
      'createdAt',
    },
  );
  if (json['schemaVersion'] != 'cockpit.worker.case-completion/v1') {
    throw const FormatException('Unsupported case completion intent.');
  }
  final output = workerObject(json['output'], r'$.completionIntent.output');
  if (output['runId'] != runId || output['attemptId'] != attemptId) {
    throw const FormatException('Case completion output identity is invalid.');
  }
  workerValidateJsonValue(output, r'$.completionIntent.output');
  final rawEvents = workerList(
    json['events'],
    r'$.completionIntent.events',
    maximum: 10000,
  );
  if (rawEvents.isEmpty) {
    throw const FormatException('Case completion event batch is empty.');
  }
  final events = <CockpitRunEvent>[
    for (var index = 0; index < rawEvents.length; index += 1)
      CockpitRunEvent.fromJson(
        rawEvents[index],
        path: '\$.completionIntent.events[$index]',
      ),
  ];
  CockpitRunEvent.validateSequence(
    events,
    afterSequence: events.first.sequence - 1,
  );
  if (events.any(
        (event) =>
            event.workspaceId != workspaceId ||
            event.runId != runId ||
            event.caseId != caseId ||
            event.attemptId != attemptId,
      ) ||
      events
              .where(
                (event) =>
                    event.entityKind == CockpitRunEventEntityKind.attempt &&
                    event.kind == 'attempt.completed' &&
                    event.outcome != null,
              )
              .length !=
          1 ||
      events
              .where(
                (event) =>
                    event.entityKind == CockpitRunEventEntityKind.testCase &&
                    event.kind == 'case.completed' &&
                    event.outcome != null,
              )
              .length !=
          1 ||
      events
              .where(
                (event) =>
                    event.entityKind == CockpitRunEventEntityKind.run &&
                    event.kind == 'run.completed' &&
                    event.lifecycle == CockpitRunLifecycle.completed,
              )
              .length !=
          1 ||
      events.last.entityKind != CockpitRunEventEntityKind.run ||
      events.last.kind != 'run.completed') {
    throw const FormatException(
      'Case completion terminal event batch is invalid.',
    );
  }
  final eventsSha256 = _sha256(
    json['eventsSha256'],
    r'$.completionIntent.eventsSha256',
  );
  if (_eventsSha256(events) != eventsSha256) {
    throw const FormatException('Case completion event digest is invalid.');
  }
  return CockpitWorkerCaseCompletionIntent(
    idempotencyKey: idempotencyKey,
    runId: runId,
    caseId: caseId,
    attemptId: attemptId,
    intentId: workerId(json['intentId'], r'$.completionIntent.intentId'),
    intentVersion: workerInteger(
      json['intentVersion'],
      r'$.completionIntent.intentVersion',
      minimum: 1,
      maximum: 1,
    ),
    output: output,
    events: events,
    eventsSha256: eventsSha256,
    createdAt: workerUtcDateTime(
      json['createdAt'],
      r'$.completionIntent.createdAt',
    ),
  );
}

_CaseCompletionReceipt _completionReceipt(Object? value) {
  final json = workerObject(value, r'$.completionReceipt');
  workerKeys(
    json,
    const <String>{
      'schemaVersion',
      'intentId',
      'intentVersion',
      'eventsSha256',
    },
    r'$.completionReceipt',
    required: const <String>{
      'schemaVersion',
      'intentId',
      'intentVersion',
      'eventsSha256',
    },
  );
  if (json['schemaVersion'] != 'cockpit.worker.case-completion-receipt/v1') {
    throw const FormatException('Unsupported case completion receipt.');
  }
  return _CaseCompletionReceipt(
    intentId: workerId(json['intentId'], r'$.completionReceipt.intentId'),
    intentVersion: workerInteger(
      json['intentVersion'],
      r'$.completionReceipt.intentVersion',
      minimum: 1,
      maximum: 1,
    ),
    eventsSha256: _sha256(
      json['eventsSha256'],
      r'$.completionReceipt.eventsSha256',
    ),
  );
}

String _fingerprint(Object? value, String path) {
  final fingerprint = workerString(value, path, minimum: 64, maximum: 64);
  if (!_isLowercaseHex(fingerprint, length: 64)) {
    throw FormatException('Invalid request fingerprint at $path.');
  }
  return fingerprint;
}

abstract interface class _CaseRunTransactions {
  Future<List<_ActiveCaseRunRecord>> activeRecords();

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

final class _ActiveCaseRunRecord {
  const _ActiveCaseRunRecord({
    required this.idempotencyKey,
    required this.recordHash,
    required this.value,
  });

  final String idempotencyKey;
  final String recordHash;
  final Map<String, Object?>? value;
}

final class _MemoryCaseRunTransactions implements _CaseRunTransactions {
  final Map<String, Map<String, Object?>> _states =
      <String, Map<String, Object?>>{};
  final Set<String> _activeKeys = <String>{};
  Future<void> _tail = Future<void>.value();

  @override
  Future<List<_ActiveCaseRunRecord>> activeRecords() => _exclusive(() async {
    return <_ActiveCaseRunRecord>[
      for (final key in (_activeKeys.toList()..sort()))
        _ActiveCaseRunRecord(
          idempotencyKey: key,
          recordHash: _recordHash(key),
          value: _states[key] == null ? null : _deepCopy(_states[key]!),
        ),
    ];
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

  static const int maximumRecordBytes = 16 * 1024 * 1024;

  final String _root;
  final CockpitPermissionHardener _permissionHardener;
  final CockpitDirectorySyncer _directorySyncer;

  String get _activeRoot => p.join(_root, 'active');

  @override
  Future<List<_ActiveCaseRunRecord>> activeRecords() async {
    await _prepareRoot();
    await _prepareActiveRoot();
    await _scanActiveDirectory();
    final active = await _readActiveManifest();
    final result = <_ActiveCaseRunRecord>[];
    final entries = active.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    for (final entry in entries) {
      final hash = entry.key;
      final key = entry.value;
      final recordDirectory = _recordDirectoryForHash(hash);
      final directoryType = await FileSystemEntity.type(
        recordDirectory,
        followLinks: false,
      );
      if (directoryType == FileSystemEntityType.notFound) {
        result.add(
          _ActiveCaseRunRecord(
            idempotencyKey: key,
            recordHash: hash,
            value: null,
          ),
        );
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
        result.add(
          _ActiveCaseRunRecord(
            idempotencyKey: key,
            recordHash: hash,
            value: null,
          ),
        );
        continue;
      }
      if (recordType != FileSystemEntityType.file &&
          recordType != FileSystemEntityType.notFound) {
        throw FileSystemException(
          'Case run active record is invalid.',
          recordPath,
        );
      }
      final current = await _storeAt(recordPath).read();
      final record = workerObject(current, r'$');
      if (record['idempotencyKey'] != key || _recordHash(key) != hash) {
        throw const FormatException(
          'Case run active manifest identity is invalid.',
        );
      }
      result.add(
        _ActiveCaseRunRecord(
          idempotencyKey: key,
          recordHash: hash,
          value: current,
        ),
      );
    }
    return result;
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

String _eventsSha256(List<CockpitRunEvent> events) => sha256
    .convert(
      utf8.encode(
        _canonicalJson(events.map((event) => event.toJson()).toList()),
      ),
    )
    .toString();

String _sha256(Object? value, String path) {
  final digest = workerString(value, path, minimum: 64, maximum: 64);
  if (!_isLowercaseHex(digest, length: 64)) {
    throw FormatException('Invalid SHA-256 digest at $path.');
  }
  return digest;
}

String _canonicalJson(Object? value) {
  if (value is Map<Object?, Object?>) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List<Object?>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}

bool _isLowercaseHex(String value, {required int length}) {
  if (value.length != length) return false;
  for (final codeUnit in value.codeUnits) {
    if ((codeUnit < 48 || codeUnit > 57) && (codeUnit < 97 || codeUnit > 102)) {
      return false;
    }
  }
  return true;
}
