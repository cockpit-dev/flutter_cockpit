import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/artifacts/cockpit_test_attempt_bundle_writer.dart';
import 'package:cockpit/src/artifacts/cockpit_test_attempt_recorder.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const writer = CockpitTestAttemptBundleWriter();
  const reader = CockpitTestAttemptBundleReader();

  test('publishes and verifies an immutable identity-scoped bundle', () async {
    final root = await Directory.systemTemp.createTemp('cockpit-v2-bundle-');
    addTearDown(() => root.delete(recursive: true));
    final result = _result(evidence: const <String>['artifact000001']);
    final summary = await writer.write(
      rootPath: root.path,
      context: result.context,
      sourceSha256: _hash('a'),
      result: result,
      artifacts: <CockpitTestRecordedArtifact>[
        CockpitTestRecordedArtifact(
          artifactId: 'artifact000001',
          kind: 'screenshot',
          relativePath: 'screenshots/final.png',
          mediaType: 'image/png',
          stepExecutionId: 'main/verify',
          bytes: const <int>[1, 2, 3, 4],
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 20, 1),
    );

    expect(
      p.normalize(summary.path),
      p.normalize(
        p.join(
          root.path,
          'projectOne',
          'workspaceOne',
          'runOne',
          'cases',
          'bundleCase',
          'attempts',
          'attemptOne',
        ),
      ),
    );
    final manifest = await reader.readAndVerify(
      path: summary.path,
      expectedManifestSha256: summary.manifestSha256,
    );
    expect(manifest.schemaVersion, 'cockpit.report/v2');
    expect(manifest.artifacts.single.sizeBytes, 4);
    expect(jsonEncode(manifest.toJson()), isNot(contains('taskId')));

    await expectLater(
      writer.write(
        rootPath: root.path,
        context: result.context,
        sourceSha256: _hash('a'),
        result: result,
        artifacts: const <CockpitTestRecordedArtifact>[],
        createdAt: DateTime.utc(2026, 7, 20, 1),
      ),
      throwsA(isA<CockpitTestBundlePublicationException>()),
    );
  });

  test('verification detects artifact tampering', () async {
    final root = await Directory.systemTemp.createTemp('cockpit-v2-tamper-');
    addTearDown(() => root.delete(recursive: true));
    final result = _result(evidence: const <String>['artifact000001']);
    final summary = await writer.write(
      rootPath: root.path,
      context: result.context,
      sourceSha256: _hash('b'),
      result: result,
      artifacts: <CockpitTestRecordedArtifact>[
        CockpitTestRecordedArtifact(
          artifactId: 'artifact000001',
          kind: 'snapshot',
          relativePath: 'snapshots/state.json',
          mediaType: 'application/json',
          stepExecutionId: 'main/verify',
          bytes: utf8.encode('{}'),
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 20, 1),
    );
    await File(
      p.join(summary.path, 'snapshots', 'state.json'),
    ).writeAsString('{"tampered":true}', flush: true);

    await expectLater(
      reader.readAndVerify(path: summary.path),
      throwsA(
        isA<CockpitTestBundleIntegrityException>().having(
          (error) => error.error.code,
          'code',
          CockpitTestErrorCode.bundleIntegrityFailed,
        ),
      ),
    );
  });

  test('publication rejects evidence without a matching artifact', () async {
    final root = await Directory.systemTemp.createTemp('cockpit-v2-index-');
    addTearDown(() => root.delete(recursive: true));
    final result = _result(evidence: const <String>['artifact000001']);

    await expectLater(
      writer.write(
        rootPath: root.path,
        context: result.context,
        sourceSha256: _hash('c'),
        result: result,
        artifacts: const <CockpitTestRecordedArtifact>[],
        createdAt: DateTime.utc(2026, 7, 20, 1),
      ),
      throwsA(isA<CockpitTestBundlePublicationException>()),
    );
    expect(
      Directory(
        p.join(
          root.path,
          'projectOne',
          'workspaceOne',
          'runOne',
          'cases',
          'bundleCase',
          'attempts',
          'attemptOne',
        ),
      ).existsSync(),
      isFalse,
    );
  });

  test('indexes evidence for repeated execution occurrences', () async {
    final root = await Directory.systemTemp.createTemp(
      'cockpit-v2-occurrence-index-',
    );
    addTearDown(() => root.delete(recursive: true));
    final result = _resultWithRepeatedOccurrences();
    final summary = await writer.write(
      rootPath: root.path,
      context: result.context,
      sourceSha256: _hash('d'),
      result: result,
      artifacts: <CockpitTestRecordedArtifact>[
        CockpitTestRecordedArtifact(
          artifactId: 'artifact000001',
          kind: 'screenshot',
          relativePath: 'screenshots/attempt-1.png',
          mediaType: 'image/png',
          stepExecutionId: 'main/retry/retryBack',
          bytes: const <int>[1],
        ),
        CockpitTestRecordedArtifact(
          artifactId: 'artifact000002',
          kind: 'screenshot',
          relativePath: 'screenshots/attempt-2.png',
          mediaType: 'image/png',
          stepExecutionId: 'main/retry/retryBack',
          bytes: const <int>[2],
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 20, 1),
    );

    final manifest = await reader.readAndVerify(path: summary.path);
    expect(manifest.evidenceIndex, hasLength(2));
    expect(manifest.evidenceIndex.map((entry) => entry.stepResultIndex), <int>[
      0,
      1,
    ]);
    expect(
      manifest.evidenceIndex.map((entry) => entry.artifactIds.single),
      <String>['artifact000001', 'artifact000002'],
    );
  });

  test('publication rejects Windows absolute artifact paths', () async {
    final root = await Directory.systemTemp.createTemp(
      'cockpit-v2-windows-path-',
    );
    addTearDown(() => root.delete(recursive: true));
    final result = _result(evidence: const <String>['artifact000001']);

    await expectLater(
      writer.write(
        rootPath: root.path,
        context: result.context,
        sourceSha256: _hash('e'),
        result: result,
        artifacts: <CockpitTestRecordedArtifact>[
          CockpitTestRecordedArtifact(
            artifactId: 'artifact000001',
            kind: 'snapshot',
            relativePath: 'C:/outside/attempt.json',
            mediaType: 'application/json',
            stepExecutionId: 'main/verify',
            bytes: const <int>[1],
          ),
        ],
        createdAt: DateTime.utc(2026, 7, 20, 1),
      ),
      throwsA(isA<CockpitTestBundlePublicationException>()),
    );
  });
}

CockpitTestAttemptResult _result({required List<String> evidence}) {
  final context = CockpitTestRunContext(
    projectId: 'projectOne',
    workspaceId: 'workspaceOne',
    runId: 'runOne',
    caseId: 'bundleCase',
    attemptId: 'attemptOne',
    engineVersion: '2.0.0',
  );
  return CockpitTestAttemptResult(
    context: context,
    lifecycle: CockpitTestLifecycle.completed,
    outcome: CockpitTestOutcome.passed,
    stability: CockpitTestStability.stable,
    startedAt: DateTime.utc(2026, 7, 20),
    finishedAt: DateTime.utc(2026, 7, 20, 0, 0, 1),
    durationMs: 1000,
    targetId: 'deviceOne',
    platform: 'android',
    requestedPlane: CockpitTestPlane.semantic,
    actualPlane: CockpitTestPlane.semantic,
    steps: <CockpitTestStepResult>[
      CockpitTestStepResult(
        stepId: 'verify',
        executionId: 'main/verify',
        section: 'main',
        status: CockpitTestStepStatus.passed,
        startedAt: DateTime.utc(2026, 7, 20),
        durationMs: 10,
        evidence: evidence,
      ),
    ],
  );
}

String _hash(String character) => List<String>.filled(64, character).join();

CockpitTestAttemptResult _resultWithRepeatedOccurrences() {
  final context = CockpitTestRunContext(
    projectId: 'projectOne',
    workspaceId: 'workspaceOne',
    runId: 'runOne',
    caseId: 'bundleCase',
    attemptId: 'attemptOne',
    engineVersion: '2.0.0',
  );
  CockpitTestStepResult step(int attempt, String artifactId) =>
      CockpitTestStepResult(
        stepId: 'retryBack',
        executionId: 'main/retry/retryBack',
        section: 'main',
        status: CockpitTestStepStatus.passed,
        startedAt: DateTime.utc(2026, 7, 20),
        durationMs: 10,
        occurrence: CockpitTestStepOccurrence(retryAttempt: attempt),
        evidence: <String>[artifactId],
      );
  return CockpitTestAttemptResult(
    context: context,
    lifecycle: CockpitTestLifecycle.completed,
    outcome: CockpitTestOutcome.passed,
    stability: CockpitTestStability.flaky,
    startedAt: DateTime.utc(2026, 7, 20),
    finishedAt: DateTime.utc(2026, 7, 20, 0, 0, 1),
    durationMs: 1000,
    targetId: 'deviceOne',
    platform: 'android',
    requestedPlane: CockpitTestPlane.semantic,
    actualPlane: CockpitTestPlane.semantic,
    steps: <CockpitTestStepResult>[
      step(1, 'artifact000001'),
      step(2, 'artifact000002'),
    ],
  );
}
