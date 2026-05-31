import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;

  test('flutter-cockpit skill follows writing-skills structure rules', () {
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
    ).readAsStringSync();
    final pressureScenarios = File(
      '$root/skills/flutter-cockpit/pressure-scenarios.md',
    ).readAsStringSync();
    final wordCount = skill.split(RegExp(r'\s+')).where((word) {
      return word.trim().isNotEmpty;
    }).length;

    final frontmatterMatch = RegExp(
      r'^---\n(?<body>.*?)\n---\n',
      dotAll: true,
    ).firstMatch(skill);
    expect(frontmatterMatch, isNotNull);
    expect(frontmatterMatch!.group(0)!.length, lessThanOrEqualTo(1024));
    final frontmatter = frontmatterMatch.namedGroup('body')!.split('\n');
    expect(frontmatter, hasLength(2));
    expect(frontmatter[0], equals('name: flutter-cockpit'));
    expect('flutter-cockpit', matches(RegExp(r'^[a-zA-Z0-9-]+$')));
    expect(frontmatter[1], startsWith('description: Use when '));
    expect(
      frontmatter[1],
      isNot(anyOf(contains(' -> '), contains(' then '), contains('workflow'))),
    );

    expect(skill, contains('## Overview'));
    expect(skill, contains('## When To Use'));
    expect(skill, contains('## Quick Reference'));
    expect(skill, contains('## Common Mistakes'));
    expect(wordCount, lessThanOrEqualTo(1300));
    expect(skill, isNot(contains('@/')));
    expect(skill, isNot(contains('@skills')));
    expect(skill, isNot(contains('@superpowers')));

    expect(pressureScenarios, contains('RED/GREEN/REFACTOR'));
    expect(pressureScenarios, contains('Baseline Observation'));
    expect(pressureScenarios, contains('Post-Skill Validation'));
    expect(pressureScenarios, contains('Expected Naive Failure'));
    expect(pressureScenarios, contains('Target Corrected Behavior'));
  });

  test('flutter-cockpit skill teaches lowest-cost public surface usage', () {
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
    ).readAsStringSync();
    final contract = File(
      '$root/docs/contracts/flutter-cockpit-skill-contract.md',
    ).readAsStringSync();
    final cliReference = File(
      '$root/skills/flutter-cockpit/examples/cli-command-reference.md',
    ).readAsStringSync();
    final rapidLoop = File(
      '$root/skills/flutter-cockpit/examples/rapid-dev-loop.md',
    ).readAsStringSync();

    expect(skill, contains('## Development Rules'));
    expect(skill, contains('## Failure Recovery'));
    expect(skill, contains('## Other Surfaces'));
    expect(skill, contains('Copy-Ready Commands'));
    expect(skill, contains('App-first by default'));
    expect(skill, contains('Default app flow: `launch-app`'));
    expect(skill, contains('Keep app alive for next edit'));
    expect(skill, contains('`stop-app` is cleanup or recovery'));
    expect(skill, contains('not a loop step'));
    expect(skill, contains('when `hot-restart` cannot recover'));
    expect(skill, contains('clean rebuild/relaunch'));
    expect(
      skill,
      contains('named `captureScreenshot` before UI completion claim'),
    );
    expect(skill, contains('Evidence:'));
    expect(
      skill,
      contains('key mutating commands auto-attach best-effort screenshots'),
    );
    expect(skill, contains('Verify a completed non-empty artifact'));
    expect(
      skill,
      contains('For development recording, stay inside flutter_cockpit'),
    );
    expect(
      skill,
      contains('start-recording` -> interact/reload -> `stop-recording'),
    );
    expect(skill, contains('flutter_cockpit_devtools start-recording'));
    expect(skill, contains('flutter_cockpit_devtools stop-recording'));
    expect(skill, contains('Do not use external screen-recording tools'));
    expect(skill, contains('Persistent sessions'));
    expect(skill, contains('Direct remote is an escape hatch'));
    expect(skill, contains('help <command>'));
    expect(skill, contains('.dart_tool/flutter_cockpit/latest_app.json'));
    expect(skill, contains('jq'));
    expect(skill, contains('captureScreenshot'));
    expect(skill, contains('artifact refs or output paths'));
    expect(
      skill,
      contains('Do not wait until the final response to collect evidence'),
    );
    expect(skill, contains('run one named `captureScreenshot`'));
    expect(skill, contains('Do not set `type: Text` for button labels'));
    expect(skill, contains('Do not blindly replay a non-idempotent batch'));
    expect(skill, contains('re-read minimal route/state first'));
    expect(skill, contains('Prefer `run-batch` for route-crossing flows'));
    expect(skill, contains('errorJson'));
    expect(skill, contains('errorJson.code'));
    expect(skill, contains('errorJson.message'));
    expect(skill, contains('optional `details`'));
    expect(skill, contains('Differentiate `remoteUnavailable`'));
    expect(skill, contains('bridgeUnavailable'));
    expect(
      skill,
      contains('Treat `invalidPayload` as a caller command/option defect'),
    );
    expect(skill, contains('web browser-host recording'));
    expect(skill, contains('ffmpeg startup/output evidence missing'));
    expect(skill, contains('--ios-device-id <id>'));
    expect(skill, contains('--stdout-format json'));
    expect(skill, contains('--output <path>'));
    expect(skill, contains('--output-format json'));
    expect(
      skill,
      contains(
        'dart run flutter_cockpit_devtools:flutter_cockpit_devtools list-targets',
      ),
    );
    expect(
      skill,
      contains(
        'launch-app --project-dir <dir> --platform <platform> --device-id <id>',
      ),
    );
    expect(skill, contains('read-app --profile minimal'));
    expect(skill, contains('Do not shell-background `launch-app`'));
    expect(skill, contains('It returns after readiness'));
    expect(skill, contains('supervisor keeps logs'));
    expect(skill, contains('FlutterAppDelegate.h has been modified'));
    expect(
      skill,
      contains('run-command --command-file /tmp/flutter_cockpit/command.json'),
    );
    expect(
      skill,
      contains('run-batch --commands-file /tmp/flutter_cockpit/commands.json'),
    );
    expect(skill, contains('hot-reload'));
    expect(skill, contains('read-errors --max-errors 10'));
    expect(skill, contains('stop-app'));
    expect(
      skill,
      contains(
        'validate-task --config-json /tmp/flutter_cockpit/validate_task.json',
      ),
    );
    expect(skill, contains('MCP `read_task_bundle_summary`'));
    expect(skill, isNot(contains('--output-json')));
    expect(skill, isNot(contains('--output-ai')));
    expect(contract, contains('non-idempotent batch'));
    expect(contract, contains('route-aware recovery'));
    expect(contract, contains('launch-remote-session'));
    expect(contract, contains('execute-remote-command-batch'));
    expect(contract, contains('launch-development-session'));
    expect(contract, contains('collect-development-probe'));
    expect(contract, contains('start-remote-recording'));
    expect(contract, contains('host recording prerequisite reporting'));
    expect(contract, contains('completed recording evidence only'));
    expect(contract, contains('errorJson.code'));
    expect(contract, contains('errorJson.message'));
    expect(contract, contains('preserve remote endpoint error codes'));
    expect(contract, contains('artifactNotFound'));
    expect(contract, contains('caller payload or option problem'));
    expect(contract, contains('blocked_by_environment'));
    expect(
      contract,
      contains('explicit Android and iOS device-id passthrough'),
    );
    expect(cliReference, contains('--output'));
    expect(cliReference, contains('--output-format json'));
    expect(cliReference, isNot(contains('--output-json')));
    expect(cliReference, isNot(contains('--output-ai')));
    expect(cliReference, contains('--flavor'));
    expect(cliReference, contains('grep-package-uris'));
    expect(
      cliReference,
      contains('auto-normalizes the default `flutterApp` target kind'),
    );
    expect(cliReference, contains('do not need to pass `--target-kind`'));
    expect(cliReference, contains('launch-development-session'));
    expect(cliReference, contains('collect-development-probe'));
    expect(cliReference, contains('compare-development-probe'));
    expect(cliReference, contains('launch-remote-session'));
    expect(cliReference, contains('execute-remote-command-batch'));
    expect(cliReference, contains('jq'));
    expect(cliReference, contains('grep-package-uris'));
    expect(
      cliReference,
      contains('automation launch is not a supported browser path'),
    );
    expect(
      cliReference,
      contains('auto-normalizes the default `flutterApp` target kind'),
    );
    expect(cliReference, contains('scrollUntilVisible'));
    expect(cliReference, contains('enterText'));
    expect(cliReference, contains('lastReloadSucceeded'));
    expect(cliReference, contains('start-recording'));
    expect(
      cliReference,
      contains('launch-development-session` also writes an app handle'),
    );
    expect(
      cliReference,
      contains('instead of external screen-recording tools'),
    );
    expect(cliReference, contains('QuickTime'));
    expect(
      cliReference,
      contains('non-empty bytes or a non-empty source/output file'),
    );
    expect(cliReference, contains('Do not claim video recording coverage'));
    expect(
      cliReference,
      contains('unblock the recorder before claiming video proof'),
    );
    expect(cliReference, contains('read-task-bundle-summary'));
    expect(cliReference, contains('--bundle-dir /tmp/flutter_cockpit/out/'));
    expect(cliReference, contains('--app-json /tmp/flutter_cockpit/app.json'));
    expect(cliReference, contains('--ios-device-id <id>'));
    expect(rapidLoop, contains('jq'));
    expect(rapidLoop, contains('app.json'));
    expect(
      rapidLoop,
      contains('Do not run `launch-app` with shell backgrounding'),
    );
    expect(rapidLoop, contains('leaves a supervisor behind for logs'));
    expect(rapidLoop, contains('Do not call `stop-app` after every loop'));
    expect(rapidLoop, contains('use `stop-app` as cleanup or recovery'));
    expect(rapidLoop, contains('grep-package-uris'));
    expect(rapidLoop, contains('textPreviews'));
    expect(rapidLoop, contains('final explicit `captureScreenshot`'));
    expect(rapidLoop, contains('run-batch --recording-json'));
    expect(rapidLoop, contains('start-recording` -> interact/reload'));
    expect(rapidLoop, contains('stop-recording'));
    expect(
      rapidLoop,
      contains('use framework recording before external screen tools'),
    );
    expect(rapidLoop, contains('completed with a non-empty artifact'));
    expect(rapidLoop, contains('remoteUnavailable'));
    expect(rapidLoop, contains('smallest remaining step'));
    expect(rapidLoop, contains('Do not parallelize'));
  });

  test('flutter-cockpit skill references stay consistent', () {
    final skillDir = Directory('$root/skills/flutter-cockpit');
    final skillFiles =
        skillDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.md'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final docsByName = <String, String>{
      for (final file in skillFiles) file.path: file.readAsStringSync(),
    };
    final allDocs = docsByName.values.join('\n');

    expect(skillFiles.map((file) => file.path), contains(endsWith('SKILL.md')));
    expect(
      skillFiles.map((file) => file.path),
      contains(endsWith('INSTALL.md')),
    );
    expect(
      skillFiles.map((file) => file.path),
      contains(endsWith('pressure-scenarios.md')),
    );

    final skill = docsByName['${skillDir.path}/SKILL.md']!;
    for (final match in RegExp(
      r'\]\((examples/[^)]+\.md)\)',
    ).allMatches(skill)) {
      final relativePath = match.group(1)!;
      expect(
        File('${skillDir.path}/$relativePath').existsSync(),
        isTrue,
        reason: 'SKILL.md references missing file $relativePath',
      );
    }

    expect(allDocs, isNot(contains('--output-json')));
    expect(allDocs, isNot(contains('--output-ai')));
    expect(allDocs, isNot(contains('@/')));
    expect(allDocs, isNot(contains('@superpowers')));
    expect(allDocs, isNot(contains('High-Value Rules')));
    expect(allDocs, isNot(contains('first-use guardrails')));
    expect(allDocs, isNot(contains('observe step')));
    expect(allDocs, isNot(contains('observe stage')));
    expect(allDocs, isNot(contains('bootstrap, baseline, and observe')));

    final runtimeValidation =
        docsByName['${skillDir.path}/examples/runtime-validation.md']!;
    expect(
      runtimeValidation,
      contains('keep the app alive while more edits are likely'),
    );
    expect(
      runtimeValidation,
      contains('cleanup or recovery requires `stop-app`'),
    );
    expect(
      runtimeValidation,
      isNot(contains('read runtime errors, and stop the app')),
    );
    expect(runtimeValidation, contains('use flutter_cockpit recording first'));

    final cliReference =
        docsByName['${skillDir.path}/examples/cli-command-reference.md']!;
    expect(cliReference, contains('Stop the app only for cleanup or recovery'));
    expect(
      cliReference,
      contains(
        'CLI app recovery is `app.json` or `.dart_tool/flutter_cockpit/latest_app.json` first',
      ),
    );

    final rapidLoop =
        docsByName['${skillDir.path}/examples/rapid-dev-loop.md']!;
    expect(rapidLoop, contains('CLI `analyze-files` or MCP `analyze_files`'));
    expect(rapidLoop, contains('CLI `pub-dev-search` or MCP `pub_dev_search`'));
    expect(rapidLoop, contains('`run-tests`/`run_tests`'));

    final install = docsByName['${skillDir.path}/INSTALL.md']!;
    expect(install, contains('Do not assume the current agent is Codex'));
    expect(install, contains('symlink'));
    expect(install, contains('Restart the AI host'));

    final pressureScenarios =
        docsByName['${skillDir.path}/pressure-scenarios.md']!;
    expect(
      pressureScenarios,
      contains('post-action evidence read before judgment'),
    );
    expect(
      pressureScenarios,
      contains('CLI `launch-app` + `read-app` + `run-command`'),
    );
    expect(
      pressureScenarios,
      contains('quick reference and development rules'),
    );
  });
}
