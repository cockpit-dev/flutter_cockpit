import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/foundation/cockpit_locked_json_store.dart';
import 'package:cockpit/src/foundation/cockpit_permissions.dart';
import 'package:cockpit/src/worker/cockpit_worker_case_run_store.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('durably recovers a prepared attempt before retrying', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'cockpit-case-runs-prepared-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final path = p.join(await temporary.resolveSymbolicLinks(), 'case_runs');
    final hardener = Platform.isWindows
        ? const CockpitWindowsInheritedAclPermissionHardener()
        : const CockpitPosixPermissionHardener();
    final preparedAt = DateTime.utc(2026, 7, 22);
    final first = CockpitWorkerCaseRunStore.file(
      workspaceId: 'workspaceA',
      path: path,
      permissionHardener: hardener,
      directorySyncer: const _NoopDirectorySyncer(),
    );
    final initial = await first.reserve(
      idempotencyKey: 'case-run-prepared',
      requestFingerprint: _fingerprint('c'),
      caseId: 'caseA',
      proposedRunId: 'run_prepared',
      proposedAttemptId: 'attempt_prepared',
      now: preparedAt,
    );

    final reopened = CockpitWorkerCaseRunStore.file(
      workspaceId: 'workspaceA',
      path: path,
      permissionHardener: hardener,
      directorySyncer: const _NoopDirectorySyncer(),
    );
    expect(
      await reopened.recover(now: preparedAt.add(const Duration(seconds: 1))),
      1,
    );
    final retry = await reopened.reserve(
      idempotencyKey: 'case-run-prepared',
      requestFingerprint: _fingerprint('c'),
      caseId: 'caseA',
      proposedRunId: 'run_replacement',
      proposedAttemptId: 'attempt_retry',
      now: preparedAt.add(const Duration(seconds: 2)),
    );

    expect(retry.runId, initial.runId);
    expect(retry.attemptId, 'attempt_retry');
    final document = await _singleRecord(path);
    final attempts = document['attempts'] as List;
    expect(attempts.map((attempt) => (attempt as Map)['status']), <String>[
      'interrupted',
      'prepared',
    ]);
  });

  test(
    'durably recovers a running attempt into a new retry boundary',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'cockpit-case-runs-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final path = p.join(await temporary.resolveSymbolicLinks(), 'case_runs');
      final hardener = Platform.isWindows
          ? const CockpitWindowsInheritedAclPermissionHardener()
          : const CockpitPosixPermissionHardener();
      final first = CockpitWorkerCaseRunStore.file(
        workspaceId: 'workspaceA',
        path: path,
        permissionHardener: hardener,
        directorySyncer: const _NoopDirectorySyncer(),
      );
      final preparedAt = DateTime.utc(2026, 7, 22, 1);
      final initial = await first.reserve(
        idempotencyKey: 'case-run-A',
        requestFingerprint: _fingerprint('a'),
        caseId: 'caseA',
        proposedRunId: 'run_A',
        proposedAttemptId: 'attempt_A',
        now: preparedAt,
      );
      await first.markRunning(
        idempotencyKey: 'case-run-A',
        runId: initial.runId,
        attemptId: initial.attemptId,
        now: preparedAt.add(const Duration(seconds: 1)),
      );

      final reopened = CockpitWorkerCaseRunStore.file(
        workspaceId: 'workspaceA',
        path: path,
        permissionHardener: hardener,
        directorySyncer: const _NoopDirectorySyncer(),
      );
      expect(
        await reopened.recover(now: preparedAt.add(const Duration(seconds: 2))),
        1,
      );
      final retry = await reopened.reserve(
        idempotencyKey: 'case-run-A',
        requestFingerprint: _fingerprint('a'),
        caseId: 'caseA',
        proposedRunId: 'run_should_not_replace',
        proposedAttemptId: 'attempt_B',
        now: preparedAt.add(const Duration(seconds: 3)),
      );
      expect(retry.runId, initial.runId);
      expect(retry.attemptId, 'attempt_B');
      expect(retry.replayed, isFalse);

      final document = await _singleRecord(path);
      final attempts = document['attempts'] as List;
      expect(attempts.map((attempt) => (attempt as Map)['status']), <String>[
        'interrupted',
        'prepared',
      ]);
    },
  );

  test('replays completed output and rejects fingerprint conflicts', () async {
    final store = CockpitWorkerCaseRunStore.memory(workspaceId: 'workspaceA');
    final now = DateTime.utc(2026, 7, 22, 2);
    final reservation = await store.reserve(
      idempotencyKey: 'case-run-A',
      requestFingerprint: _fingerprint('a'),
      caseId: 'caseA',
      proposedRunId: 'run_A',
      proposedAttemptId: 'attempt_A',
      now: now,
    );
    await store.markRunning(
      idempotencyKey: 'case-run-A',
      runId: reservation.runId,
      attemptId: reservation.attemptId,
      now: now.add(const Duration(seconds: 1)),
    );
    await store.markCompleted(
      idempotencyKey: 'case-run-A',
      runId: reservation.runId,
      attemptId: reservation.attemptId,
      output: const <String, Object?>{
        'runId': 'run_A',
        'attemptId': 'attempt_A',
        'result': <String, Object?>{'outcome': 'passed'},
      },
      now: now.add(const Duration(seconds: 2)),
    );

    final replay = await store.reserve(
      idempotencyKey: 'case-run-A',
      requestFingerprint: _fingerprint('a'),
      caseId: 'caseA',
      proposedRunId: 'run_B',
      proposedAttemptId: 'attempt_B',
      now: now.add(const Duration(seconds: 3)),
    );
    expect(replay.replayed, isTrue);
    expect(replay.runId, 'run_A');
    expect(replay.attemptId, 'attempt_A');
    expect(replay.completedOutput!['result'], <String, Object?>{
      'outcome': 'passed',
    });

    await expectLater(
      store.reserve(
        idempotencyKey: 'case-run-A',
        requestFingerprint: _fingerprint('b'),
        caseId: 'caseA',
        proposedRunId: 'run_C',
        proposedAttemptId: 'attempt_C',
        now: now.add(const Duration(seconds: 4)),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>().having(
          (error) => error.code,
          'code',
          'idempotencyConflict',
        ),
      ),
    );
  });

  test(
    'shards completed case runs beyond the former global capacity',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'cockpit-case-runs-capacity-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final path = p.join(await temporary.resolveSymbolicLinks(), 'case_runs');
      final hardener = Platform.isWindows
          ? const CockpitWindowsInheritedAclPermissionHardener()
          : const CockpitPosixPermissionHardener();
      final store = CockpitWorkerCaseRunStore.file(
        workspaceId: 'workspaceA',
        path: path,
        permissionHardener: hardener,
        directorySyncer: const _NoopDirectorySyncer(),
      );
      final now = DateTime.utc(2026, 7, 22, 3);
      final payload = List<String>.filled(750 * 1024, 'x').join();
      for (var index = 0; index < 12; index += 1) {
        final key = 'capacity-$index';
        final reservation = await store.reserve(
          idempotencyKey: key,
          requestFingerprint: _fingerprint('a'),
          caseId: 'case_$index',
          proposedRunId: 'run_$index',
          proposedAttemptId: 'attempt_$index',
          now: now,
        );
        await store.markRunning(
          idempotencyKey: key,
          runId: reservation.runId,
          attemptId: reservation.attemptId,
          now: now.add(const Duration(seconds: 1)),
        );
        await store.markCompleted(
          idempotencyKey: key,
          runId: reservation.runId,
          attemptId: reservation.attemptId,
          output: <String, Object?>{'payload': payload},
          now: now.add(const Duration(seconds: 2)),
        );
      }

      final records = await _recordFiles(path);
      expect(records, hasLength(12));
      final totalBytes = (await Future.wait(
        records.map((file) => file.length()),
      )).fold<int>(0, (total, length) => total + length);
      expect(totalBytes, greaterThan(8 * 1024 * 1024));

      final reopened = CockpitWorkerCaseRunStore.file(
        workspaceId: 'workspaceA',
        path: path,
        permissionHardener: hardener,
        directorySyncer: const _NoopDirectorySyncer(),
      );
      expect(
        await reopened.recover(now: now.add(const Duration(seconds: 3))),
        0,
      );
      final replay = await reopened.reserve(
        idempotencyKey: 'capacity-11',
        requestFingerprint: _fingerprint('a'),
        caseId: 'case_11',
        proposedRunId: 'run_replacement',
        proposedAttemptId: 'attempt_replacement',
        now: now.add(const Duration(seconds: 3)),
      );
      expect(replay.replayed, isTrue);
      expect(replay.runId, 'run_11');
      expect(replay.completedOutput?['payload'], payload);
      await expectLater(
        reopened.reserve(
          idempotencyKey: 'capacity-11',
          requestFingerprint: _fingerprint('b'),
          caseId: 'case_11',
          proposedRunId: 'run_conflict',
          proposedAttemptId: 'attempt_conflict',
          now: now.add(const Duration(seconds: 4)),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'idempotencyConflict',
          ),
        ),
      );
    },
  );

  test('recovery rejects a corrupted case-run record', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'cockpit-case-runs-corrupt-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final path = p.join(await temporary.resolveSymbolicLinks(), 'case_runs');
    final hardener = Platform.isWindows
        ? const CockpitWindowsInheritedAclPermissionHardener()
        : const CockpitPosixPermissionHardener();
    final store = CockpitWorkerCaseRunStore.file(
      workspaceId: 'workspaceA',
      path: path,
      permissionHardener: hardener,
      directorySyncer: const _NoopDirectorySyncer(),
    );
    await store.reserve(
      idempotencyKey: 'corrupt-record',
      requestFingerprint: _fingerprint('c'),
      caseId: 'case_corrupt',
      proposedRunId: 'run_corrupt',
      proposedAttemptId: 'attempt_corrupt',
      now: DateTime.utc(2026, 7, 22, 4),
    );
    final record = (await _recordFiles(path)).single;
    await record.writeAsString('{');

    await expectLater(
      store.recover(now: DateTime.utc(2026, 7, 22, 4, 0, 1)),
      throwsA(
        isA<CockpitStorageException>().having(
          (error) => error.code,
          'code',
          'storageCorrupt',
        ),
      ),
    );
  });

  test(
    'recovers exact active temp remnants and rejects unknown files',
    () async {
      final fixture = await _CaseStoreFixture.create('case-temp-remnant');
      addTearDown(fixture.dispose);
      final now = DateTime.utc(2026, 7, 22, 5);
      await fixture.store.reserve(
        idempotencyKey: 'case-temp',
        requestFingerprint: _fingerprint('a'),
        caseId: 'case_temp',
        proposedRunId: 'run_temp',
        proposedAttemptId: 'attempt_temp',
        now: now,
      );
      final record = (await _recordFiles(fixture.path)).single;
      final temp = await File(
        p.join(
          record.parent.path,
          '.record.json.321.${List<String>.filled(24, 'b').join()}.tmp',
        ),
      ).writeAsString('partial');

      expect(
        await fixture.reopen().recover(
          now: now.add(const Duration(seconds: 1)),
        ),
        1,
      );
      expect(await temp.exists(), isFalse);

      final retry = await fixture.reopen().reserve(
        idempotencyKey: 'case-temp',
        requestFingerprint: _fingerprint('a'),
        caseId: 'case_temp',
        proposedRunId: 'run_other',
        proposedAttemptId: 'attempt_retry',
        now: now.add(const Duration(seconds: 2)),
      );
      final unknown = await File(
        p.join(record.parent.path, '.record.json.invalid.tmp'),
      ).writeAsString('invalid');
      await expectLater(
        fixture.reopen().markRunning(
          idempotencyKey: 'case-temp',
          runId: retry.runId,
          attemptId: retry.attemptId,
          now: now.add(const Duration(seconds: 3)),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await unknown.exists(), isTrue);
      await unknown.delete();
      final wrongTarget = await File(
        p.join(
          record.parent.path,
          '.other.json.321.${List<String>.filled(24, 'd').join()}.tmp',
        ),
      ).writeAsString('wrong');
      await expectLater(
        fixture.reopen().markRunning(
          idempotencyKey: 'case-temp',
          runId: retry.runId,
          attemptId: retry.attemptId,
          now: now.add(const Duration(seconds: 4)),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await wrongTarget.exists(), isTrue);
    },
  );

  test('active case record symlinks fail closed', () async {
    if (Platform.isWindows) return;
    final fixture = await _CaseStoreFixture.create('case-symlink');
    addTearDown(fixture.dispose);
    final now = DateTime.utc(2026, 7, 22, 6);
    await fixture.store.reserve(
      idempotencyKey: 'case-symlink',
      requestFingerprint: _fingerprint('b'),
      caseId: 'case_symlink',
      proposedRunId: 'run_symlink',
      proposedAttemptId: 'attempt_symlink',
      now: now,
    );
    final record = (await _recordFiles(fixture.path)).single;
    await Link(p.join(record.parent.path, 'unknown.json')).create(record.path);

    await expectLater(
      fixture.reopen().recover(now: now.add(const Duration(seconds: 1))),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'case active manifest corruption and hash tampering fail closed',
    () async {
      final corrupt = await _CaseStoreFixture.create('case-manifest-corrupt');
      addTearDown(corrupt.dispose);
      await corrupt.store.recover(now: DateTime.utc(2026, 7, 22, 7));
      await _manifestFile(corrupt.path).writeAsString('{');
      await expectLater(
        corrupt.reopen().recover(now: DateTime.utc(2026, 7, 22, 7, 0, 1)),
        throwsA(isA<CockpitStorageException>()),
      );

      final tampered = await _CaseStoreFixture.create('case-manifest-tamper');
      addTearDown(tampered.dispose);
      await tampered.store.reserve(
        idempotencyKey: 'case-manifest-tamper',
        requestFingerprint: _fingerprint('c'),
        caseId: 'case_tamper',
        proposedRunId: 'run_tamper',
        proposedAttemptId: 'attempt_tamper',
        now: DateTime.utc(2026, 7, 22, 8),
      );
      final manifest =
          jsonDecode(await _manifestFile(tampered.path).readAsString())
              as Map<String, Object?>;
      final records = manifest['records']! as Map<String, Object?>;
      final value = records.values.single;
      records
        ..clear()
        ..[List<String>.filled(64, '0').join()] = value;
      await _manifestFile(tampered.path).writeAsString(jsonEncode(manifest));
      await expectLater(
        tampered.reopen().recover(now: DateTime.utc(2026, 7, 22, 8, 0, 1)),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('both case active-manifest crash windows recover safely', () async {
    final missing = await _CaseStoreFixture.create('case-missing-record');
    addTearDown(missing.dispose);
    await missing.store.recover(now: DateTime.utc(2026, 7, 22, 9));
    await _writeCaseManifest(missing.path, <String>['missing-case-record']);
    expect(
      await missing.reopen().recover(now: DateTime.utc(2026, 7, 22, 9, 0, 1)),
      0,
    );
    expect(await _manifestRecords(missing.path), isEmpty);

    final completed = await _CaseStoreFixture.create('case-completed-window');
    addTearDown(completed.dispose);
    final now = DateTime.utc(2026, 7, 22, 10);
    final reservation = await completed.store.reserve(
      idempotencyKey: 'case-completed-window',
      requestFingerprint: _fingerprint('d'),
      caseId: 'case_completed',
      proposedRunId: 'run_completed',
      proposedAttemptId: 'attempt_completed',
      now: now,
    );
    await completed.store.markRunning(
      idempotencyKey: 'case-completed-window',
      runId: reservation.runId,
      attemptId: reservation.attemptId,
      now: now,
    );
    final activeBeforeCompletion = await _manifestFile(
      completed.path,
    ).readAsString();
    await completed.store.markCompleted(
      idempotencyKey: 'case-completed-window',
      runId: reservation.runId,
      attemptId: reservation.attemptId,
      output: const <String, Object?>{'outcome': 'passed'},
      now: now.add(const Duration(seconds: 1)),
    );
    await _manifestFile(completed.path).writeAsString(activeBeforeCompletion);
    expect(
      await completed.reopen().recover(
        now: now.add(const Duration(seconds: 2)),
      ),
      0,
    );
    expect(await _manifestRecords(completed.path), isEmpty);
    final replay = await completed.reopen().reserve(
      idempotencyKey: 'case-completed-window',
      requestFingerprint: _fingerprint('d'),
      caseId: 'case_completed',
      proposedRunId: 'run_other',
      proposedAttemptId: 'attempt_other',
      now: now.add(const Duration(seconds: 3)),
    );
    expect(replay.replayed, isTrue);
    expect(replay.completedOutput, const <String, Object?>{
      'outcome': 'passed',
    });
  });

  test('case startup ignores inactive completed record contents', () async {
    final fixture = await _CaseStoreFixture.create('case-inactive-records');
    addTearDown(fixture.dispose);
    final now = DateTime.utc(2026, 7, 22, 11);
    for (var index = 0; index < 6; index += 1) {
      final key = 'case-inactive-$index';
      final reservation = await fixture.store.reserve(
        idempotencyKey: key,
        requestFingerprint: _fingerprint('e'),
        caseId: 'case_$index',
        proposedRunId: 'run_$index',
        proposedAttemptId: 'attempt_$index',
        now: now,
      );
      await fixture.store.markRunning(
        idempotencyKey: key,
        runId: reservation.runId,
        attemptId: reservation.attemptId,
        now: now,
      );
      await fixture.store.markCompleted(
        idempotencyKey: key,
        runId: reservation.runId,
        attemptId: reservation.attemptId,
        output: const <String, Object?>{'outcome': 'passed'},
        now: now.add(const Duration(seconds: 1)),
      );
    }
    final corruptHash = sha256
        .convert(utf8.encode('case-inactive-0'))
        .toString();
    await File(
      p.join(
        fixture.path,
        'records',
        corruptHash.substring(0, 2),
        corruptHash,
        'record.json',
      ),
    ).writeAsString('{');

    expect(
      await fixture.reopen().recover(now: now.add(const Duration(seconds: 2))),
      0,
    );
    final replay = await fixture.reopen().reserve(
      idempotencyKey: 'case-inactive-5',
      requestFingerprint: _fingerprint('e'),
      caseId: 'case_5',
      proposedRunId: 'run_other',
      proposedAttemptId: 'attempt_other',
      now: now.add(const Duration(seconds: 3)),
    );
    expect(replay.replayed, isTrue);
  });

  test('case initial manifest crash requires an empty record store', () async {
    final fresh = await _CaseStoreFixture.create('case-initial-manifest');
    addTearDown(fresh.dispose);
    final active = await Directory(
      p.join(fresh.path, 'active'),
    ).create(recursive: true);
    final temp = await File(
      p.join(
        active.path,
        '.manifest.json.222.${List<String>.filled(24, 'd').join()}.tmp',
      ),
    ).writeAsString('partial');
    expect(await fresh.store.recover(now: DateTime.utc(2026, 7, 22, 12)), 0);
    expect(await temp.exists(), isFalse);
    expect(await _manifestFile(fresh.path).exists(), isTrue);

    final existing = await _CaseStoreFixture.create('case-missing-manifest');
    addTearDown(existing.dispose);
    await existing.store.reserve(
      idempotencyKey: 'case-manifest-deleted',
      requestFingerprint: _fingerprint('f'),
      caseId: 'case_manifest_deleted',
      proposedRunId: 'run_manifest_deleted',
      proposedAttemptId: 'attempt_manifest_deleted',
      now: DateTime.utc(2026, 7, 22, 13),
    );
    await _manifestFile(existing.path).delete();
    await expectLater(
      existing.reopen().recover(now: DateTime.utc(2026, 7, 22, 13, 0, 1)),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'case record temp evidence is recovered under its record lock',
    () async {
      final fixture = await _CaseStoreFixture.create('case-record-temp');
      addTearDown(fixture.dispose);
      const key = 'case-record-temp-evidence';
      final hash = sha256.convert(utf8.encode(key)).toString();
      await Directory(p.join(fixture.path, 'active')).create(recursive: true);
      await _writeCaseManifest(fixture.path, const <String>[key]);
      final recordDirectory = await Directory(
        p.join(fixture.path, 'records', hash.substring(0, 2), hash),
      ).create(recursive: true);
      final temp = await File(
        p.join(
          recordDirectory.path,
          '.record.json.444.${List<String>.filled(24, 'f').join()}.tmp',
        ),
      ).writeAsString('partial');

      await expectLater(
        fixture.reopen().recover(now: DateTime.utc(2026, 7, 22, 14)),
        throwsA(isA<FormatException>()),
      );

      expect(await temp.exists(), isFalse);
      expect((await _manifestRecords(fixture.path)).values, contains(key));
    },
  );
}

String _fingerprint(String character) => List.filled(64, character).join();

Future<Map<Object?, Object?>> _singleRecord(String root) async {
  final records = await _recordFiles(root);
  expect(records, hasLength(1));
  return jsonDecode(await records.single.readAsString())
      as Map<Object?, Object?>;
}

Future<List<File>> _recordFiles(String root) async => Directory(root)
    .list(recursive: true, followLinks: false)
    .where(
      (entity) => entity is File && p.basename(entity.path) == 'record.json',
    )
    .cast<File>()
    .toList();

final class _NoopDirectorySyncer implements CockpitDirectorySyncer {
  const _NoopDirectorySyncer();

  @override
  Future<void> sync(String directoryPath) async {}
}

final class _CaseStoreFixture {
  _CaseStoreFixture(this.directory, this.path, this.hardener)
    : store = CockpitWorkerCaseRunStore.file(
        workspaceId: 'workspaceA',
        path: path,
        permissionHardener: hardener,
        directorySyncer: const _NoopDirectorySyncer(),
      );

  static Future<_CaseStoreFixture> create(String prefix) async {
    final directory = await Directory.systemTemp.createTemp('$prefix-');
    final path = p.join(await directory.resolveSymbolicLinks(), 'case_runs');
    final hardener = Platform.isWindows
        ? const CockpitWindowsInheritedAclPermissionHardener()
        : const CockpitPosixPermissionHardener();
    return _CaseStoreFixture(directory, path, hardener);
  }

  final Directory directory;
  final String path;
  final CockpitPermissionHardener hardener;
  final CockpitWorkerCaseRunStore store;

  CockpitWorkerCaseRunStore reopen() => CockpitWorkerCaseRunStore.file(
    workspaceId: 'workspaceA',
    path: path,
    permissionHardener: hardener,
    directorySyncer: const _NoopDirectorySyncer(),
  );

  Future<void> dispose() => directory.delete(recursive: true);
}

File _manifestFile(String root) =>
    File(p.join(root, 'active', 'manifest.json'));

Future<Map<String, Object?>> _manifestRecords(String root) async {
  final manifest =
      jsonDecode(await _manifestFile(root).readAsString())
          as Map<String, Object?>;
  return manifest['records']! as Map<String, Object?>;
}

Future<void> _writeCaseManifest(String root, List<String> keys) async {
  await _manifestFile(root).writeAsString(
    jsonEncode(<String, Object?>{
      'schemaVersion': 'cockpit.worker.case-run-active/v1',
      'records': <String, Object?>{
        for (final key in keys)
          sha256.convert(utf8.encode(key)).toString(): key,
      },
    }),
  );
}
