import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/recording/cockpit_video_artifact_inspector.dart';
import 'package:cockpit/src/validation/cockpit_bundle_artifact_validator.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'uses local image inspection to validate screenshot artifacts',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_png',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final file = File(p.join(tempDir.path, 'sample.png'));
      await file.writeAsBytes(_validPngBytes);

      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          fail('ordinary screenshot validation must not run $executable');
        },
      );

      final result = await validator.validateScreenshot(file.path);

      expect(result.isValid, isTrue);
      expect(result.validator, 'image');
      expect(result.details['width'], 2);
      expect(result.details['height'], 2);
    },
  );

  test('rejects screenshots without visible pixels', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_png_fallback',
    );
    addTearDown(() async => _deleteDir(tempDir));

    final file = File(p.join(tempDir.path, 'sample.png'));
    await file.writeAsBytes(
      img.encodePng(img.Image(width: 2, height: 2, numChannels: 4)),
    );

    final validator = CockpitBundleArtifactValidator(
      processRunner: (executable, arguments) async {
        fail('ordinary screenshot validation must not run $executable');
      },
    );

    final result = await validator.validateScreenshot(file.path);

    expect(result.isValid, isFalse);
    expect(result.code, 'invalidScreenshotArtifact');
    expect(result.validator, 'image');
    expect(result.details['inspectionCode'], 'screenshotFullyTransparent');
  });

  test('rejects invalid screenshot artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_png_invalid',
    );
    addTearDown(() async => _deleteDir(tempDir));

    final file = File(p.join(tempDir.path, 'sample.png'));
    await file.writeAsBytes(const <int>[1, 2, 3, 4]);

    final validator = CockpitBundleArtifactValidator(
      processRunner: (executable, arguments) async {
        fail('ordinary screenshot validation must not run $executable');
      },
    );

    final result = await validator.validateScreenshot(file.path);

    expect(result.isValid, isFalse);
    expect(result.code, 'invalidScreenshotArtifact');
  });

  test('keeps ordinary recording validation process-free', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_mp4',
    );
    addTearDown(() async => _deleteDir(tempDir));

    final file = File(p.join(tempDir.path, 'sample.mp4'));
    await file.writeAsBytes(_validMp4Bytes);

    final validator = CockpitBundleArtifactValidator(
      processRunner: (executable, arguments) async {
        fail('ordinary recording validation must not run $executable');
      },
    );

    final result = await validator.validateRecording(file.path);

    expect(result.isValid, isTrue);
    expect(result.validator, 'builtinMp4');
    expect(result.details['majorBrand'], 'isom');
  });

  test(
    'strict acceptance video validation delegates to the video inspector',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_mp4_fallback',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final file = File(p.join(tempDir.path, 'sample.mp4'));
      await file.writeAsBytes(_validMp4Bytes);

      final validator = CockpitBundleArtifactValidator(
        videoArtifactInspector: CockpitVideoArtifactInspector(
          processRunner: (executable, arguments, {required timeout}) async {
            if (executable == 'ffprobe') {
              return ProcessResult(51, 0, _strictVideoProbeJson, '');
            }
            return ProcessResult(52, 0, '', '');
          },
        ),
      );

      final result = await validator.validateAcceptanceVideo(file.path);

      expect(result.isValid, isTrue);
      expect(result.validator, 'ffprobe+ffmpeg');
      expect(result.details['codecName'], 'h264');
      expect(result.details['durationSeconds'], 2.5);
    },
  );

  test('strict validation forwards configured executable paths', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_executables',
    );
    addTearDown(() async => _deleteDir(tempDir));
    final recordingFile = File(p.join(tempDir.path, 'sample.mp4'));
    await recordingFile.writeAsBytes(_validMp4Bytes);
    final ffprobePath = await _writeVideoProbeExecutable(tempDir);
    final ffmpegPath = p.join(
      tempDir.path,
      Platform.isWindows ? 'missing-ffmpeg.exe' : 'missing-ffmpeg',
    );
    final validator = CockpitBundleArtifactValidator(
      ffprobeExecutable: ffprobePath,
      ffmpegExecutable: ffmpegPath,
    );

    final result = await validator.validateAcceptanceVideo(recordingFile.path);

    expect(result.isValid, isFalse);
    expect(result.code, 'videoValidatorUnavailable');
    expect(result.details['executable'], ffmpegPath);
  });

  test('strict acceptance video preserves invalid-media failures', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_strict_invalid',
    );
    addTearDown(() async => _deleteDir(tempDir));

    final file = File(p.join(tempDir.path, 'sample.mp4'));
    await file.writeAsBytes(_validMp4Bytes);
    final validator = CockpitBundleArtifactValidator(
      videoArtifactInspector: CockpitVideoArtifactInspector(
        processRunner: (executable, arguments, {required timeout}) async {
          if (executable == 'ffprobe') {
            return ProcessResult(53, 0, _strictVideoProbeJson, '');
          }
          return ProcessResult(
            54,
            1,
            '',
            'Invalid data found when processing input',
          );
        },
      ),
    );

    final result = await validator.validateAcceptanceVideo(file.path);

    expect(result.isValid, isFalse);
    expect(result.code, 'videoDecodeFailed');
    expect(result.validator, 'ffprobe+ffmpeg');
    expect(result.details['failureKind'], 'invalidMedia');
  });

  test('rejects invalid recording artifacts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_bundle_artifact_validator_mp4_invalid',
    );
    addTearDown(() async => _deleteDir(tempDir));

    final file = File(p.join(tempDir.path, 'sample.mp4'));
    await file.writeAsBytes(const <int>[1, 2, 3, 4]);

    final validator = CockpitBundleArtifactValidator(
      processRunner: (executable, arguments) async {
        fail('ordinary recording validation must not run $executable');
      },
    );

    final result = await validator.validateRecording(file.path);

    expect(result.isValid, isFalse);
    expect(result.code, 'invalidRecordingArtifact');
  });

  test(
    'validates delivery consistency when the extracted frame matches the screenshot',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_valid',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      await screenshotFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );
      await recordingFile.writeAsBytes(_validMp4Bytes);

      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildCanvasImage(0xFF184E46)));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
      );

      expect(result.isValid, isTrue);
      expect(result.validator, 'deliveryConsistency');
      expect(result.details['bestSimilarity'], greaterThan(0.9));
    },
  );

  test(
    'rejects delivery consistency when the extracted frame differs from the screenshot',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_invalid',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      await screenshotFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );
      await recordingFile.writeAsBytes(_validMp4Bytes);

      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildContrastImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
      );

      expect(result.isValid, isFalse);
      expect(result.code, 'inconsistentDeliveryEvidence');
    },
  );

  test(
    'falls back to deeper late-frame offsets when near-end ffmpeg seeks return no output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_fallback',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      await screenshotFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );
      await recordingFile.writeAsBytes(_validMp4Bytes);

      final ffmpegCalls = <List<String>>[];
      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final seekValue = arguments[arguments.indexOf('-sseof') + 1];
            if (seekValue == '-1.8') {
              await File(outputPath).parent.create(recursive: true);
              await File(
                outputPath,
              ).writeAsBytes(_encodedPng(_buildCanvasImage(0xFF184E46)));
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

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
      );

      expect(result.isValid, isTrue);
      expect(result.validator, 'deliveryConsistency');
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.contains('-sseof') &&
              arguments[arguments.indexOf('-sseof') + 1] == '-1.8',
        ),
        isTrue,
      );
    },
  );

  test(
    'uses bundle keyframes before ffmpeg late-frame extraction for delivery consistency',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_keyframe',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      final keyframeFile = File(
        p.join(tempDir.path, 'acceptance_keyframe.png'),
      );
      await screenshotFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );
      await recordingFile.writeAsBytes(_validMp4Bytes);
      await keyframeFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );

      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffmpeg') {
            final outputPath = arguments.last;
            await File(outputPath).parent.create(recursive: true);
            await File(
              outputPath,
            ).writeAsBytes(_encodedPng(_buildContrastImage()));
            return ProcessResult(0, 0, '', '');
          }
          throw ProcessException(
            executable,
            arguments,
            'unexpected executable',
          );
        },
      );

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
        candidateFramePaths: <String>[keyframeFile.path],
      );

      expect(result.isValid, isTrue);
      expect(result.validator, 'deliveryConsistency');
      expect(result.details['bestSource'], 'bundleKeyframe');
      expect(result.details['bestSimilarity'], greaterThan(0.9));
    },
  );

  test(
    'rejects short recordings when only an early frame matches the screenshot',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_short_recording',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      await screenshotFile.writeAsBytes(
        _encodedPng(_buildCanvasImage(0xFF184E46)),
      );
      await recordingFile.writeAsBytes(_validMp4Bytes);

      final ffmpegCalls = <List<String>>[];
      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
              0,
              0,
              '{"streams":[{"codec_name":"h264","codec_type":"video","width":240,"height":480}],"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.561667"}}',
              '',
            );
          }
          if (executable == 'ffmpeg') {
            ffmpegCalls.add(List<String>.from(arguments));
            final outputPath = arguments.last;
            final seekValue = arguments[arguments.indexOf('-sseof') + 1];
            await File(outputPath).parent.create(recursive: true);
            await File(outputPath).writeAsBytes(
              _encodedPng(
                seekValue == '-2.2'
                    ? _buildCanvasImage(0xFF184E46)
                    : _buildContrastImage(),
              ),
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

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
      );

      expect(result.isValid, isFalse);
      expect(result.code, 'inconsistentDeliveryEvidence');
      expect(
        ffmpegCalls.any(
          (arguments) =>
              arguments.contains('-sseof') &&
              arguments[arguments.indexOf('-sseof') + 1] == '-2.2',
        ),
        isFalse,
      );
    },
  );

  test(
    'keeps delivery consistency similarity bounded for high-range image formats',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_bundle_artifact_validator_consistency_bounded',
      );
      addTearDown(() async => _deleteDir(tempDir));

      final screenshotFile = File(p.join(tempDir.path, 'acceptance.png'));
      final recordingFile = File(p.join(tempDir.path, 'acceptance.mp4'));
      final keyframeFile = File(
        p.join(tempDir.path, 'acceptance_keyframe.png'),
      );
      await screenshotFile.writeAsBytes(_encodeHighRangePng(65535, 8192, 2048));
      await recordingFile.writeAsBytes(_validMp4Bytes);
      await keyframeFile.writeAsBytes(_encodeHighRangePng(65535, 8192, 2048));

      final validator = CockpitBundleArtifactValidator(
        processRunner: (executable, arguments) {
          throw ProcessException(executable, arguments, 'ffmpeg unavailable');
        },
      );

      final result = await validator.validateDeliveryConsistency(
        screenshotPath: screenshotFile.path,
        recordingPath: recordingFile.path,
        candidateFramePaths: <String>[keyframeFile.path],
      );

      expect(result.isValid, isTrue);
      expect(result.details['bestSimilarity'], inInclusiveRange(0.0, 1.0));
    },
  );
}

Future<void> _deleteDir(Directory dir) async {
  if (dir.existsSync()) {
    await dir.delete(recursive: true);
  }
}

Future<String> _writeVideoProbeExecutable(Directory directory) async {
  final file = File(
    p.join(directory.path, Platform.isWindows ? 'ffprobe.cmd' : 'ffprobe'),
  );
  if (Platform.isWindows) {
    await file.writeAsString('@echo off\r\necho $_strictVideoProbeJson\r\n');
  } else {
    await file.writeAsString(
      "#!/bin/sh\nprintf '%s\\n' '$_strictVideoProbeJson'\n",
    );
    final chmod = await Process.run('chmod', <String>['+x', file.path]);
    expect(chmod.exitCode, 0, reason: '${chmod.stderr}');
  }
  return file.path;
}

final List<int> _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAABAAAAAQBPJcTWAAAADklEQVR4nGNkAAMWCAUAADgABkRoBWYAAAAASUVORK5CYII=',
);

final List<int> _validMp4Bytes = base64Decode(
  'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAuVtZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAD2WIhAAz//727L4FNhTIwQAAAAhBmiJsQr/+wAAAAAgBnkF5Cv/EgQAAA1xtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAAPoAAAAeAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACh3RyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAAeAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAEAAAABAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAAHgAAAQAAAEAAAAAAf9tZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAADIAAAAIAFXEAAAAAAAtaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlcgAAAAGqbWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAABanN0YmwAAAC+c3RzZAAAAAAAAAABAAAArmF2YzEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAEAAQAEgAAABIAAAAAAAAAAEVTGF2YzYyLjExLjEwMCBsaWJ4MjY0AAAAAAAAAAAAAAAY//8AAAA0YXZjQwFkAAr/4QAXZ2QACqzZXsBEAAADAAQAAAMAyDxIllgBAAZo6+PLIsD9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAvuIAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAMAAAIAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAAAoY3R0cwAAAAAAAAADAAAAAQAABAAAAAABAAAGAAAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAADAAAAAQAAACBzdHN6AAAAAAAAAAAAAAADAAACxQAAAAwAAAAMAAAAFHN0Y28AAAAAAAAAAQAAADAAAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYyLjMuMTAw',
);

const String _strictVideoProbeJson =
    '{"streams":[{"index":0,"codec_name":"h264","codec_long_name":"H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10","codec_type":"video","width":16,"height":16,"pix_fmt":"yuv420p","r_frame_rate":"30/1"}],"format":{"filename":"sample.mp4","nb_streams":1,"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"2.500000","size":"2048","bit_rate":"6553"}}';

List<int> _encodedPng(img.Image image) => img.encodePng(image);

List<int> _encodeHighRangePng(int r, int g, int b) {
  final image = img.Image(width: 240, height: 480, format: img.Format.uint16);
  img.fill(image, color: img.ColorUint16.rgb(r, g, b));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 78,
    color: img.ColorUint16.rgb(r, g, b),
  );
  return img.encodePng(image);
}

img.Image _buildCanvasImage(int accentColor) {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(246, 240, 231, 255));
  img.fillRect(
    image,
    x1: 18,
    y1: 28,
    x2: 220,
    y2: 78,
    color: img.ColorUint8.rgba(
      (accentColor >> 16) & 0xFF,
      (accentColor >> 8) & 0xFF,
      accentColor & 0xFF,
      (accentColor >> 24) & 0xFF,
    ),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 120,
    x2: 220,
    y2: 126,
    color: img.ColorUint8.rgba(0xD8, 0xCF, 0xC0, 0xFF),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 180,
    x2: 220,
    y2: 280,
    color: img.ColorUint8.rgba(0xF5, 0xF0, 0xE6, 0xFF),
  );
  img.fillRect(
    image,
    x1: 18,
    y1: 318,
    x2: 220,
    y2: 328,
    color: img.ColorUint8.rgba(0x18, 0x4E, 0x46, 0xFF),
  );
  return image;
}

img.Image _buildContrastImage() {
  final image = img.Image(width: 240, height: 480);
  img.fill(image, color: img.ColorRgba8(24, 24, 24, 255));
  img.fillRect(
    image,
    x1: 24,
    y1: 34,
    x2: 216,
    y2: 220,
    color: img.ColorRgba8(122, 45, 18, 255),
  );
  img.fillRect(
    image,
    x1: 24,
    y1: 260,
    x2: 216,
    y2: 430,
    color: img.ColorRgba8(245, 245, 245, 255),
  );
  img.fillRect(
    image,
    x1: 102,
    y1: 70,
    x2: 138,
    y2: 420,
    color: img.ColorRgba8(232, 180, 72, 255),
  );
  return image;
}
