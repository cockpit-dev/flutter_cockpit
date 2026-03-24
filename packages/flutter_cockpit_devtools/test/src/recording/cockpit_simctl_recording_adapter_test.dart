import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'simctl adapter starts and finalizes a host recording artifact',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_adapter',
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
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
log_file="$script_dir/simctl.log"
printf '%s\n' "$*" >> "$log_file"
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
        deviceId: 'simulator-123',
        executable: executable.path,
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-demo',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(session.state, CockpitRecordingState.recording);
      expect(result.state, CockpitRecordingState.completed);
      expect(
        result.artifact,
        const CockpitArtifactRef(
          role: 'recording',
          relativePath: 'recordings/host-simctl-demo.mp4',
        ),
      );
      expect(result.sourceFilePath, isNotNull);
      expect(File(result.sourceFilePath!).readAsStringSync(), 'simctl-video');
      expect(
        File(p.join(tempDir.path, 'simctl.log')).readAsStringSync(),
        contains('simctl io simulator-123 recordVideo --force'),
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
    'simctl adapter waits for ffprobe duration to finalize before succeeding',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_finalize',
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

      var ffprobeCallCount = 0;
      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: 'simulator-789',
        executable: executable.path,
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            ffprobeCallCount += 1;
            final duration = switch (ffprobeCallCount) {
              1 => '0.200',
              2 => '0.500',
              _ => '1.200',
            };
            return ProcessResult(
              0,
              0,
              '{"format":{"duration":"$duration"}}',
              '',
            );
          }
          throw ProcessException(executable, arguments, 'unexpected command');
        },
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-finalize',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(result.state, CockpitRecordingState.completed);
      expect(ffprobeCallCount, greaterThanOrEqualTo(3));
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
