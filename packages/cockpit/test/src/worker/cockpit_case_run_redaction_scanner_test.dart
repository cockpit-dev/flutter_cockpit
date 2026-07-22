import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/worker/cockpit_case_run_adapter.dart';
import 'package:cockpit/src/worker/cockpit_worker_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const secret = 'exact-sensitive-value';

  test('rejects sensitive bytes in binary and malformed UTF-8 files', () async {
    for (final bytes in <List<int>>[
      <int>[0x00, 0x01, ...utf8.encode(secret), 0x02, 0x03],
      <int>[0xff, 0xfe, ...utf8.encode(secret), 0xc3, 0x28],
    ]) {
      final fixture = await _ScannerFixture.create(secret);
      addTearDown(fixture.dispose);
      await File(
        p.join(fixture.attemptRoot.path, 'capture.bin'),
      ).writeAsBytes(bytes);

      await expectLater(
        fixture.scanner.verify(fixture.attemptRoot.path),
        throwsA(_workerCode('plaintextSecretRejected')),
      );
      expect(await fixture.attemptRoot.exists(), isFalse);
    }
  });

  test('matches exact sensitive bytes across stream chunks', () async {
    final scanner = CockpitWorkerLogRedactor(
      sensitiveValues: const <String>[secret],
    ).sensitiveByteScanner();

    expect(
      await scanner.contains(
        Stream<List<int>>.fromIterable(<List<int>>[
          <int>[0xff, ...utf8.encode('exact-sens')],
          utf8.encode('itive-'),
          <int>[...utf8.encode('value'), 0xfe],
        ]),
      ),
      isTrue,
    );
  });

  test('bounds automaton nodes independently of aggregate bytes', () {
    final oversizedPattern = List<String>.filled(300000, 'x').join();

    expect(
      () => CockpitWorkerLogRedactor(
        sensitiveValues: <String>[oversizedPattern],
      ).sensitiveByteScanner(),
      throwsFormatException,
    );
  });

  test('reports a typed publication error without deleting staging', () async {
    final fixture = await _ScannerFixture.create(secret);
    addTearDown(fixture.dispose);
    await File(
      p.join(fixture.attemptRoot.path, 'manifest.json'),
    ).writeAsString('{"message":"$secret"}', flush: true);

    final error = await fixture.scanner.validateForPublication(
      fixture.attemptRoot.path,
    );

    expect(error?.code.name, 'bundlePublicationFailed');
    expect(error?.details['reason'], 'plaintextSecretRejected');
    expect(await fixture.attemptRoot.exists(), isTrue);
  });

  test(
    'rejects sensitive relative filenames and removes the attempt',
    () async {
      final fixture = await _ScannerFixture.create(secret);
      addTearDown(fixture.dispose);
      await File(
        p.join(fixture.attemptRoot.path, 'capture-$secret.bin'),
      ).writeAsBytes(const <int>[1, 2, 3]);

      await expectLater(
        fixture.scanner.verify(fixture.attemptRoot.path),
        throwsA(_workerCode('plaintextSecretRejected')),
      );
      expect(await fixture.attemptRoot.exists(), isFalse);
    },
  );

  test('rejects symlinks without deleting their external target', () async {
    if (Platform.isWindows) return;
    final fixture = await _ScannerFixture.create(secret);
    addTearDown(fixture.dispose);
    final outside = await Directory.systemTemp.createTemp(
      'cockpit-redaction-outside-',
    );
    addTearDown(() => outside.delete(recursive: true));
    final external = await File(
      p.join(outside.path, 'external.bin'),
    ).writeAsBytes(const <int>[1, 2, 3]);
    await Link(
      p.join(fixture.attemptRoot.path, 'linked.bin'),
    ).create(external.path);

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
    expect(await fixture.attemptRoot.exists(), isFalse);
    expect(await external.readAsBytes(), const <int>[1, 2, 3]);
  });

  test('streams a large artifact without rejecting safe bytes', () async {
    final fixture = await _ScannerFixture.create(secret);
    addTearDown(fixture.dispose);
    final file = File(p.join(fixture.attemptRoot.path, 'recording.mp4'));
    final sink = file.openWrite();
    final chunk = List<int>.filled(1024 * 1024, 0x5a);
    for (var index = 0; index < 16; index += 1) {
      sink.add(chunk);
    }
    await sink.close();

    await fixture.scanner.verify(fixture.attemptRoot.path);

    expect(await fixture.attemptRoot.exists(), isTrue);
    expect(await file.length(), 16 * 1024 * 1024);
  });

  test('enforces entity budget at the exact boundary', () async {
    final fixture = await _ScannerFixture.create(secret, maximumEntities: 2);
    addTearDown(fixture.dispose);
    await File(
      p.join(fixture.attemptRoot.path, 'a.bin'),
    ).writeAsBytes(<int>[1]);
    await File(
      p.join(fixture.attemptRoot.path, 'b.bin'),
    ).writeAsBytes(<int>[2]);

    await fixture.scanner.verify(fixture.attemptRoot.path);
    await File(
      p.join(fixture.attemptRoot.path, 'c.bin'),
    ).writeAsBytes(<int>[3]);

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
    expect(await fixture.attemptRoot.exists(), isFalse);
  });

  test('enforces directory depth at the exact boundary', () async {
    final fixture = await _ScannerFixture.create(secret, maximumDepth: 2);
    addTearDown(fixture.dispose);
    final first = await Directory(
      p.join(fixture.attemptRoot.path, 'one'),
    ).create();
    await File(p.join(first.path, 'safe.bin')).writeAsBytes(<int>[1]);

    await fixture.scanner.verify(fixture.attemptRoot.path);
    final second = await Directory(p.join(first.path, 'two')).create();
    await File(p.join(second.path, 'too-deep.bin')).writeAsBytes(<int>[2]);

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
  });

  test('enforces single-file bytes at the exact boundary', () async {
    final fixture = await _ScannerFixture.create(secret, maximumFileBytes: 4);
    addTearDown(fixture.dispose);
    final file = File(p.join(fixture.attemptRoot.path, 'capture.bin'));
    await file.writeAsBytes(<int>[1, 2, 3, 4]);

    await fixture.scanner.verify(fixture.attemptRoot.path);
    await file.writeAsBytes(<int>[1, 2, 3, 4, 5]);

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
  });

  test('enforces aggregate bytes at the exact boundary', () async {
    final fixture = await _ScannerFixture.create(
      secret,
      maximumFileBytes: 10,
      maximumAggregateBytes: 4,
    );
    addTearDown(fixture.dispose);
    final first = File(p.join(fixture.attemptRoot.path, 'first.bin'));
    await first.writeAsBytes(<int>[1, 2]);
    await File(
      p.join(fixture.attemptRoot.path, 'second.bin'),
    ).writeAsBytes(<int>[3, 4]);

    await fixture.scanner.verify(fixture.attemptRoot.path);
    await first.writeAsBytes(<int>[1, 2, 5]);

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
  });

  test('fails closed on deadline and chunk cancellation', () async {
    final expired = await _ScannerFixture.create(
      secret,
      deadline: DateTime.utc(2026, 7, 22),
      utcNow: () => DateTime.utc(2026, 7, 22),
    );
    addTearDown(expired.dispose);
    await expectLater(
      expired.scanner.verify(expired.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );

    var checks = 0;
    final cancelled = await _ScannerFixture.create(
      secret,
      isCancelled: () => ++checks >= 4,
    );
    addTearDown(cancelled.dispose);
    await File(
      p.join(cancelled.attemptRoot.path, 'recording.bin'),
    ).writeAsBytes(List<int>.filled(1024 * 1024, 0x5a));
    await expectLater(
      cancelled.scanner.verify(cancelled.attemptRoot.path),
      throwsA(_workerCode('caseOutputRedactionFailed')),
    );
    expect(checks, greaterThanOrEqualTo(4));
  });

  test('public verification scans arbitrary attempt subtrees', () async {
    final fixture = await _ScannerFixture.create(secret);
    addTearDown(fixture.dispose);
    final bundle = await Directory(
      p.join(fixture.attemptRoot.path, 'published', 'bundle'),
    ).create(recursive: true);
    await File(
      p.join(bundle.path, 'already-validated.bin'),
    ).writeAsString(secret);
    await File(
      p.join(fixture.attemptRoot.path, 'preparation.json'),
    ).writeAsString('{}');

    await expectLater(
      fixture.scanner.verify(fixture.attemptRoot.path),
      throwsA(_workerCode('plaintextSecretRejected')),
    );

    expect(await fixture.attemptRoot.exists(), isFalse);
  });
}

Matcher _workerCode(String code) => isA<CockpitApplicationServiceException>()
    .having((error) => error.code, 'code', code);

final class _ScannerFixture {
  _ScannerFixture(this.temporary, this.attemptRoot, this.scanner);

  final Directory temporary;
  final Directory attemptRoot;
  final CockpitCaseAttemptRedactionScanner scanner;

  static Future<_ScannerFixture> create(
    String secret, {
    DateTime? deadline,
    bool Function()? isCancelled,
    DateTime Function()? utcNow,
    int maximumEntities = 100000,
    int maximumDepth = 128,
    int maximumFileBytes = 16 * 1024 * 1024 * 1024,
    int maximumAggregateBytes = 64 * 1024 * 1024 * 1024,
  }) async {
    final temporary = await Directory.systemTemp.createTemp(
      'cockpit-case-redaction-',
    );
    final canonicalTemporary = await temporary.resolveSymbolicLinks();
    final stateRoot = await Directory(
      p.join(canonicalTemporary, 'state'),
    ).create();
    final attemptRoot = await Directory(
      p.join(stateRoot.path, 'runs', 'run_A', 'cases', 'attempt_A'),
    ).create(recursive: true);
    return _ScannerFixture(
      temporary,
      attemptRoot,
      CockpitCaseAttemptRedactionScanner(
        runStateRoot: stateRoot.path,
        redactor: CockpitWorkerLogRedactor(sensitiveValues: <String>[secret]),
        deadline: deadline,
        isCancelled: isCancelled,
        utcNow: utcNow,
        maximumEntities: maximumEntities,
        maximumDepth: maximumDepth,
        maximumFileBytes: maximumFileBytes,
        maximumAggregateBytes: maximumAggregateBytes,
      ),
    );
  }

  Future<void> dispose() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  }
}
