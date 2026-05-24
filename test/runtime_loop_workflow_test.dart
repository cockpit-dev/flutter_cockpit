import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;
  final workflowFile = File('$root/.github/workflows/runtime-loop.yml');
  final melosConfigFile = File('$root/melos.yaml');
  final demoReadmeFile = File('$root/examples/cockpit_demo/README.md');
  final platformVerifierFile = File(
    '$root/examples/cockpit_demo/tool/verify_platforms.dart',
  );
  final rapidDevVerifierFile = File(
    '$root/examples/cockpit_demo/tool/verify_rapid_dev.dart',
  );

  test('runtime loop workflow uses full verifier coverage on every platform', () {
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
    expect(workflow, contains('(cd packages/flutter_cockpit && flutter test)'));
    expect(
      workflow,
      contains('(cd packages/flutter_cockpit_devtools && dart test)'),
    );
    expect(workflow, contains('(cd examples/cockpit_demo && flutter test)'));
    expect(workflow, isNot(contains('run: melos run test')));
    expect(workflow, isNot(contains('run: dart run melos test')));
    expect(workflow, contains('android-runtime-loop:'));
    expect(workflow, contains('ios-runtime-loop:'));
    expect(workflow, contains('macos-runtime-loop:'));
    expect(workflow, contains('web-runtime-loop:'));
    expect(workflow, contains('linux-runtime-loop:'));
    expect(workflow, contains('windows-runtime-loop:'));

    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform android'),
    );
    expect(workflow, contains(r'--launch-timeout-seconds 600 >"$LOG_PATH"'));
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
      contains('dart run tool/verify_platforms.dart --platform web'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform linux'),
    );
    expect(
      workflow,
      contains('dart run tool/verify_platforms.dart --platform windows'),
    );
    expect(
      workflow,
      contains(r'--launch-timeout-seconds 600 2>&1 | tee "$LOG_PATH_POSIX"'),
    );
    expect(workflow, isNot(contains('--launch-timeout-seconds 300')));
    expect(workflow, contains('dart run tool/verify_mcp_surface.dart'));
    expect(workflow, contains(r'STATUS=${PIPESTATUS[0]}'));
    expect(workflow, contains('xvfb-run -a dart run'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('"sync_lab_conflict_recovery"'));
    expect(workflow, contains('assert platform["batchCommandCount"] == 30'));
    expect(workflow, contains('assert platform["autoScreenshotCount"] >= 20'));
    expect(workflow, contains('assert platform["recordingOutputPath"]'));
    expect(workflow, contains('assert platform["screenshotByteLength"] > 0'));
    expect(workflow, isNot(contains('platform["batchCommandCount"] == 4')));
  });

  test('runtime loop bootstrap is self-contained on clean runners', () {
    final workflow = workflowFile.readAsStringSync();
    final demoReadme = demoReadmeFile.readAsStringSync();

    expect(melosConfigFile.existsSync(), isTrue);
    expect(workflow, contains('flutter pub get'));
    expect(workflow, isNot(contains('dart run melos bootstrap')));
    expect(workflow, isNot(contains('run: melos bootstrap')));
    expect(demoReadme, contains('flutter pub get'));
    expect(demoReadme, isNot(contains('dart run melos bootstrap')));
  });

  test('web runtime loop installs X11 utilities required by host recording', () {
    final workflow = workflowFile.readAsStringSync();

    final webDependenciesStep = RegExp(
      r'Install web validation dependencies[\s\S]*?sudo apt-get install -y ([^\n]+)',
    ).firstMatch(workflow);

    expect(webDependenciesStep, isNotNull);
    expect(webDependenciesStep!.group(1), contains('ffmpeg'));
    expect(webDependenciesStep.group(1), contains('x11-utils'));
    expect(webDependenciesStep.group(1), contains('xvfb'));
  });

  test('runtime loop verifier scripts accept the CI output protocol', () {
    final workflow = workflowFile.readAsStringSync();
    final platformVerifier = platformVerifierFile.readAsStringSync();
    final rapidDevVerifier = rapidDevVerifierFile.readAsStringSync();

    expect(workflow, contains(r'--output "$RESULT_JSON"'));
    expect(workflow, contains(r'--output "$RESULT_JSON_POSIX"'));
    expect(workflow, contains('--output-format json'));
    expect(workflow, isNot(contains('--output-json')));

    for (final verifier in <String>[platformVerifier, rapidDevVerifier]) {
      expect(verifier, contains("'output'"));
      expect(verifier, contains("'output-format'"));
      expect(verifier, contains("allowed: const <String>['json']"));
      expect(verifier, contains("defaultsTo: 'json'"));
      expect(verifier, isNot(contains("'output-json'")));
    }
  });
}
