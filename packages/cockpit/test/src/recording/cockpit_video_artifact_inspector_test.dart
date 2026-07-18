import 'dart:async';
import 'dart:io';

import 'package:cockpit/src/recording/cockpit_video_artifact_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CockpitVideoArtifactInspector', () {
    test('rejects malformed ffprobe JSON as invalid media', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          return ProcessResult(41, 0, '{malformed-json', '');
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoProbeMalformed');
      expect(result.failureKind, CockpitVideoArtifactFailureKind.invalidMedia);
    });

    test('rejects metadata without a video stream', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          return ProcessResult(42, 0, _audioOnlyProbeJson, '');
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoStreamMissing');
      expect(result.failureKind, CockpitVideoArtifactFailureKind.invalidMedia);
    });

    test('rejects nonpositive video dimensions', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          return ProcessResult(
            43,
            0,
            _videoProbeJson(width: 0, height: 720, duration: '2.500'),
            '',
          );
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoInvalidDimensions');
      expect(result.failureKind, CockpitVideoArtifactFailureKind.invalidMedia);
      expect(result.details, containsPair('width', 0));
    });

    test('rejects nonpositive video duration', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          return ProcessResult(
            44,
            0,
            _videoProbeJson(width: 1280, height: 720, duration: '0.000'),
            '',
          );
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoInvalidDuration');
      expect(result.failureKind, CockpitVideoArtifactFailureKind.invalidMedia);
    });

    test('rejects a nonzero one-frame ffmpeg decode', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final calls = <String>[];
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          calls.add(executable);
          if (executable == 'ffprobe') {
            return ProcessResult(
              45,
              0,
              _videoProbeJson(width: 1280, height: 720, duration: '2.500'),
              '',
            );
          }
          return ProcessResult(
            46,
            1,
            '',
            'Error while decoding stream #0:0: Invalid data found',
          );
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(calls, <String>['ffprobe', 'ffmpeg']);
      expect(result.isValid, isFalse);
      expect(result.code, 'videoDecodeFailed');
      expect(result.failureKind, CockpitVideoArtifactFailureKind.invalidMedia);
      expect(result.details['exitCode'], 1);
    });

    test('accepts usable metadata and a decoded frame', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final calls = <({String executable, List<String> arguments})>[];
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          calls.add((
            executable: executable,
            arguments: List<String>.from(arguments),
          ));
          if (executable == 'ffprobe') {
            return ProcessResult(
              47,
              0,
              _videoProbeJson(width: 1280, height: 720, duration: '2.500'),
              '',
            );
          }
          return ProcessResult(48, 0, '', '');
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isTrue);
      expect(result.code, 'validVideoArtifact');
      expect(result.failureKind, isNull);
      expect(result.details['codecName'], 'h264');
      expect(result.details['width'], 1280);
      expect(result.details['height'], 720);
      expect(result.details['durationSeconds'], 2.5);
      expect(calls, hasLength(2));
      expect(calls[0].arguments, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_entries',
        'stream=codec_name,codec_type,width,height:format=duration',
        fixture.file.path,
      ]);
      expect(
        calls[1].arguments,
        containsAllInOrder(<String>[
          '-i',
          fixture.file.path,
          '-frames:v',
          '1',
          '-f',
          'null',
          '-',
        ]),
      );
    });

    test('classifies a missing ffprobe executable as unavailable', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) {
          throw ProcessException(
            executable,
            arguments,
            'No such file or directory',
          );
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoValidatorUnavailable');
      expect(
        result.failureKind,
        CockpitVideoArtifactFailureKind.validatorUnavailable,
      );
      expect(result.details['executable'], 'ffprobe');
    });

    test('classifies a missing ffmpeg executable as unavailable', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              49,
              0,
              _videoProbeJson(width: 1280, height: 720, duration: '2.500'),
              '',
            );
          }
          throw ProcessException(
            executable,
            arguments,
            'No such file or directory',
          );
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoValidatorUnavailable');
      expect(
        result.failureKind,
        CockpitVideoArtifactFailureKind.validatorUnavailable,
      );
      expect(result.details['executable'], 'ffmpeg');
    });

    test('bounds one-frame decoding with the configured timeout', () async {
      final fixture = await _VideoFixture.create();
      addTearDown(fixture.dispose);
      final inspector = CockpitVideoArtifactInspector(
        decodeTimeout: const Duration(seconds: 3),
        processRunner: (executable, arguments, {required timeout}) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              50,
              0,
              _videoProbeJson(width: 1280, height: 720, duration: '2.500'),
              '',
            );
          }
          expect(timeout, const Duration(seconds: 3));
          throw TimeoutException('ffmpeg decode exceeded 3 seconds');
        },
      );

      final result = await inspector.inspect(fixture.file.path);

      expect(result.isValid, isFalse);
      expect(result.code, 'videoValidationTimedOut');
      expect(
        result.failureKind,
        CockpitVideoArtifactFailureKind.validatorUnavailable,
      );
      expect(result.details['executable'], 'ffmpeg');
      expect(result.details['timeoutMs'], 3000);
    });
  });
}

final class _VideoFixture {
  const _VideoFixture({required this.directory, required this.file});

  final Directory directory;
  final File file;

  static Future<_VideoFixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'cockpit_video_inspector_test_',
    );
    final file = File(p.join(directory.path, 'recording.mp4'));
    await file.writeAsBytes(const <int>[
      0,
      0,
      0,
      24,
      102,
      116,
      121,
      112,
      105,
      115,
      111,
      109,
    ]);
    return _VideoFixture(directory: directory, file: file);
  }

  Future<void> dispose() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

String _videoProbeJson({
  required int width,
  required int height,
  required String duration,
}) {
  return '''
{
  "streams": [
    {
      "index": 0,
      "codec_name": "h264",
      "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
      "profile": "High",
      "codec_type": "video",
      "width": $width,
      "height": $height,
      "coded_width": $width,
      "coded_height": $height,
      "pix_fmt": "yuv420p",
      "r_frame_rate": "30/1",
      "avg_frame_rate": "30/1",
      "time_base": "1/15360"
    }
  ],
  "format": {
    "filename": "recording.mp4",
    "nb_streams": 1,
    "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
    "format_long_name": "QuickTime / MOV",
    "start_time": "0.000000",
    "duration": "$duration",
    "size": "80421",
    "bit_rate": "257347"
  }
}
''';
}

const String _audioOnlyProbeJson = '''
{
  "streams": [
    {
      "index": 0,
      "codec_name": "aac",
      "codec_long_name": "AAC (Advanced Audio Coding)",
      "codec_type": "audio",
      "sample_rate": "48000",
      "channels": 2
    }
  ],
  "format": {
    "filename": "recording.mp4",
    "nb_streams": 1,
    "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
    "duration": "2.500000"
  }
}
''';
