import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_macos_recording_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('macos recording adapter starts and finalizes a host recording artifact',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_macos_recording_adapter',
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
if printf '%s' "$*" | grep -q -- '-list_devices true'; then
  printf '[1] Capture screen 0\n' >&2
  exit 0
fi
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
printf 'Press [q] to stop\n' >&2
trap 'printf "macos-video" > "$output_path"; exit 0' INT
while true; do
  sleep 1
done
''',
    );

    final osascriptExecutable = await _writeExecutable(
      directory: tempDir,
      name: 'osascript',
      body: r'''
#!/bin/sh
exit 0
''',
    );

    final adapter = CockpitMacosRecordingAdapter(
      appId: 'dev.cockpit.cockpitDemo',
      ffmpegExecutable: ffmpegExecutable.path,
      osascriptExecutable: osascriptExecutable.path,
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
        name: 'host-macos-demo',
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
        relativePath: 'recordings/host-macos-demo.mp4',
      ),
    );
    expect(File(result.sourceFilePath!).readAsStringSync(), 'macos-video');
    expect(
      File(p.join(tempDir.path, 'ffmpeg.log')).readAsStringSync(),
      contains('-f avfoundation'),
    );
  });

  test(
    'macos recording adapter tolerates quiet startup when ffmpeg keeps running',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_recording_adapter_quiet',
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
if printf '%s' "$*" | grep -q -- '-list_devices true'; then
  printf '[1] Capture screen 0\n' >&2
  exit 0
fi
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
trap 'printf "quiet-macos-video" > "$output_path"; exit 0' INT
sleep 0.1
printf "startup-evidence" > "$output_path"
while true; do
  sleep 1
done
''',
      );

      final osascriptExecutable = await _writeExecutable(
        directory: tempDir,
        name: 'osascript',
        body: r'''
#!/bin/sh
exit 0
''',
      );

      final adapter = CockpitMacosRecordingAdapter(
        appId: 'dev.cockpit.cockpitDemo',
        ffmpegExecutable: ffmpegExecutable.path,
        osascriptExecutable: osascriptExecutable.path,
        startupTimeout: const Duration(milliseconds: 200),
        startupEvidenceTimeout: const Duration(seconds: 1),
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
          name: 'quiet-startup-demo',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(session.state, CockpitRecordingState.recording);
      expect(result.state, CockpitRecordingState.completed);
      expect(
          File(result.sourceFilePath!).readAsStringSync(), 'quiet-macos-video');
    },
  );

  test(
    'macos recording adapter fails fast when ffmpeg never confirms startup or produces output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_recording_adapter_startup_failure',
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
if printf '%s' "$*" | grep -q -- '-list_devices true'; then
  printf '[1] Capture screen 0\n' >&2
  exit 0
fi
while true; do
  sleep 1
done
''',
      );

      final osascriptExecutable = await _writeExecutable(
        directory: tempDir,
        name: 'osascript',
        body: r'''
#!/bin/sh
exit 0
''',
      );

      final adapter = CockpitMacosRecordingAdapter(
        appId: 'dev.cockpit.cockpitDemo',
        ffmpegExecutable: ffmpegExecutable.path,
        osascriptExecutable: osascriptExecutable.path,
        startupTimeout: const Duration(milliseconds: 200),
        startupEvidenceTimeout: const Duration(milliseconds: 100),
        stopTimeout: const Duration(seconds: 2),
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      await expectLater(
        adapter.startRecording(
          const CockpitRecordingRequest(
            purpose: CockpitRecordingPurpose.acceptance,
            name: 'missing-startup-evidence',
            attachToStep: true,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Ensure Screen Recording permission is granted'),
          ),
        ),
      );
    },
  );

  test(
    'macos recording adapter can stop an active session after the adapter instance is recreated',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_recording_adapter_recreated',
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
if printf '%s' "$*" | grep -q -- '-list_devices true'; then
  printf '[1] Capture screen 0\n' >&2
  exit 0
fi
output_path=""
for arg in "$@"; do
  output_path="$arg"
done
printf 'Press [q] to stop\n' >&2
trap 'printf "recreated-macos-video" > "$output_path"; exit 0' INT
while true; do
  sleep 1
done
''',
      );

      final osascriptExecutable = await _writeExecutable(
        directory: tempDir,
        name: 'osascript',
        body: r'''
#!/bin/sh
exit 0
''',
      );

      CockpitMacosRecordingAdapter buildAdapter() {
        return CockpitMacosRecordingAdapter(
          appId: 'com.google.Chrome',
          ffmpegExecutable: ffmpegExecutable.path,
          osascriptExecutable: osascriptExecutable.path,
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
      }

      final startedAdapter = buildAdapter();
      await startedAdapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-macos-recreated',
          attachToStep: true,
        ),
      );

      final stoppedAdapter = buildAdapter();
      final result = await stoppedAdapter.stopRecording();

      expect(result.state, CockpitRecordingState.completed);
      expect(
        File(result.sourceFilePath!).readAsStringSync(),
        'recreated-macos-video',
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
