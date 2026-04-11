import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;
  final workflowFile = File('$root/.github/workflows/runtime-loop.yml');

  test('runtime loop workflow uses full verifier coverage on every platform',
      () {
    final workflow = workflowFile.readAsStringSync();

    expect(workflow, contains('macos-mcp-surface:'));
    expect(workflow, contains('run: melos run test'));
    expect(workflow, contains('android-runtime-loop:'));
    expect(workflow, contains('ios-runtime-loop:'));
    expect(workflow, contains('macos-runtime-loop:'));
    expect(workflow, contains('linux-runtime-loop:'));
    expect(workflow, contains('windows-runtime-loop:'));

    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform android'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform ios'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform macos'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform linux'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform windows'),
    );
    expect(workflow, contains('dart run tool/verify_mcp_surface.dart'));
    expect(workflow, contains(r'STATUS=${PIPESTATUS[0]}'));
    expect(workflow, contains('xvfb-run -a dart run'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
  });
}
