import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;
  final workflowFile = File('$root/.github/workflows/runtime-loop.yml');
  final exampleE2eWorkflowFile = File(
    '$root/.github/workflows/example-e2e.yml',
  );
  final platformCapabilitiesWorkflowFile = File(
    '$root/.github/workflows/platform-capabilities.yml',
  );
  final melosConfigFile = File('$root/melos.yaml');
  final demoReadmeFile = File('$root/examples/cockpit_demo/README.md');
  final platformVerifierFile = File(
    '$root/examples/cockpit_demo/tool/verify_platforms.dart',
  );
  final rapidDevVerifierFile = File(
    '$root/examples/cockpit_demo/tool/verify_rapid_dev.dart',
  );
  final androidVerifierScriptFile = File(
    '$root/.github/scripts/run-android-verifier.sh',
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
        'flutter analyze packages/flutter_cockpit packages/cockpit examples/cockpit_demo test',
      ),
    );
    expect(workflow, contains('flutter pub publish --dry-run'));
    expect(workflow, contains('dart pub publish --dry-run'));
    expect(workflow, contains('dart test test'));
    expect(workflow, contains('(cd packages/flutter_cockpit && flutter test)'));
    expect(workflow, contains('(cd packages/cockpit && dart test)'));
    expect(workflow, contains('(cd examples/cockpit_demo && flutter test)'));
    expect(workflow, isNot(contains('run: melos run test')));
    expect(workflow, isNot(contains('run: dart run melos test')));
    expect(workflow, contains('android-runtime-loop:'));
    expect(workflow, contains('ios-runtime-loop:'));
    expect(workflow, contains('macos-runtime-loop:'));
    expect(workflow, contains('web-runtime-loop:'));
    expect(workflow, contains('linux-runtime-loop:'));
    expect(workflow, contains('windows-runtime-loop:'));

    final androidVerifierScript = androidVerifierScriptFile.readAsStringSync();
    expect(
      androidVerifierScript,
      contains('dart run tool/verify_platforms.dart'),
    );
    expect(androidVerifierScript, contains('--platform android'));
    expect(
      androidVerifierScript,
      contains('--launch-timeout-seconds "\$LAUNCH_TIMEOUT_SECONDS"'),
    );
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
    expect(workflow, contains('working-directory: packages/cockpit'));
    expect(workflow, contains(r'STATUS=${PIPESTATUS[0]}'));
    expect(workflow, contains('xvfb-run -a dart run'));
    expect(workflow, contains('reactivecircus/android-emulator-runner@v2'));
    expect(workflow, contains('subprocess.TimeoutExpired'));
    expect(workflow, contains('xcrun", "simctl", "bootstatus"'));
    expect(workflow, isNot(contains('timeout 150 xcrun')));
    expect(workflow, contains('"sync_lab_conflict_recovery"'));
    expect(workflow, contains('assert platform["batchCommandCount"] == 31'));
    expect(workflow, contains('assert platform["autoScreenshotCount"] >= 18'));
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
    expect(windowsBlock, contains('cockpit_development_supervisor_*.log'));
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

  test('one-shot demo verifiers flush output and exit explicitly', () {
    for (final verifierFile in <File>[
      platformVerifierFile,
      rapidDevVerifierFile,
    ]) {
      final verifier = verifierFile.readAsStringSync();

      expect(verifier, contains('Future<int> _finishVerifierRun('));
      expect(verifier, contains('await stdout.flush();'));
      expect(verifier, contains('await stderr.flush();'));
      expect(verifier, contains('exit(await _finishVerifierRun('));
      expect(verifier, isNot(contains('exitCode = result.success ? 0 : 1;')));
    }
  });

  test(
    'one-shot demo verifiers keep terminal output bounded for file output',
    () {
      for (final verifierFile in <File>[
        platformVerifierFile,
        rapidDevVerifierFile,
      ]) {
        final verifier = verifierFile.readAsStringSync();

        expect(verifier, contains("stdout.writeln('output=\${file.path}');"));
      }
    },
  );

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

  test('linux runtime loop keeps apt payload bounded and retried', () {
    final workflow = workflowFile.readAsStringSync();
    final linuxBlock = _workflowJobBlock(workflow, 'linux-runtime-loop');

    expect(linuxBlock, contains('DEBIAN_FRONTEND: noninteractive'));
    expect(linuxBlock, contains('apt_retry()'));
    expect(
      linuxBlock,
      contains('sudo apt-get install -y --no-install-recommends'),
    );
    expect(linuxBlock, contains('libgtk-3-dev'));
    expect(linuxBlock, contains('clang'));
    expect(linuxBlock, contains('cmake'));
    expect(linuxBlock, contains('ninja-build'));
    expect(linuxBlock, contains('pkg-config'));
    expect(linuxBlock, contains('xvfb'));
    expect(linuxBlock, contains('x11-utils'));
    expect(linuxBlock, isNot(contains('libgstreamer')));
    expect(linuxBlock, isNot(contains('gstreamer1.0-libav')));
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
    final fallbackSuffix = <String>['hot-reload', 'hot-restart'];
    final startupFallbackCommands = <String>[
      for (final command in commonExpectedCommands)
        if (command != 'start-recording' && command != 'stop-recording')
          command,
    ];
    final startupFallbackCommandsWithTimeline = <String>[
      ...startupFallbackCommands.sublist(
        0,
        startupFallbackCommands.length - fallbackSuffix.length,
      ),
      'timeline-recording-fallback',
      ...fallbackSuffix,
    ];
    final stopFallbackCommands = <String>[...commonExpectedCommands]
      ..insert(
        commonExpectedCommands.indexOf('wait-idle'),
        'timeline-recording-fallback',
      );
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
        expect(
          block,
          contains('assert platform["verifiedCommands"] == expected_commands'),
        );
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
          contains('verified_commands = platform["verifiedCommands"]'),
        );
        expect(
          block,
          contains('assert verified_commands == expected_commands'),
        );
        expect(block, contains('assert verified_commands in ('));
        expect(
          block,
          contains(
            'platform["systemVerifiedActions"] == ["readSystemState", "readProcessList"]',
          ),
        );
        expect(
          block,
          contains('expected_driver = os.environ["EXPECTED_RECORDING_DRIVER"]'),
        );
        expect(block, contains('startup_fallback_commands'));
        expect(block, contains('stop_fallback_commands'));
        expect(
          block,
          contains('if command not in ("start-recording", "stop-recording")'),
        );
        expect(block, contains('+ ["timeline-recording-fallback"]'));
        expect(block, contains('stop_fallback_commands.insert('));
        expect(
          startupFallbackCommandsWithTimeline,
          isNot(contains('start-recording')),
        );
        expect(
          startupFallbackCommandsWithTimeline,
          isNot(contains('stop-recording')),
        );
        expect(stopFallbackCommands, contains('start-recording'));
        expect(stopFallbackCommands, contains('stop-recording'));
        expect(block, contains('recording_driver == expected_driver'));
        expect(
          block,
          contains('recording_driver == f"{expected_driver}-fallback"'),
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

  test('publish dry-runs restore Flutter workspace dependency resolution', () {
    final workflow = workflowFile.readAsStringSync();
    final readinessBlock = _workflowStepBlock(
      workflow,
      'Run publish readiness gates',
    );

    expect(readinessBlock, contains('flutter pub get'));
    expect(readinessBlock, contains('git diff --exit-code pubspec.lock'));
  });

  test(
    'dart package regression tests restore Flutter workspace resolution',
    () {
      final workflow = workflowFile.readAsStringSync();
      final regressionBlock = _workflowStepBlock(
        workflow,
        'Run full shared regression suite',
      );

      expect(regressionBlock, contains('(cd packages/cockpit && dart test)'));
      expect(regressionBlock, contains('flutter pub get'));
      expect(regressionBlock, contains('git diff --exit-code pubspec.lock'));
    },
  );

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

  test('example e2e workflow is self-contained and strict', () {
    final workflow = exampleE2eWorkflowFile.readAsStringSync();

    for (final jobName in <String>[
      'rapid-dev-macos-ios',
      'rapid-dev-android',
      'rapid-dev-web',
      'rapid-dev-linux',
      'rapid-dev-windows',
    ]) {
      final block = _workflowJobBlock(workflow, jobName);
      expect(
        block,
        contains('subosito/flutter-action@v2'),
        reason: '$jobName must install the pinned Flutter SDK.',
      );
      expect(
        block,
        contains('flutter-version: \${{ env.FLUTTER_VERSION }}'),
        reason: '$jobName must use the workflow Flutter version.',
      );
    }

    final webBlock = _workflowJobBlock(workflow, 'rapid-dev-web');
    expect(webBlock, contains('assert data["success"] is True'));
    expect(webBlock, isNot(contains('known web gap')));
    expect(webBlock, isNot(contains('failureCode"] == "serverError"')));

    final androidVerifierBlock = _workflowStepBlock(
      workflow,
      'Run rapid-dev verifier (Android)',
    );
    expect(androidVerifierBlock, isNot(contains('pipefail')));
    expect(
      androidVerifierBlock,
      contains(
        'script: bash "\$GITHUB_WORKSPACE/.github/scripts/run-android-verifier.sh" rapid-dev',
      ),
    );
  });

  test('android emulator runner steps use single-shell repository scripts', () {
    final androidVerifierScript = androidVerifierScriptFile.readAsStringSync();

    expect(androidVerifierScript, contains('cd "\$PROJECT_DIR"'));
    expect(androidVerifierScript, contains('STATUS=\$?'));
    expect(androidVerifierScript, contains('cat "\$LOG_PATH"'));
    expect(androidVerifierScript, contains('platform-capabilities)'));
    expect(androidVerifierScript, contains('runtime-loop)'));
    expect(androidVerifierScript, contains('rapid-dev)'));

    final workflowSteps = <String, String>{
      'runtime-loop': _workflowStepBlock(
        workflowFile.readAsStringSync(),
        'Run Android full verifier',
      ),
      'example-e2e': _workflowStepBlock(
        exampleE2eWorkflowFile.readAsStringSync(),
        'Run rapid-dev verifier (Android)',
      ),
      'platform-capabilities': _workflowStepBlock(
        platformCapabilitiesWorkflowFile.readAsStringSync(),
        'Run exhaustive capability verifier (Android)',
      ),
    };

    for (final entry in workflowSteps.entries) {
      expect(
        entry.value,
        contains(
          'script: bash "\$GITHUB_WORKSPACE/.github/scripts/run-android-verifier.sh"',
        ),
        reason:
            '${entry.key} must run Android verifier logic inside one bash process because android-emulator-runner executes inline script lines independently.',
      );
      expect(entry.value, isNot(contains('cd "\$GITHUB_WORKSPACE')));
      expect(entry.value, isNot(contains('dart run tool/verify_')));
    }
  });

  test('workflow artifact uploads cannot mask verifier results', () {
    for (final entry in <MapEntry<String, File>>[
      MapEntry<String, File>('runtime-loop', workflowFile),
      MapEntry<String, File>('example-e2e', exampleE2eWorkflowFile),
      MapEntry<String, File>(
        'validation-examples',
        File('$root/.github/workflows/validation-examples.yml'),
      ),
      MapEntry<String, File>(
        'platform-capabilities',
        platformCapabilitiesWorkflowFile,
      ),
    ]) {
      final workflow = entry.value.readAsStringSync();
      final uploadStepPattern = RegExp(
        r'^      - name: .*Upload[\s\S]*?^        uses: actions/upload-artifact@v7',
        multiLine: true,
      );
      final matches = uploadStepPattern.allMatches(workflow).toList();

      expect(matches, isNotEmpty, reason: '${entry.key} should upload bundles');
      for (final match in matches) {
        final block = match.group(0)!;
        expect(
          block,
          contains('continue-on-error: true'),
          reason:
              '${entry.key} artifact upload should preserve verifier result when GitHub artifact storage is temporarily unavailable.',
        );
      }
    }
  });

  test('platform capability workflow verifies actions strictly', () {
    final workflow = platformCapabilitiesWorkflowFile.readAsStringSync();
    final verifier = File(
      '$root/examples/cockpit_demo/tool/src/cockpit_demo_platform_verifier.dart',
    ).readAsStringSync();

    expect(workflow, contains('name: platform-capabilities'));
    expect(workflow, contains('--exhaustive-system-control'));
    expect(workflow, contains('assert data["success"] is True'));
    expect(workflow, isNot(contains('WARN ')));
    expect(workflow, isNot(contains('only {sc_ratio:.0%}')));
    expect(workflow, isNot(contains('sc_ratio >= 0.5')));

    expect(verifier, contains('request.exhaustiveSystemControl'));
    expect(verifier, contains('systemControlActionFailed'));
    expect(
      verifier,
      isNot(contains('exhaustive action \${action.name} failed (best-effort)')),
    );
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

String _workflowStepBlock(String workflow, String stepName) {
  final start = workflow.indexOf('      - name: $stepName');
  expect(start, isNonNegative, reason: 'Missing workflow step $stepName.');
  final nextStep = workflow.indexOf('\n      - name:', start + 1);
  return workflow.substring(start, nextStep == -1 ? workflow.length : nextStep);
}

String _workflowPlatformLabel(String jobName) {
  return switch (jobName) {
    'macos-runtime-loop' => 'macOS',
    'web-runtime-loop' => 'web',
    'linux-runtime-loop' => 'Linux',
    _ => throw ArgumentError.value(jobName, 'jobName', 'Unsupported job'),
  };
}
