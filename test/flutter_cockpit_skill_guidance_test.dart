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

    expect(skill, contains('High-Value Rules'));
    expect(skill, contains('Copy-Ready Commands'));
    expect(skill, contains('app-first'));
    expect(skill, contains('Persistent edit loop'));
    expect(skill, contains('Direct remote is an escape hatch'));
    expect(skill, contains('help <command>'));
    expect(skill, contains('.dart_tool/flutter_cockpit/latest_app.json'));
    expect(skill, contains('jq'));
    expect(skill, contains('captureScreenshot'));
    expect(skill, contains('artifact refs or output paths'));
    expect(skill, contains('Do not blindly replay a non-idempotent batch'));
    expect(skill, contains('re-read minimal route or state before retrying'));
    expect(skill, contains('Prefer `run-batch` for route-crossing flows'));
    expect(skill, contains('errorJson'));
    expect(skill, contains('`code`, `message`, and optional `details`'));
    expect(skill, contains('non-usage failures'));
    expect(skill, contains('optional `details`'));
    expect(skill, contains('Do not collapse all remote failures'));
    expect(skill, contains('bridgeUnavailable'));
    expect(skill,
        contains('Treat `invalidPayload` as a command or option defect'));
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
    expect(
      skill,
      contains('read-app --profile minimal'),
    );
    expect(
      skill,
      contains('run-command --command-file /tmp/flutter_cockpit/command.json'),
    );
    expect(
      skill,
      contains('run-batch --commands-file /tmp/flutter_cockpit/commands.json'),
    );
    expect(
      skill,
      contains('hot-reload'),
    );
    expect(
      skill,
      contains('read-errors --max-errors 10'),
    );
    expect(
      skill,
      contains('stop-app'),
    );
    expect(
      skill,
      contains(
          'validate-task --config-json /tmp/flutter_cockpit/validate_task.json'),
    );
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
        contract, contains('explicit Android and iOS device-id passthrough'));
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
    expect(
      cliReference,
      contains('do not need to pass `--target-kind`'),
    );
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
    expect(cliReference,
        contains('non-empty bytes or a non-empty source/output file'));
    expect(cliReference, contains('Do not claim video recording coverage'));
    expect(
      cliReference,
      contains('unblock the recorder before claiming video proof'),
    );
    expect(cliReference, contains('--app-json /tmp/flutter_cockpit/app.json'));
    expect(cliReference, contains('--ios-device-id <id>'));
    expect(rapidLoop, contains('jq'));
    expect(rapidLoop, contains('app.json'));
    expect(rapidLoop, contains('grep-package-uris'));
    expect(rapidLoop, contains('textPreviews'));
    expect(rapidLoop, contains('remoteUnavailable'));
    expect(rapidLoop, contains('smallest remaining step'));
    expect(rapidLoop, contains('Do not parallelize'));
  });
}
