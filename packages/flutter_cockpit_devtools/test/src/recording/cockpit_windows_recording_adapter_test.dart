import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_windows_recording_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'windows recording adapter starts and finalizes a host recording artifact',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_windows_recording_adapter',
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
printf 'Press [q] to stop\n' >&2
while IFS= read -r line; do
  if [ "$line" = "q" ]; then
    printf "windows-video" > "$output_path"
    exit 0
  fi
done
''',
      );

      final adapter = CockpitWindowsRecordingAdapter(
        appId: 'cockpit_demo',
        ffmpegExecutable: ffmpegExecutable.path,
        powershellExecutable: ffmpegExecutable.path,
        startupTimeout: const Duration(seconds: 2),
        stopTimeout: const Duration(seconds: 2),
        finalizationPollInterval: const Duration(milliseconds: 10),
        ffprobeProcessRunner: (executable, arguments) async => ProcessResult(
          0,
          0,
          '{"format":{"duration":"2.000"},"streams":[{"codec_type":"video","nb_frames":"40"}]}',
          '',
        ),
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-windows-demo',
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
          relativePath: 'recordings/host-windows-demo.mp4',
        ),
      );
      expect(File(result.sourceFilePath!).readAsStringSync(), 'windows-video');
      expect(
        File(p.join(tempDir.path, 'ffmpeg.log')).readAsStringSync(),
        contains('-f gdigrab'),
      );
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
