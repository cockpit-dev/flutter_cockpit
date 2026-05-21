import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/artifacts/cockpit_timeline_video_fallback_builder.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('writes the standard task-run directory structure', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-001',
        taskId: 'task-login',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 5),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
    );

    expect(File(p.join(outputDir.path, 'manifest.json')).existsSync(), isTrue);
    expect(
      File(p.join(outputDir.path, 'environment.json')).existsSync(),
      isTrue,
    );
    expect(File(p.join(outputDir.path, 'steps.json')).existsSync(), isTrue);
    expect(
      Directory(p.join(outputDir.path, 'screenshots')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(outputDir.path, 'recordings')).existsSync(),
      isTrue,
    );
  });

  test('writes expected manifest, handoff, and acceptance content', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-002',
        taskId: 'task-signup',
        platform: 'ios',
        status: CockpitTaskStatus.failed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 6),
        artifactRefs: const [],
        failureSummary: 'Missing snackbar.',
      ),
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nNeeds follow-up.',
      handoff: const {'status': 'failed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
    );
    final manifestJson = jsonDecode(
      await File(
        p.join(outputDir.path, 'manifest.json'),
      ).readAsString(),
    ) as Map<String, Object?>;
    final handoffJson = jsonDecode(
      await File(p.join(outputDir.path, 'handoff.json')).readAsString(),
    ) as Map<String, Object?>;
    final acceptance = await File(
      p.join(outputDir.path, 'acceptance.md'),
    ).readAsString();

    expect(manifestJson['taskId'], 'task-signup');
    expect(handoffJson['status'], 'failed');
    expect(acceptance, contains('# Acceptance'));
  });

  test('writes binary artifact payloads into the bundle output', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final artifact = const CockpitArtifactRef(
      role: 'screenshot',
      relativePath: 'screenshots/home_acceptance.png',
    );
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-003',
        taskId: 'task-capture',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
        artifactRefs: [artifact],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactPayloads: <String, List<int>>{
        artifact.relativePath: <int>[137, 80, 78, 71],
      },
    );

    expect(
      File(p.join(outputDir.path, artifact.relativePath)).readAsBytesSync(),
      <int>[137, 80, 78, 71],
    );
  });

  test('rejects artifact payload paths that escape the bundle', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_escape_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-escape',
        taskId: 'task-escape',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 1),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    await expectLater(
      writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: const <String, List<int>>{
          '../outside.png': <int>[137, 80, 78, 71],
        },
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          contains('Artifact path must stay inside the task-run bundle'),
        ),
      ),
    );

    expect(File(p.join(tempDir.path, 'outside.png')).existsSync(), isFalse);
  });

  test(
    'writes delivery.json with bundle-local screenshot references',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter();
      final artifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-004',
          taskId: 'task-delivery',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 2),
          artifactRefs: [artifact],
          nativeScreenshotCount: 1,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: const [],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nDelivered.',
        handoff: const {'status': 'completed'},
        delivery: const <String, Object?>{
          'summary': 'Ready for user delivery',
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': ['screenshots/home_acceptance.png'],
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
      );

      final deliveryJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'delivery.json'),
        ).readAsString(),
      ) as Map<String, Object?>;

      expect(deliveryJson['primaryScreenshotRef'], artifact.relativePath);
      expect((deliveryJson['attachmentRefs'] as List<Object?>).cast<String>(), [
        artifact.relativePath,
      ]);
    },
  );

  test('copies recording source files into the bundle output', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter();
    final artifact = const CockpitArtifactRef(
      role: 'recording',
      relativePath: 'recordings/home_acceptance.mp4',
    );
    final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
    await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);

    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-005',
        taskId: 'task-video',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 3),
        artifactRefs: [artifact],
        recordingCount: 1,
        nativeRecordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const {'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );

    expect(
      File(p.join(outputDir.path, artifact.relativePath)).readAsBytesSync(),
      <int>[0, 1, 2, 3, 4],
    );
  });

  test(
    'synthesizes a fallback delivery video when recording failed but screenshots exist',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_fallback_video',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _FakeRecordingKeyframeExtractor(),
        timelineVideoFallbackBuilder: _FakeTimelineVideoFallbackBuilder(
          sourceRoot: tempDir.path,
          durationMs: 2400,
        ),
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 23, 2, 0, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-fallback-video',
          taskId: 'task-fallback-video',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(seconds: 4)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
          ],
          screenshotCount: 2,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_start_requested',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 200)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 1800)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_failed',
            actionArgs: const <String, Object?>{
              'failureReason': 'simctl recording output did not finalize.',
            },
            observedAt: startedAt.add(const Duration(seconds: 4)),
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': false,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final manifestJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'manifest.json'),
        ).readAsString(),
      ) as Map<String, Object?>;
      final deliveryJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'delivery.json'),
        ).readAsString(),
      ) as Map<String, Object?>;
      final handoffJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'handoff.json'),
        ).readAsString(),
      ) as Map<String, Object?>;

      expect(manifestJson['deliveryVideoReady'], isTrue);
      expect(manifestJson['recordingCount'], 1);
      expect(manifestJson['deliveryVideoFailureCodes'], isEmpty);
      expect(deliveryJson['deliveryVideoReady'], isTrue);
      expect(deliveryJson['deliveryVideoSynthesized'], isTrue);
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
            as Map<Object?, Object?>)['ready'],
        isTrue,
      );
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
            as Map<Object?, Object?>)['failureCodes'],
        isEmpty,
      );
      expect(
        ((deliveryJson['readiness'] as Map<Object?, Object?>)['video']
                as Map<Object?, Object?>)
            .containsKey('failureReason'),
        isFalse,
      );
      expect(
        deliveryJson['primaryRecordingRef'],
        'recordings/task-fallback-video_session-fallback-video_timeline_fallback.mp4',
      );
      expect(
        File(
          p.join(
            outputDir.path,
            deliveryJson['primaryRecordingRef']! as String,
          ),
        ).readAsBytesSync(),
        <int>[0, 1, 2, 3],
      );
      expect(handoffJson['deliveryVideoSynthesized'], isTrue);
      expect(
        ((handoffJson['gates']
            as Map<Object?, Object?>)['recordingReadyOrExplained']),
        isTrue,
      );
      expect(
        ((handoffJson['gateFailureCodes']
            as Map<Object?, Object?>)['recordingReadyOrExplained']),
        isEmpty,
      );
    },
  );

  test(
    'adds a midpoint keyframe when a synthesized fallback video only has early and late screenshot evidence',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_fallback_midpoint',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _SparseRecordingKeyframeExtractor(),
        timelineVideoFallbackBuilder: _FakeTimelineVideoFallbackBuilder(
          sourceRoot: tempDir.path,
          durationMs: 3125,
        ),
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 23, 2, 30, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-fallback-midpoint',
          taskId: 'task-fallback-midpoint',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 3125)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
          ],
          screenshotCount: 2,
          deliveryArtifactsReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_start_requested',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 446)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{},
            observedAt: startedAt.add(const Duration(milliseconds: 2525)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_failed',
            actionArgs: const <String, Object?>{
              'failureReason': 'simctl recording output did not finalize.',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 3125)),
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'deliveryVideoReady': false,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final deliveryJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'delivery.json'),
        ).readAsString(),
      ) as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();

      expect(deliveryJson['deliveryVideoSynthesized'], isTrue);
      expect(deliveryJson['deliveryKeyframesReady'], isTrue);
      expect(deliveryJson['keyframeCoverage'], <String, Object?>{
        'durationMs': 3269,
        'hasEarlyCoverage': true,
        'hasMidCoverage': true,
        'hasLateCoverage': true,
        'isReady': true,
      });
      expect(
        keyframes.map((keyframe) => keyframe['label']),
        containsAll(<Object?>['baseline', 'midpoint', 'tail_consistency']),
      );
      final midpoint = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'midpoint',
      );
      expect(midpoint['linkedScreenshotRef'], acceptanceArtifact.relativePath);
      expect(
        File(p.join(outputDir.path, midpoint['ref']! as String)).existsSync(),
        isTrue,
      );
    },
  );

  test('writes extracted recording keyframes into delivery metadata', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final writer = TaskRunBundleWriter(
      keyframeExtractor: _FakeRecordingKeyframeExtractor(),
    );
    final artifact = const CockpitArtifactRef(
      role: 'recording',
      relativePath: 'recordings/home_acceptance.mp4',
    );
    final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
    await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
    final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);

    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-005b',
        taskId: 'task-video-keyframes',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: startedAt,
        finishedAt: startedAt.add(const Duration(seconds: 8)),
        artifactRefs: [artifact],
        recordingCount: 1,
        nativeRecordingCount: 1,
        deliveryVideoReady: true,
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'recording_started',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'recording',
          },
          observedAt: startedAt,
        ),
        CockpitStepRecord(
          index: 1,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
          },
          observedAt: startedAt.add(const Duration(seconds: 8)),
          artifactRefs: <CockpitArtifactRef>[artifact],
        ),
      ],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nRecorded.',
      handoff: const {'status': 'completed'},
      delivery: const <String, Object?>{
        'primaryRecordingRef': 'recordings/home_acceptance.mp4',
        'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
        'deliveryVideoReady': true,
      },
    );

    final outputDir = await writer.writeBundle(
      bundle: bundle,
      outputRoot: tempDir.path,
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );

    final deliveryJson = jsonDecode(
      await File(
        p.join(outputDir.path, 'delivery.json'),
      ).readAsString(),
    ) as Map<String, Object?>;
    final keyframes = (deliveryJson['keyframes'] as List<Object?>)
        .cast<Map<Object?, Object?>>();

    expect(deliveryJson['deliveryKeyframesReady'], isTrue);
    expect(deliveryJson['keyframeCoverage'], <String, Object?>{
      'durationMs': 8000,
      'hasEarlyCoverage': true,
      'hasMidCoverage': true,
      'hasLateCoverage': true,
      'isReady': true,
    });
    expect(keyframes, hasLength(2));
    expect(
      File(
        p.join(outputDir.path, keyframes.first['ref']! as String),
      ).existsSync(),
      isTrue,
    );
  });

  test(
    'supplements sparse recording keyframes with baseline and acceptance screenshots',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final writer = TaskRunBundleWriter(
        keyframeExtractor: _SparseRecordingKeyframeExtractor(),
      );
      final recordingArtifact = const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/home_acceptance.mp4',
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/home_acceptance.png',
      );
      final sourceFile = File(p.join(tempDir.path, 'temp_recording.mp4'));
      await sourceFile.writeAsBytes(const <int>[0, 1, 2, 3, 4]);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-005c',
          taskId: 'task-video-keyframes-sparse',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 3269)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
            recordingArtifact,
          ],
          recordingCount: 1,
          nativeRecordingCount: 1,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'recording',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'baseline_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 340)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 1222)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_stopped',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'completed',
              'recordingDurationMs': 3269,
            },
            observedAt: startedAt.add(const Duration(milliseconds: 3269)),
            artifactRefs: <CockpitArtifactRef>[recordingArtifact],
          ),
        ],
        observations: const [],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const {'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/home_acceptance.png',
          'attachmentRefs': [
            'screenshots/home_baseline.png',
            'screenshots/home_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'primaryRecordingRef': 'recordings/home_acceptance.mp4',
          'videoAttachmentRefs': ['recordings/home_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: sourceFile.path,
        },
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: const <int>[137, 80, 78, 71],
          acceptanceArtifact.relativePath: const <int>[137, 80, 78, 71],
        },
      );

      final deliveryJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'delivery.json'),
        ).readAsString(),
      ) as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();

      expect(deliveryJson['deliveryKeyframesReady'], isTrue);
      expect(deliveryJson.containsKey('keyframeFailureReason'), isFalse);
      expect(deliveryJson['keyframeCoverage'], <String, Object?>{
        'durationMs': 3269,
        'hasEarlyCoverage': true,
        'hasMidCoverage': true,
        'hasLateCoverage': true,
        'isReady': true,
      });
      expect(keyframes, hasLength(3));
      expect(
        keyframes.map((keyframe) => keyframe['label']),
        containsAll(<Object?>['baseline', 'acceptance', 'tail_consistency']),
      );
      final supplementedBaseline = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'baseline',
      );
      final supplementedAcceptance = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'acceptance',
      );
      expect(
        supplementedBaseline['linkedScreenshotRef'],
        baselineArtifact.relativePath,
      );
      expect(
        supplementedAcceptance['linkedScreenshotRef'],
        acceptanceArtifact.relativePath,
      );
      expect(
        File(
          p.join(outputDir.path, supplementedBaseline['ref']! as String),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(outputDir.path, supplementedAcceptance['ref']! as String),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test(
    'chooses a tail consistency keyframe that matches the final acceptance view',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_tail_consistency',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final acceptancePng = _encodePng(_buildAcceptanceImage());
      final baselinePng = _encodePng(_buildBaselineImage());
      final staleTailPng = _encodePng(_buildStaleEditorImage());
      final recordingArtifact = const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/ios_acceptance.mp4',
      );
      final baselineArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/ios_baseline.png',
      );
      final acceptanceArtifact = const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/ios_acceptance.png',
      );
      final startedAt = DateTime.utc(2026, 3, 22, 12, 45, 29);
      final recordingFile = File(p.join(tempDir.path, 'ios_acceptance.mp4'))
        ..writeAsBytesSync(const <int>[0, 1, 2, 3, 4]);

      final writer = TaskRunBundleWriter(
        keyframeExtractor: DefaultCockpitRecordingKeyframeExtractor(
          processRunner: (executable, arguments) async {
            if (executable == 'ffprobe') {
              return ProcessResult(
                0,
                0,
                '{"streams":[{"codec_name":"hevc","codec_type":"video","width":1320,"height":2868}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"8.445"}}',
                '',
              );
            }
            if (executable == 'ffmpeg') {
              final outputPath = arguments.last;
              await File(outputPath).parent.create(recursive: true);
              if (outputPath.contains('tail_consistency')) {
                final seekValue = arguments[arguments.indexOf('-sseof') + 1];
                final bytes = switch (seekValue) {
                  '-0.600' => staleTailPng,
                  '-1.200' || '-1.800' => acceptancePng,
                  _ => <int>[],
                };
                if (bytes.isNotEmpty) {
                  await File(outputPath).writeAsBytes(bytes);
                }
                return ProcessResult(0, 0, '', '');
              }
              final bytes =
                  outputPath.contains('baseline') ? baselinePng : acceptancePng;
              await File(outputPath).writeAsBytes(bytes);
              return ProcessResult(0, 0, '', '');
            }
            throw ProcessException(
              executable,
              arguments,
              'unexpected executable',
            );
          },
        ),
      );

      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-tail-consistency',
          taskId: 'task-tail-consistency',
          platform: 'ios',
          status: CockpitTaskStatus.completed,
          startedAt: startedAt,
          finishedAt: startedAt.add(const Duration(milliseconds: 11178)),
          artifactRefs: <CockpitArtifactRef>[
            baselineArtifact,
            acceptanceArtifact,
            recordingArtifact,
          ],
          screenshotCount: 2,
          recordingCount: 1,
          nativeRecordingCount: 1,
          deliveryArtifactsReady: true,
          deliveryVideoReady: true,
        ),
        environment: const CockpitEnvironment(
          platform: 'ios',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'recording_started',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'recording',
            },
            observedAt: startedAt,
          ),
          CockpitStepRecord(
            index: 1,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'baseline_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 235)),
            requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
            artifactRefs: <CockpitArtifactRef>[baselineArtifact],
            captureRefs: <CockpitArtifactRef>[baselineArtifact],
          ),
          CockpitStepRecord(
            index: 2,
            actionType: 'captureScreenshot',
            actionArgs: const <String, Object?>{
              'commandId': 'acceptance_capture',
            },
            observedAt: startedAt.add(const Duration(milliseconds: 8445)),
            requestedCaptureProfile: CockpitCaptureProfile.acceptance,
            artifactRefs: <CockpitArtifactRef>[acceptanceArtifact],
            captureRefs: <CockpitArtifactRef>[acceptanceArtifact],
          ),
          CockpitStepRecord(
            index: 3,
            actionType: 'recording_stopped',
            actionArgs: const <String, Object?>{
              'recordingPurpose': 'acceptance',
              'recordingState': 'completed',
              'recordingDurationMs': 11178,
            },
            observedAt: startedAt.add(const Duration(milliseconds: 11178)),
            artifactRefs: <CockpitArtifactRef>[recordingArtifact],
          ),
        ],
        observations: const <CockpitObservation>[],
        acceptanceMarkdown: '# Acceptance\n\nRecorded.',
        handoff: const <String, Object?>{'status': 'completed'},
        delivery: const <String, Object?>{
          'primaryScreenshotRef': 'screenshots/ios_acceptance.png',
          'attachmentRefs': [
            'screenshots/ios_baseline.png',
            'screenshots/ios_acceptance.png',
          ],
          'deliveryArtifactsReady': true,
          'primaryRecordingRef': 'recordings/ios_acceptance.mp4',
          'videoAttachmentRefs': ['recordings/ios_acceptance.mp4'],
          'deliveryVideoReady': true,
        },
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
        artifactPayloads: <String, List<int>>{
          baselineArtifact.relativePath: baselinePng,
          acceptanceArtifact.relativePath: acceptancePng,
        },
        artifactSourcePaths: <String, String>{
          recordingArtifact.relativePath: recordingFile.path,
        },
      );

      final deliveryJson = jsonDecode(
        await File(
          p.join(outputDir.path, 'delivery.json'),
        ).readAsString(),
      ) as Map<String, Object?>;
      final keyframes = (deliveryJson['keyframes'] as List<Object?>)
          .cast<Map<Object?, Object?>>();
      final tailKeyframe = keyframes.firstWhere(
        (keyframe) => keyframe['label'] == 'tail_consistency',
      );
      final tailBytes = await File(
        p.join(outputDir.path, tailKeyframe['ref']! as String),
      ).readAsBytes();

      expect(tailBytes, acceptancePng);
    },
  );

  test(
    'externalizes forensic snapshots into diagnostics artifacts and keeps step snapshots summarized',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_test',
      );
      final writer = TaskRunBundleWriter();
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final diagnosticsArtifact = const CockpitArtifactRef(
        role: 'diagnostics',
        relativePath: 'diagnostics/step_000_snapshot.json',
      );
      final bundle = CockpitContextBundle(
        manifest: CockpitRunManifest(
          sessionId: 'session-006',
          taskId: 'task-diagnostics',
          platform: 'android',
          status: CockpitTaskStatus.completed,
          startedAt: DateTime.utc(2026, 3, 20, 8),
          finishedAt: DateTime.utc(2026, 3, 20, 8, 4),
          artifactRefs: <CockpitArtifactRef>[diagnosticsArtifact],
        ),
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        steps: <CockpitStepRecord>[
          CockpitStepRecord(
            index: 0,
            actionType: 'collectSnapshot',
            actionArgs: const <String, Object?>{},
            observedAt: DateTime.utc(2026, 3, 20, 8, 1),
            artifactRefs: <CockpitArtifactRef>[diagnosticsArtifact],
            snapshot: CockpitSnapshot(
              routeName: '/checkout',
              diagnosticLevel: CockpitSnapshotProfile.forensic,
              truncated: true,
              diagnosticsArtifactRef: diagnosticsArtifact,
              summary: CockpitSnapshotSummary(
                visibleTargetCount: 1,
                targetsWithCockpitIdCount: 1,
                targetsWithTextCount: 0,
                styleDetailsIncluded: false,
                diagnosticPropertiesIncluded: true,
                ancestorSummariesIncluded: false,
                rebuildSummaryIncluded: false,
                accessibilitySummaryIncluded: false,
              ),
              visibleTargets: <CockpitSnapshotTarget>[
                CockpitSnapshotTarget(
                  registrationId: 'checkout.submit',
                  cockpitId: 'submit_button',
                  routeName: '/checkout',
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
                  ],
                  diagnosticProperties: <CockpitDiagnosticProperty>[
                    CockpitDiagnosticProperty(
                      name: 'label',
                      value: 'Submit',
                      category: CockpitDiagnosticCategory.basic,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        observations: <CockpitObservation>[
          CockpitObservation(
            routeName: '/checkout',
            diagnosticLevel: CockpitSnapshotProfile.forensic,
            truncated: true,
            diagnosticsArtifactRef: diagnosticsArtifact,
          ),
        ],
        acceptanceMarkdown: '# Acceptance\n\nDiagnosed.',
        handoff: const {'status': 'completed'},
      );

      final outputDir = await writer.writeBundle(
        bundle: bundle,
        outputRoot: tempDir.path,
      );
      final diagnosticsJson = jsonDecode(
        File(
          p.join(outputDir.path, diagnosticsArtifact.relativePath),
        ).readAsStringSync(),
      ) as Map<String, Object?>;
      final stepsJson = jsonDecode(
        File(p.join(outputDir.path, 'steps.json')).readAsStringSync(),
      ) as List<Object?>;
      final inlineSnapshot =
          ((stepsJson.single as Map<Object?, Object?>)['snapshot']
                  as Map<Object?, Object?>?) ??
              const <Object?, Object?>{};

      expect(
        File(
          p.join(outputDir.path, diagnosticsArtifact.relativePath),
        ).existsSync(),
        isTrue,
      );
      expect(diagnosticsJson['diagnosticLevel'], 'forensic');
      expect(
        (diagnosticsJson['visibleTargets'] as List<Object?>),
        hasLength(1),
      );
      expect(
        inlineSnapshot['diagnosticsArtifactRef'],
        diagnosticsArtifact.toJson(),
      );
      expect(inlineSnapshot['truncated'], isTrue);
    },
  );
}

final class _FakeRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: const <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_baseline.png',
          label: 'baseline',
          offsetMs: 600,
          source: CockpitRecordingKeyframeSource.stepCapture,
        ),
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_tail.png',
          label: 'tail_consistency',
          offsetMs: 7600,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/home_acceptance_baseline.png': const <int>[137, 80, 78, 71],
        'keyframes/home_acceptance_tail.png': const <int>[137, 80, 78, 71],
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 8000,
        hasEarlyCoverage: true,
        hasMidCoverage: true,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _SparseRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: const <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/home_acceptance_tail.png',
          label: 'tail_consistency',
          offsetMs: 2669,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/home_acceptance_tail.png': const <int>[137, 80, 78, 71],
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 3269,
        hasEarlyCoverage: false,
        hasMidCoverage: false,
        hasLateCoverage: true,
      ),
    );
  }
}

final class _FakeTimelineVideoFallbackBuilder
    implements CockpitTimelineVideoFallbackBuilder {
  const _FakeTimelineVideoFallbackBuilder({
    required this.sourceRoot,
    required this.durationMs,
  });

  final String sourceRoot;
  final int durationMs;

  @override
  Future<CockpitTimelineVideoFallbackResult?> build({
    required CockpitContextBundle bundle,
    required String outputDirectoryPath,
  }) async {
    final file = File(p.join(sourceRoot, 'fallback-video.mp4'));
    await file.writeAsBytes(const <int>[0, 1, 2, 3]);
    return CockpitTimelineVideoFallbackResult(
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath:
            'recordings/task-fallback-video_session-fallback-video_timeline_fallback.mp4',
      ),
      sourceFilePath: file.path,
      durationMs: durationMs,
      screenshotRefs: const <String>[
        'screenshots/home_baseline.png',
        'screenshots/home_acceptance.png',
      ],
    );
  }
}

List<int> _encodePng(img.Image image) => img.encodePng(image);

img.Image _buildAcceptanceImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(9, 14, 14));
  img.fillRect(
    image,
    x1: 20,
    y1: 40,
    x2: 220,
    y2: 100,
    color: img.ColorRgb8(20, 36, 34),
  );
  img.fillRect(
    image,
    x1: 20,
    y1: 140,
    x2: 220,
    y2: 430,
    color: img.ColorRgb8(12, 19, 18),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 170,
    x2: 208,
    y2: 182,
    color: img.ColorRgb8(235, 238, 237),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 210,
    x2: 160,
    y2: 218,
    color: img.ColorRgb8(212, 216, 214),
  );
  img.fillRect(
    image,
    x1: 32,
    y1: 248,
    x2: 188,
    y2: 256,
    color: img.ColorRgb8(212, 216, 214),
  );
  return image;
}

img.Image _buildBaselineImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(14, 18, 22));
  img.fillRect(
    image,
    x1: 20,
    y1: 56,
    x2: 220,
    y2: 156,
    color: img.ColorRgb8(28, 45, 52),
  );
  return image;
}

img.Image _buildStaleEditorImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgb8(10, 14, 14));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 188,
    color: img.ColorRgb8(18, 24, 24),
  );
  img.fillRect(
    image,
    x1: 20,
    y1: 320,
    x2: 220,
    y2: 372,
    color: img.ColorRgb8(161, 195, 187),
  );
  img.fillRect(
    image,
    x1: 24,
    y1: 214,
    x2: 216,
    y2: 216,
    color: img.ColorRgb8(86, 96, 94),
  );
  return image;
}
