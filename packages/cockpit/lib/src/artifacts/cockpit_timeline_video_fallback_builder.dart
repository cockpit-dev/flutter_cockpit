// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

typedef CockpitTimelineVideoProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class CockpitTimelineVideoFallbackResult {
  const CockpitTimelineVideoFallbackResult({
    required this.artifact,
    required this.sourceFilePath,
    required this.durationMs,
    required this.screenshotRefs,
    this.cleanupDirectoryPath,
  });

  final CockpitArtifactRef artifact;
  final String sourceFilePath;
  final int durationMs;
  final List<String> screenshotRefs;
  final String? cleanupDirectoryPath;
}

abstract interface class CockpitTimelineVideoFallbackBuilder {
  Future<CockpitTimelineVideoFallbackResult?> build({
    required CockpitContextBundle bundle,
    required String outputDirectoryPath,
  });
}

final class DefaultCockpitTimelineVideoFallbackBuilder
    implements CockpitTimelineVideoFallbackBuilder {
  const DefaultCockpitTimelineVideoFallbackBuilder({
    String ffmpegExecutable = 'ffmpeg',
    CockpitTimelineVideoProcessRunner processRunner = Process.run,
  }) : _ffmpegExecutable = ffmpegExecutable,
       _processRunner = processRunner;

  final String _ffmpegExecutable;
  final CockpitTimelineVideoProcessRunner _processRunner;

  @override
  Future<CockpitTimelineVideoFallbackResult?> build({
    required CockpitContextBundle bundle,
    required String outputDirectoryPath,
  }) async {
    if (!_recordingWasRequested(bundle.steps)) {
      return null;
    }

    final screenshotFrames = _screenshotFramesFor(bundle);
    if (screenshotFrames.isEmpty) {
      return null;
    }

    final workingDirectory = await Directory.systemTemp.createTemp(
      'flutter_cockpit_timeline_video_',
    );
    final framesDirectory = Directory(p.join(workingDirectory.path, 'frames'))
      ..createSync(recursive: true);
    final outputFile = File(
      p.join(workingDirectory.path, '${_sanitizedBaseName(bundle)}.mp4'),
    );

    var frameIndex = 0;
    for (final screenshotFrame in screenshotFrames) {
      final screenshotFile = File(
        p.join(outputDirectoryPath, screenshotFrame.relativePath),
      );
      if (!screenshotFile.existsSync()) {
        continue;
      }
      final frameCopies = _frameCopiesForDuration(screenshotFrame.durationMs);
      for (var copyIndex = 0; copyIndex < frameCopies; copyIndex += 1) {
        final framePath = p.join(
          framesDirectory.path,
          'frame_${frameIndex.toString().padLeft(4, '0')}.png',
        );
        screenshotFile.copySync(framePath);
        frameIndex += 1;
      }
    }

    if (frameIndex == 0) {
      await workingDirectory.delete(recursive: true);
      return null;
    }

    final result = await _processRunner(_ffmpegExecutable, <String>[
      '-y',
      '-framerate',
      '${_framesPerSecond()}',
      '-i',
      p.join(framesDirectory.path, 'frame_%04d.png'),
      '-vf',
      'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p',
      '-c:v',
      'libx264',
      '-movflags',
      '+faststart',
      outputFile.path,
    ]);

    if (result.exitCode != 0 || !outputFile.existsSync()) {
      await workingDirectory.delete(recursive: true);
      return null;
    }

    final durationMs = screenshotFrames.fold<int>(
      0,
      (total, frame) => total + frame.durationMs,
    );
    return CockpitTimelineVideoFallbackResult(
      artifact: CockpitArtifactRef(
        role: 'timeline_preview',
        relativePath:
            'recordings/${_sanitizedBaseName(bundle)}_timeline_fallback.mp4',
      ),
      sourceFilePath: outputFile.path,
      durationMs: durationMs,
      screenshotRefs: screenshotFrames
          .map((frame) => frame.relativePath)
          .toList(growable: false),
      cleanupDirectoryPath: workingDirectory.path,
    );
  }

  bool _recordingWasRequested(List<CockpitStepRecord> steps) {
    return steps.any(
      (step) =>
          step.actionType == 'recording_start_requested' ||
          step.actionType == 'recording_started' ||
          step.actionType == 'recording_failed' ||
          step.actionType == 'recording_stopped',
    );
  }

  List<_CockpitScreenshotTimelineFrame> _screenshotFramesFor(
    CockpitContextBundle bundle,
  ) {
    final screenshotSteps =
        bundle.steps
            .where(
              (step) => step.captureRefs.any(
                (artifact) => artifact.role == 'screenshot',
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.observedAt.compareTo(right.observedAt));
    if (screenshotSteps.isEmpty) {
      return const <_CockpitScreenshotTimelineFrame>[];
    }

    final frames = <_CockpitScreenshotTimelineFrame>[];
    for (var index = 0; index < screenshotSteps.length; index += 1) {
      final step = screenshotSteps[index];
      String? screenshotRef;
      for (final artifact in step.captureRefs) {
        if (artifact.role == 'screenshot') {
          screenshotRef = artifact.relativePath;
          break;
        }
      }
      if (screenshotRef == null) {
        continue;
      }

      final nextObservedAt = index + 1 < screenshotSteps.length
          ? screenshotSteps[index + 1].observedAt
          : null;
      final durationMs = _durationForFrame(
        current: step.observedAt,
        next: nextObservedAt,
        isAcceptance:
            step.requestedCaptureProfile == CockpitCaptureProfile.acceptance ||
            step.requestedCaptureProfile ==
                CockpitCaptureProfile.nativePreferred,
      );
      frames.add(
        _CockpitScreenshotTimelineFrame(
          relativePath: screenshotRef,
          durationMs: durationMs,
        ),
      );
    }
    return frames;
  }

  int _durationForFrame({
    required DateTime current,
    required DateTime? next,
    required bool isAcceptance,
  }) {
    if (next == null) {
      return isAcceptance ? 1800 : 1200;
    }
    final delta = next.difference(current).inMilliseconds;
    return delta.clamp(800, 4000);
  }

  int _frameCopiesForDuration(int durationMs) {
    final copies = (durationMs / 1000 * _framesPerSecond()).round();
    return copies < 1 ? 1 : copies;
  }

  int _framesPerSecond() => 8;

  String _sanitizedBaseName(CockpitContextBundle bundle) {
    final raw = '${bundle.manifest.taskId}_${bundle.manifest.sessionId}';
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return sanitized.isEmpty ? 'timelineVideo' : sanitized;
  }
}

final class _CockpitScreenshotTimelineFrame {
  const _CockpitScreenshotTimelineFrame({
    required this.relativePath,
    required this.durationMs,
  });

  final String relativePath;
  final int durationMs;
}
