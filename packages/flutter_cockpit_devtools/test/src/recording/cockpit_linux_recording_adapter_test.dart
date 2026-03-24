import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_linux_recording_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'linux recording adapter starts and finalizes a host recording artifact',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_recording_adapter',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final ffmpegExecutable = await _writeExecutable(
        directory: tempDir,
        name: 'ffmpeg',
        body: r'''
#!/bin/sh
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
log_file="$script_dir/ffmpeg.log"
printf '%s\n' "$*" >> "$log_file"
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
printf 'Output #0\n' >&2
while IFS= read -r line; do
  if [ "$line" = "q" ]; then
    printf "linux-video" > "$output_path"
    exit 0
  fi
done
''',
      );

      final adapter = CockpitLinuxRecordingAdapter(
        appId: 'cockpit_demo',
        ffmpegExecutable: ffmpegExecutable.path,
        windowActivatorExecutable: ffmpegExecutable.path,
        displayConfigResolver: () async => const CockpitLinuxDisplayConfig(
          display: ':99',
          captureSize: '1440x900',
        ),
        startupTimeout: const Duration(seconds: 2),
        stopTimeout: const Duration(seconds: 2),
        finalizationPollInterval: const Duration(milliseconds: 10),
        ffprobeProcessRunner: (executable, arguments) async => ProcessResult(
          0,
          0,
          '{"format":{"duration":"1.500"},"streams":[{"codec_type":"video","nb_frames":"30"}]}',
          '',
        ),
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-linux-demo',
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
          relativePath: 'recordings/host-linux-demo.mp4',
        ),
      );
      expect(File(result.sourceFilePath!).readAsStringSync(), 'linux-video');
      final log = File(p.join(tempDir.path, 'ffmpeg.log')).readAsStringSync();
      expect(log, contains('-f x11grab'));
      expect(log, contains('-video_size 1440x900'));
      expect(log, contains('-i :99+0,0'));
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
