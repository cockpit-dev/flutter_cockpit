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
      contains(r'--launch-timeout-seconds 2400 2>&1 | tee "$LOG_PATH"'),
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
    expect(
      workflow,
      contains('"read_system_capabilities" in mcp_cli["toolNames"]'),
    );
    expect(workflow, contains('"run_system_action" in mcp_cli["toolNames"]'));
    expect(workflow, contains('"read_system_capabilities",'));
    expect(workflow, contains('"run_system_action_read_system_state",'));
    expect(
      workflow,
      contains(
        'app["run_system_action_read_system_state"]["action"] == "readSystemState"',
      ),
    );
    expect(
      workflow,
      contains('working-directory: packages/flutter_cockpit_devtools'),
    );
    expect(workflow, contains(r'STATUS=${PIPESTATUS[0]}'));
    expect(workflow, contains('xvfb-run -a dart run'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('subprocess.TimeoutExpired'));
    expect(workflow, contains('xcrun", "simctl", "bootstatus"'));
    expect(workflow, isNot(contains('timeout 150 xcrun')));
    expect(workflow, contains('"sync_lab_conflict_recovery"'));
    expect(workflow, contains('assert platform["batchCommandCount"] == 32'));
    expect(workflow, contains('assert platform["autoScreenshotCount"] >= 19'));
    expect(workflow, contains('assert platform["recordingOutputPath"]'));
    expect(workflow, contains('assert platform["screenshotByteLength"] > 0'));
    expect(workflow, isNot(contains('platform["batchCommandCount"] == 4')));
  });

  test('windows runtime loop uploads real supervisor logs on failure', () {
    final workflow = workflowFile.readAsStringSync();
    final windowsBlock = _workflowJobBlock(workflow, 'windows-runtime-loop');

    expect(windowsBlock, contains('runs-on: windows-2022'));
    expect(windowsBlock, isNot(contains('runs-on: windows-latest')));
    expect(windowsBlock, contains('SUPERVISOR_LOG_DIR='));
    expect(windowsBlock, contains('import shutil'));
    expect(windowsBlock, contains('candidate_dirs'));
    expect(windowsBlock, contains('RUNNER_TEMP'));
    expect(windowsBlock, contains('LOCALAPPDATA'));
    expect(
      windowsBlock,
      contains('flutter_cockpit_development_supervisor_*.log'),
    );
    expect(
      windowsBlock,
      contains('pathlib.Path(os.environ["RESULT_JSON_POSIX"])'),
    );
    expect(windowsBlock, contains('supervisorLogPath'));
    expect(windowsBlock, contains('shutil.copy2'));
    expect(windowsBlock, contains('candidate.exists()'));
    expect(windowsBlock, contains('supervisorLogPath not found'));
    expect(windowsBlock, contains(r'${{ env.SUPERVISOR_LOG_DIR }}'));
  });

  test('desktop runtime loops print verifier diagnostics on failure', () {
    final workflow = workflowFile.readAsStringSync();

    for (final jobName in <String>[
      'macos-runtime-loop',
      'web-runtime-loop',
      'linux-runtime-loop',
    ]) {
      final block = _workflowJobBlock(workflow, jobName);
      expect(
        block,
        contains(
          'Print ${_workflowPlatformLabel(jobName)} verifier diagnostics',
        ),
        reason: '$jobName must expose verifier diagnostics in the failed log.',
      );
      expect(block, contains(r'[ -f "$LOG_PATH" ] && cat "$LOG_PATH" || true'));
      expect(
        block,
        contains(r'[ -f "$RESULT_JSON" ] && cat "$RESULT_JSON" || true'),
      );
    }
  });

  test('runtime loop command assertions track full verifier output', () {
    final workflow = workflowFile.readAsStringSync();
    final commonExpectedCommands = <String>[
      'launch-app',
      'read-app',
      'inspect-ui',
      'read-system-capabilities',
      'run-system-action:readSystemState',
      'run-system-action:readProcessList',
      'run-batch',
      'start-recording',
      'stop-recording',
      'wait-idle',
      'sync_lab_conflict_recovery',
      'read-network',
      'read-errors',
      'read-logs',
      'inspect-surface',
      'capture-screenshot',
      'hot-reload',
      'hot-restart',
    ];
    final iosExpectedCommands = <String>[
      'launch-app',
      'read-app',
      'inspect-ui',
      'read-system-capabilities',
      'run-system-action:readSystemState',
      'run-system-action:readProcessList',
      'run-system-action:setStatusBar',
      'run-system-action:clearStatusBar',
      'run-system-action:setClipboard',
      'run-system-action:getClipboard',
      'run-batch',
      'start-recording',
      'stop-recording',
      'wait-idle',
      'sync_lab_conflict_recovery',
      'read-network',
      'read-errors',
      'read-logs',
      'inspect-surface',
      'capture-screenshot',
      'hot-reload',
      'hot-restart',
    ];
    final webExpectedCommands = <String>[
      'launch-app',
      'read-app',
      'inspect-ui',
      'read-system-capabilities',
      'run-batch',
      'start-recording',
      'stop-recording',
      'wait-idle',
      'sync_lab_conflict_recovery',
      'read-network',
      'read-errors',
      'read-logs',
      'inspect-surface',
      'capture-screenshot',
      'hot-reload',
      'hot-restart',
    ];

    for (final jobName in <String>[
      'android-runtime-loop',
      'macos-runtime-loop',
      'linux-runtime-loop',
      'windows-runtime-loop',
    ]) {
      final block = _workflowJobBlock(workflow, jobName);
      for (final command in commonExpectedCommands) {
        expect(
          block,
          contains('"$command"'),
          reason: '$jobName must assert the verifier command "$command".',
        );
      }
      expect(
        block,
        contains('assert platform["verifiedCommands"] == expected_commands'),
      );
      expect(block, contains('EXPECTED_SYSTEM_CONTROL_ADAPTER'));
      expect(block, contains('platform["systemControlAdapter"]'));
      expect(
        block,
        contains('"readSystemState" in platform["systemAvailableActions"]'),
      );
      expect(
        block,
        contains('"readProcessList" in platform["systemAvailableActions"]'),
      );
      if (jobName == 'android-runtime-loop') {
        expect(block, contains('"run-system-action:setNetworkSpeed"'));
        expect(block, contains('"run-system-action:setNetworkDelay"'));
        expect(
          block,
          contains('"setNetworkSpeed" in platform["systemAvailableActions"]'),
        );
        expect(
          block,
          contains('"setNetworkDelay" in platform["systemAvailableActions"]'),
        );
        expect(
          block,
          contains(
            'platform["systemVerifiedActions"] == ["readSystemState", "readProcessList", "setNetworkSpeed", "setNetworkDelay"]',
          ),
        );
      } else {
        expect(
          block,
          contains(
            'platform["systemVerifiedActions"] == ["readSystemState", "readProcessList"]',
          ),
        );
      }
    }

    final iosBlock = _workflowJobBlock(workflow, 'ios-runtime-loop');
    for (final command in iosExpectedCommands) {
      expect(
        iosBlock,
        contains('"$command"'),
        reason: 'ios-runtime-loop must assert the verifier command "$command".',
      );
    }
    expect(iosBlock, contains('ios.simctl+xctest'));
    expect(
      iosBlock,
      contains('"readProcessList" in platform["systemAvailableActions"]'),
    );
    expect(
      iosBlock,
      contains('"setStatusBar" in platform["systemAvailableActions"]'),
    );
    expect(
      iosBlock,
      contains('"clearStatusBar" in platform["systemAvailableActions"]'),
    );
    expect(
      iosBlock,
      contains(
        'platform["systemVerifiedActions"] == ["readSystemState", "readProcessList", "setStatusBar", "clearStatusBar", "setClipboard", "getClipboard"]',
      ),
    );

    final webBlock = _workflowJobBlock(workflow, 'web-runtime-loop');
    expect(
      webBlock,
      contains('fallback_suffix = ["hot-reload", "hot-restart"]'),
    );
    expect(webBlock, contains('assert verified_commands == expected_commands'));
    expect(webBlock, contains('startup_fallback_commands'));
    expect(webBlock, contains('stop_fallback_commands'));
    expect(webBlock, contains('platform["systemControlAdapter"]'));
    expect(
      webBlock,
      contains('platform.get("systemAvailableActions", []) == []'),
    );
    expect(
      webBlock,
      contains('platform.get("systemVerifiedActions", []) == []'),
    );
    for (final command in webExpectedCommands) {
      expect(
        webBlock,
        contains('"$command"'),
        reason: 'web-runtime-loop must assert the verifier command "$command".',
      );
    }
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

String _workflowJobBlock(String workflow, String jobName) {
  final start = workflow.indexOf('  $jobName:');
  expect(start, isNonNegative, reason: 'Missing workflow job $jobName.');
  final nextJob = RegExp(r'\n  [a-zA-Z0-9_-]+:\n')
      .allMatches(workflow, start + 1)
      .where((match) => match.start > start)
      .map((match) => match.start)
      .firstOrNull;
  return workflow.substring(start, nextJob ?? workflow.length);
}

String _workflowPlatformLabel(String jobName) {
  return switch (jobName) {
    'macos-runtime-loop' => 'macOS',
    'web-runtime-loop' => 'web',
    'linux-runtime-loop' => 'Linux',
    _ => throw ArgumentError.value(jobName, 'jobName', 'Unsupported job'),
  };
}
