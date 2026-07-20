import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/artifacts/cockpit_recording_keyframe_extractor.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'extracts multiple keyframes from the recording timeline and marks coverage ready',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_extractor',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
      final steps = <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'recording_started',
          actionArgs: const <String, Object?>{
            'recordingName': 'todo-acceptance',
            'recordingPurpose': 'acceptance',
            'recordingState': 'recording',
          },
          observedAt: startedAt,
        ),
        CockpitStepRecord(
          index: 1,
          actionType: 'captureScreenshot',
          actionArgs: const <String, Object?>{'reason': 'baseline'},
          observedAt: startedAt.add(const Duration(milliseconds: 640)),
          requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/baseline.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'captureScreenshot',
          actionArgs: const <String, Object?>{'reason': 'acceptance'},
          observedAt: startedAt.add(const Duration(milliseconds: 6840)),
          requestedCaptureProfile: CockpitCaptureProfile.acceptance,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/acceptance.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 3,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingName': 'todo-acceptance',
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 7800,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 7800)),
        ),
      ];

      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":720,"height":1280}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"7.8"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildFrameImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(result.coverage.isReady, isTrue);
      expect(result.coverage.durationMs, 7800);
      expect(result.keyframes.length, greaterThanOrEqualTo(3));
      expect(
        result.keyframes.map((keyframe) => keyframe.label),
        containsAll(<String>['baseline', 'acceptance', 'tail_consistency']),
      );
      expect(
        result.keyframes
            .where((keyframe) => keyframe.linkedScreenshotRef != null)
            .map((keyframe) => keyframe.linkedScreenshotRef),
        containsAll(<String>[
          'screenshots/baseline.png',
          'screenshots/acceptance.png',
        ]),
      );
      expect(
        result.artifactPayloads.keys,
        everyElement(startsWith('keyframes/')),
      );
      expect(
        result.artifactPayloads.keys,
        everyElement(
          matches(RegExp(r'^keyframes/\d{8}ms_acceptance_[a-z0-9_]+\.png$')),
        ),
      );
      expect(
        result.artifactPayloads.keys.toList()..sort(),
        result.artifactPayloads.keys.toList(),
      );
      expect(result.coverage.hasEarlyCoverage, isTrue);
      expect(result.coverage.hasMidCoverage, isTrue);
      expect(result.coverage.hasLateCoverage, isTrue);
    },
  );

  test(
    'extracts a tail consistency frame from a real recording near the end of the timeline',
    () async {
      final ffmpegCheck = await Process.run('ffmpeg', <String>['-version']);
      final ffprobeCheck = await Process.run('ffprobe', <String>['-version']);
      if (ffmpegCheck.exitCode != 0 || ffprobeCheck.exitCode != 0) {
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_real_ffmpeg',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final sourcePng = File(p.join(tempDir.path, 'frame.png'));
      await sourcePng.writeAsBytes(_encodedPng(_buildFrameImage()));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      final createVideo = await Process.run('ffmpeg', <String>[
        '-y',
        '-loop',
        '1',
        '-i',
        sourcePng.path,
        '-t',
        '5.4',
        '-vf',
        'scale=240:480',
        '-pix_fmt',
        'yuv420p',
        recordingFile.path,
      ]);
      expect(createVideo.exitCode, 0, reason: '${createVideo.stderr}');
      expect(recordingFile.existsSync(), isTrue);

      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
      final steps = <CockpitStepRecord>[
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
          actionArgs: const <String, Object?>{'reason': 'baseline'},
          observedAt: startedAt.add(const Duration(milliseconds: 420)),
          requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/baseline.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'captureScreenshot',
          actionArgs: const <String, Object?>{'reason': 'acceptance'},
          observedAt: startedAt.add(const Duration(milliseconds: 4300)),
          requestedCaptureProfile: CockpitCaptureProfile.acceptance,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/acceptance.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 3,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 5400,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 5400)),
        ),
      ];

      const extractor = DefaultCockpitRecordingKeyframeExtractor();
      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(
        result.keyframes.any(
          (keyframe) => keyframe.label == 'tail_consistency',
        ),
        isTrue,
      );
      expect(result.coverage.hasLateCoverage, isTrue);
      expect(result.coverage.isReady, isTrue);
      expect(
        result.artifactPayloads.keys,
        contains('keyframes/00004800ms_acceptance_tail_consistency.png'),
      );
    },
  );

  test(
    'keeps tail consistency coverage even when acceptance is near the end of the recording',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_tail_dedup',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
      final steps = <CockpitStepRecord>[
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
          actionArgs: const <String, Object?>{'reason': 'acceptance'},
          observedAt: startedAt.add(const Duration(milliseconds: 4900)),
          requestedCaptureProfile: CockpitCaptureProfile.acceptance,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/acceptance.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 5400,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 5400)),
        ),
      ];

      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":720,"height":1280}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"5.4"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildFrameImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(
        result.keyframes.map((keyframe) => keyframe.label),
        containsAll(<String>['acceptance', 'tail_consistency']),
      );
      expect(result.coverage.hasLateCoverage, isTrue);
      expect(result.coverage.isReady, isTrue);
    },
  );

  test(
    'uses end-relative ffmpeg extraction for tail consistency frames',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_tail_seek',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final startedAt = DateTime.utc(2026, 3, 22, 6, 0, 0);
      final steps = <CockpitStepRecord>[
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
            'recordingDurationMs': 5290,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 5290)),
        ),
      ];
      final ffmpegCalls = <List<String>>[];
      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":720,"height":1280}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"5.290"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final usesEndRelativeSeek = arguments.contains('-sseof');
            if (!usesEndRelativeSeek &&
                outputPath.contains('tail_consistency')) {
              return ProcessResult(0, 1, '', 'tail extraction failed');
            }
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildFrameImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(
        result.keyframes.any(
          (keyframe) => keyframe.label == 'tail_consistency',
        ),
        isTrue,
      );
      final tailInvocation = ffmpegCalls.firstWhere(
        (arguments) => arguments.last.contains('tail_consistency'),
      );
      expect(tailInvocation, contains('-sseof'));
    },
  );

  test(
    'retries near-end acceptance and tail keyframes with safer offsets',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_near_end_retry',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final startedAt = DateTime.utc(2026, 3, 22, 8, 59, 33);
      final ffmpegCalls = <List<String>>[];
      final steps = <CockpitStepRecord>[
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
          actionArgs: const <String, Object?>{'reason': 'baseline'},
          observedAt: startedAt.add(const Duration(milliseconds: 372)),
          requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/baseline.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'captureScreenshot',
          actionArgs: const <String, Object?>{'reason': 'acceptance'},
          observedAt: startedAt.add(const Duration(milliseconds: 6284)),
          requestedCaptureProfile: CockpitCaptureProfile.acceptance,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/acceptance.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 3,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 9714,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 9714)),
        ),
      ];

      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":720,"height":1280}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"6.091489"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final seekValue = arguments.contains('-sseof')
                ? arguments[arguments.indexOf('-sseof') + 1]
                : arguments[arguments.indexOf('-ss') + 1];
            final shouldFail =
                outputPath.contains('acceptance') && seekValue == '6.091' ||
                outputPath.contains('tail_consistency') &&
                    seekValue == '-0.300';
            if (shouldFail) {
              return ProcessResult(0, 1, '', 'seek too close to tail');
            }
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildFrameImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(result.coverage.hasLateCoverage, isTrue);
      expect(result.coverage.isReady, isTrue);
      expect(
        result.keyframes.any((keyframe) => keyframe.label == 'acceptance'),
        isTrue,
      );
      expect(
        result.keyframes.any(
          (keyframe) => keyframe.label == 'tail_consistency',
        ),
        isTrue,
      );
      expect(
        result.keyframes
            .firstWhere((keyframe) => keyframe.label == 'acceptance')
            .linkedScreenshotRef,
        'screenshots/acceptance.png',
      );
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.last.contains('acceptance') &&
              arguments.contains('-ss') &&
              arguments[arguments.indexOf('-ss') + 1] == '6.091',
        ),
        isTrue,
      );
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.last.contains('acceptance') &&
              arguments.contains('-ss') &&
              arguments[arguments.indexOf('-ss') + 1] == '5.491',
        ),
        isTrue,
      );
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.last.contains('tail_consistency') &&
              arguments.contains('-sseof') &&
              arguments[arguments.indexOf('-sseof') + 1] == '-0.600',
        ),
        isTrue,
      );
    },
  );

  test(
    'falls back to safer midpoint and tail offsets when sparse recordings do not yield exact-frame output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_sparse_fallback',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final startedAt = DateTime.utc(2026, 3, 22, 10, 59, 9);
      final ffmpegCalls = <List<String>>[];
      final steps = <CockpitStepRecord>[
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
          actionArgs: const <String, Object?>{'reason': 'baseline'},
          observedAt: startedAt.add(const Duration(milliseconds: 324)),
          requestedCaptureProfile: CockpitCaptureProfile.diagnostic,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/baseline.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 3291,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 3291)),
        ),
      ];

      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":720,"height":1280}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"3.291"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final seekValue = arguments.contains('-sseof')
                ? arguments[arguments.indexOf('-sseof') + 1]
                : arguments[arguments.indexOf('-ss') + 1];
            final shouldWrite =
                outputPath.contains('baseline') ||
                outputPath.contains('acceptance') && seekValue == '2.691' ||
                outputPath.contains('midpoint') && seekValue == '1.496' ||
                outputPath.contains('tail_consistency') &&
                    seekValue == '-1.800';
            if (shouldWrite) {
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_encodedPng(_buildFrameImage()));
            }
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
      );

      expect(result.failureReason, isNull);
      expect(result.coverage.hasMidCoverage, isTrue);
      expect(result.coverage.hasLateCoverage, isTrue);
      expect(result.coverage.isReady, isTrue);
      expect(
        result.keyframes.any((keyframe) => keyframe.label == 'midpoint'),
        isTrue,
      );
      expect(
        result.keyframes.any(
          (keyframe) => keyframe.label == 'tail_consistency',
        ),
        isTrue,
      );
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.last.contains('midpoint') &&
              arguments.contains('-ss') &&
              arguments[arguments.indexOf('-ss') + 1] == '1.496',
        ),
        isTrue,
      );
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.last.contains('tail_consistency') &&
              arguments.contains('-sseof') &&
              arguments[arguments.indexOf('-sseof') + 1] == '-1.800',
        ),
        isTrue,
      );
    },
  );

  test(
    'matches acceptance and tail keyframes against the persisted acceptance screenshot for short recordings',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_recording_keyframe_short_acceptance_match',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'))
        ..writeAsBytesSync(_validMp4Bytes);
      final bundleDir = Directory(p.join(tempDir.path, 'bundle'));
      final screenshotsDir = Directory(p.join(bundleDir.path, 'screenshots'))
        ..createSync(recursive: true);
      final acceptanceBytes = _encodedPng(_buildFrameImage());
      File(
        p.join(screenshotsDir.path, 'acceptance.png'),
      ).writeAsBytesSync(acceptanceBytes);
      final startedAt = DateTime.utc(2026, 3, 22, 11, 20, 0);
      final ffmpegCalls = <List<String>>[];
      final steps = <CockpitStepRecord>[
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
          actionArgs: const <String, Object?>{'reason': 'acceptance'},
          observedAt: startedAt.add(const Duration(milliseconds: 2561)),
          requestedCaptureProfile: CockpitCaptureProfile.acceptance,
          captureRefs: const <CockpitArtifactRef>[
            CockpitArtifactRef(
              role: 'screenshot',
              relativePath: 'screenshots/acceptance.png',
            ),
          ],
        ),
        CockpitStepRecord(
          index: 2,
          actionType: 'recording_stopped',
          actionArgs: const <String, Object?>{
            'recordingPurpose': 'acceptance',
            'recordingState': 'completed',
            'recordingDurationMs': 2561,
          },
          observedAt: startedAt.add(const Duration(milliseconds: 2561)),
        ),
      ];

      final extractor = DefaultCockpitRecordingKeyframeExtractor(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"hevc","codec_type":"video","width":240,"height":480}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.561667"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final isLateSeek = arguments.contains('-sseof');
            final seekValue = isLateSeek
                ? arguments[arguments.indexOf('-sseof') + 1]
                : arguments[arguments.indexOf('-ss') + 1];
            final shouldMatch =
                seekValue == '1.962' ||
                seekValue == '1.662' ||
                seekValue == '-0.900' ||
                seekValue == '-0.600';
            await File(outputPath).parent.create(recursive: true);
            await File(outputPath).writeAsBytes(
              shouldMatch
                  ? acceptanceBytes
                  : _encodedPng(_buildMismatchedFrameImage()),
            );
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await extractor.extract(
        recordingPath: recordingFile.path,
        recordingRelativePath: 'recordings/acceptance.mp4',
        steps: steps,
        bundleDirectoryPath: bundleDir.path,
      );

      expect(result.failureReason, isNull);
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.contains('-sseof') &&
              arguments[arguments.indexOf('-sseof') + 1] == '-1.800',
        ),
        isFalse,
      );
      expect(
        result.artifactPayloads[result.keyframes
            .firstWhere((keyframe) => keyframe.label == 'acceptance')
            .relativePath],
        acceptanceBytes,
      );
      expect(
        result.artifactPayloads[result.keyframes
            .firstWhere((keyframe) => keyframe.label == 'tail_consistency')
            .relativePath],
        acceptanceBytes,
      );
    },
  );
}

final List<int> _validMp4Bytes = base64Decode(
  'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAuVtZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAD2WIhAAz//727L4FNhTIwQAAAAhBmiJsQr/+wAAAAAgBnkF5Cv/EgQAAA1xtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAAPoAAAAeAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACh3RyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAAeAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAEAAAABAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAAHgAAAQAAAEAAAAAAf9tZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAADIAAAAIAFXEAAAAAAAtaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlcgAAAAGqbWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAABanN0YmwAAAC+c3RzZAAAAAAAAAABAAAArmF2YzEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAEAAQAEgAAABIAAAAAAAAAAEVTGF2YzYyLjExLjEwMCBsaWJ4MjY0AAAAAAAAAAAAAAAY//8AAAA0YXZjQwFkAAr/4QAXZ2QACqzZXsBEAAADAAQAAAMAyDxIllgBAAZo6+PLIsD9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAvuIAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAMAAAIAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAAAoY3R0cwAAAAAAAAADAAAAAQAABAAAAAABAAAGAAAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAADAAAAAQAAACBzdHN6AAAAAAAAAAAAAAADAAACxQAAAAwAAAAMAAAAFHN0Y28AAAAAAAAAAQAAADAAAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYyLjMuMTAw',
);

List<int> _encodedPng(img.Image image) => img.encodePng(image);

img.Image _buildFrameImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(243, 238, 229, 255));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 84,
    color: img.ColorRgba8(20, 66, 58, 255),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 168,
    x2: 220,
    y2: 318,
    color: img.ColorRgba8(255, 255, 255, 255),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 346,
    x2: 220,
    y2: 360,
    color: img.ColorRgba8(20, 66, 58, 255),
  );
  return image;
}

img.Image _buildMismatchedFrameImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(14, 18, 18, 255));
  img.fillRect(
    image,
    x1: 22,
    y1: 30,
    x2: 218,
    y2: 180,
    color: img.ColorRgba8(108, 36, 18, 255),
  );
  img.fillRect(
    image,
    x1: 22,
    y1: 220,
    x2: 218,
    y2: 430,
    color: img.ColorRgba8(236, 233, 224, 255),
  );
  img.fillRect(
    image,
    x1: 110,
    y1: 70,
    x2: 134,
    y2: 420,
    color: img.ColorRgba8(235, 184, 72, 255),
  );
  return image;
}
