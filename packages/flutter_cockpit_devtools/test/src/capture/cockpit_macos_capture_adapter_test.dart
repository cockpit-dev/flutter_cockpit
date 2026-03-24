import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_macos_capture_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('macos capture adapter activates the app and writes a screenshot',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_macos_capture_adapter',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final executable = await _writeExecutable(
      directory: tempDir,
      name: 'macos-capture-tool',
      body: r'''
#!/bin/sh
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
log_file="$script_dir/macos-capture.log"
printf '%s\n' "$*" >> "$log_file"
if [ "$1" = "-e" ]; then
  exit 0
fi
last_arg=""
for arg in "$@"; do
  last_arg="$arg"
done
printf 'png-data' > "$last_arg"
''',
    );

    final adapter = CockpitMacosCaptureAdapter(
      appId: 'dev.cockpit.cockpitDemo',
      osascriptExecutable: executable.path,
      screencaptureExecutable: executable.path,
      activationSettleDelay: Duration.zero,
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture-1',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'macos-acceptance',
          attachToStep: true,
        ),
      ),
    );

    expect(execution.result.success, isTrue);
    expect(
      execution.result.artifacts.single.relativePath,
      contains('screenshots/macos_acceptance_acceptance_'),
    );
    expect(execution.artifactSourcePaths, isNotEmpty);
    final sourcePath = execution.artifactSourcePaths.values.single;
    expect(File(sourcePath).readAsStringSync(), 'png-data');
    final log =
        File(p.join(tempDir.path, 'macos-capture.log')).readAsStringSync();
    expect(log,
        contains('tell application id "dev.cockpit.cockpitDemo" to activate'));
    expect(log, contains('-x'));
  });
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
