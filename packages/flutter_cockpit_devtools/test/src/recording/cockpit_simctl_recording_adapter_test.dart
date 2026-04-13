import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'simctl adapter accepts a running recorder even when no startup banner is emitted',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_no_banner',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final executable = await _writeExecutable(
        directory: tempDir,
        name: 'xcrun',
        body: r'''
#!/bin/sh
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
trap 'printf "simctl-video-no-banner" > "$output_path"; exit 0' INT
while true; do
  sleep 1
done
''',
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: 'simulator-no-banner',
        executable: executable.path,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        startupTimeout: const Duration(seconds: 1),
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-no-banner',
          attachToStep: true,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      final result = await adapter.stopRecording();

      expect(session.state, CockpitRecordingState.recording);
      expect(result.state, CockpitRecordingState.completed);
      expect(
        File(result.sourceFilePath!).readAsStringSync(),
        'simctl-video-no-banner',
      );
    },
  );

  test(
    'simctl adapter fails when the recording output file is missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_missing_output',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final executable = await _writeExecutable(
        directory: tempDir,
        name: 'xcrun',
        body: r'''
#!/bin/sh
printf 'Recording started\n' >&2
trap 'exit 0' INT
while true; do
  sleep 1
done
''',
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: 'simulator-456',
        executable: executable.path,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
      );

      await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-missing',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(result.state, CockpitRecordingState.failed);
      expect(result.failureReason, contains('output'));
    },
  );

  test(
    'simctl adapter accepts sparse simulator recordings when ffprobe reports a usable timeline',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_sparse_timeline',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final executable = await _writeExecutable(
        directory: tempDir,
        name: 'xcrun',
        body: r'''
#!/bin/sh
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
printf 'Recording started\n' >&2
trap 'printf "simctl-video" > "$output_path"; exit 0' INT
while true; do
  sleep 1
done
''',
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: 'simulator-321',
        executable: executable.path,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
                0,
                0,
                '''
{"format":{"duration":"2.706"},"streams":[{"codec_type":"video","nb_frames":"44"}]}
''',
                '');
          }
          throw ProcessException(executable, arguments, 'unexpected command');
        },
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-sparse',
          attachToStep: true,
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      final result = await adapter.stopRecording();

      expect(result.state, CockpitRecordingState.completed);
    },
  );
}

Future<File> _writeExecutable({
  required Directory directory,
  required String name,
  required String body,
}) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(body);
  await Process.run('chmod', <String>['+x', file.path]);
  return file;
}
