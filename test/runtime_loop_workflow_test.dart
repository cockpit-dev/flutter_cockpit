import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;
  final workflowFile = File('$root/.github/workflows/runtime-loop.yml');

  test('runtime loop workflow uses full verifier coverage on every platform',
      () {
    final workflow = workflowFile.readAsStringSync();

    expect(workflow, contains('macos-mcp-surface:'));
    expect(workflow, contains('Run publish readiness gates'));
    expect(
      workflow,
      contains('dart format --output=none --set-exit-if-changed'),
    );
    expect(
      workflow,
      contains(
        'dart analyze packages/flutter_cockpit packages/flutter_cockpit_devtools examples/cockpit_demo test',
      ),
    );
    expect(workflow, contains('flutter pub publish --dry-run'));
    expect(workflow, contains('dart pub publish --dry-run'));
    expect(workflow, contains('dart test test'));
    expect(
      workflow,
      contains('(cd packages/flutter_cockpit && flutter test)'),
    );
    expect(
      workflow,
      contains('(cd packages/flutter_cockpit_devtools && dart test)'),
    );
    expect(
      workflow,
      contains('(cd examples/cockpit_demo && flutter test)'),
    );
    expect(workflow, isNot(contains('run: melos run test')));
    expect(workflow, isNot(contains('run: dart run melos test')));
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
