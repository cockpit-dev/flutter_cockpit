import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;

  String readRepoFile(String path) => File('$root/$path').readAsStringSync();

  bool isSkillName(String value) {
    return value.codeUnits.every((unit) {
      return (unit >= 48 && unit <= 57) ||
          (unit >= 65 && unit <= 90) ||
          (unit >= 97 && unit <= 122) ||
          unit == 45;
    });
  }

  List<String> exampleReferencePaths(String skill) {
    final refs = <String>[];
    var offset = 0;
    while (true) {
      final linkStart = skill.indexOf('](examples/', offset);
      if (linkStart == -1) {
        return refs;
      }
      final pathStart = linkStart + 2;
      final pathEnd = skill.indexOf(')', pathStart);
      if (pathEnd == -1) {
        return refs;
      }
      final path = skill.substring(pathStart, pathEnd);
      if (path.endsWith('.md')) {
        refs.add(path);
      }
      offset = pathEnd + 1;
    }
  }

  test('flutter-cockpit skill follows writing-skills structure rules', () {
    final skill = readRepoFile('skills/flutter-cockpit/SKILL.md');
    final pressureScenarios = readRepoFile(
      'skills/flutter-cockpit/pressure-scenarios.md',
    );
    final normalizedSkill = skill
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ');
    final wordCount = normalizedSkill.split(' ').where((word) {
      return word.trim().isNotEmpty;
    }).length;

    expect(skill.startsWith('---\n'), isTrue);
    final frontmatterEnd = skill.indexOf('\n---\n', 4);
    expect(frontmatterEnd, greaterThan(0));
    expect(
      skill.substring(0, frontmatterEnd + '\n---\n'.length).length,
      lessThanOrEqualTo(1024),
    );
    final frontmatter = skill.substring(4, frontmatterEnd).split('\n');
    expect(frontmatter, hasLength(2));
    expect(frontmatter[0], equals('name: flutter-cockpit'));
    expect(isSkillName('flutter-cockpit'), isTrue);
    expect(frontmatter[1], startsWith('description: Use when '));
    expect(
      frontmatter[1],
      isNot(anyOf(contains(' -> '), contains(' then '), contains('workflow'))),
    );

    expect(skill, contains('## Overview'));
    expect(skill, contains('## When To Use'));
    expect(skill, contains('## First-Time App Wiring'));
    expect(skill, contains('## Stage Protocol'));
    expect(skill, contains('## Fast Command Pack'));
    expect(skill, contains('## Escalation Commands'));
    expect(skill, contains('## Common Mistakes'));
    expect(wordCount, lessThanOrEqualTo(1400));
    expect(skill, isNot(contains('@/')));
    expect(skill, isNot(contains('@skills')));
    expect(skill, isNot(contains('@superpowers')));

    expect(pressureScenarios, contains('RED/GREEN/REFACTOR'));
    expect(pressureScenarios, contains('Baseline Observation'));
    expect(pressureScenarios, contains('Post-Skill Validation'));
    expect(pressureScenarios, contains('Expected Naive Failure'));
    expect(pressureScenarios, contains('Target Corrected Behavior'));
  });

  test('flutter-cockpit skill enforces the AI development protocol', () {
    final skill = readRepoFile('skills/flutter-cockpit/SKILL.md');
    final contract = readRepoFile(
      'docs/contracts/flutter-cockpit-skill-contract.md',
    );
    final stages = <String>[
      'assess',
      'bootstrap',
      'baseline',
      'execute',
      'observe',
      'judge',
      'deliver',
    ];

    var lastIndex = -1;
    for (final stage in stages) {
      final index = skill.indexOf('**$stage**');
      expect(index, greaterThan(lastIndex), reason: '$stage stage order');
      lastIndex = index;
    }

    expect(
      skill,
      contains(
        '`assess -> bootstrap -> baseline -> execute -> observe -> judge -> deliver`',
      ),
    );
    expect(contract, contains('The skill must enforce this order'));
    for (final stage in stages) {
      expect(contract, contains('`$stage`'));
    }
    expect(contract, contains('rapid development validation'));
    expect(contract, contains('cheapest live loop'));
    expect(contract, contains('main skill must be self-contained'));
    expect(contract, contains('reference files are optional deep dives'));
    expect(contract, contains('not reward running extra recording'));
    expect(contract, contains('capture-screenshot'));
    expect(contract, contains('capture_screenshot'));
    expect(contract, contains('when they do not improve the decision'));
    expect(contract, contains('small edit can be complete'));
    expect(contract, contains('platform-discovery-first'));
    expect(contract, contains('Platform and device ids must come from'));
    expect(
      contract,
      contains('platform capabilities must be read from returned metadata'),
    );
    expect(
      contract.toLowerCase(),
      contains(
        'action parameter contracts must be read from returned metadata',
      ),
    );
    expect(
      contract,
      contains('parameters=[name*:type[range](allowed|values)]'),
    );

    expect(skill, contains('Default to app-first'));
    expect(skill, contains('Default to rapid development validation'));
    expect(skill, contains('cheapest live loop that answers the user'));
    expect(skill, contains('then stop'));
    expect(
      skill,
      contains('decision gates, not a fixed command script or command quota'),
    );
    expect(
      skill,
      contains('Satisfy each gate with the smallest fresh evidence available'),
    );
    expect(skill, contains('skip irrelevant commands'));
    expect(
      skill,
      contains(
        'choose CLI, MCP, app-first, target-first, persistent-session, or bundle flows',
      ),
    );
    expect(skill, contains('launch once or reuse a handle'));
    expect(skill, contains('never shell-background it'));
    expect(skill, contains('.dart_tool/flutter_cockpit/latest_app.json'));
    expect(skill, contains('add `cockpit/main.dart`'));
    expect(skill, contains('keep the production entrypoint intact'));
    expect(skill, contains('FlutterCockpitApp'));
    expect(skill, contains('FlutterCockpit.navigatorObserver'));
    expect(
      skill,
      contains('CockpitRemoteSessionConfiguration.resolveFromEnvironment'),
    );
    expect(skill, contains('read before acting'));
    expect(
      skill,
      contains(
        'unless a fresh equivalent read already answers the same question',
      ),
    );
    expect(skill, contains('read post-action state before judging'));
    expect(skill, contains('Command success is not product proof'));
    expect(
      skill,
      contains('Do not open screenshots, videos, or raw artifacts'),
    );
    expect(skill, contains('`stop-app` is cleanup or recovery only'));
    expect(skill, contains('not a normal loop step'));
    expect(skill, contains('framework recording first'));
    expect(skill, contains('unless the content is the unresolved question'));
    expect(skill, contains('run `capture-screenshot --name <proof-name>`'));
    expect(skill, contains('Do not set `type: Text` for button labels'));
    expect(skill, contains('do not replay blindly'));
    expect(skill, contains('resume from the smallest remaining safe step'));
    expect(skill, contains('Be flexible on commands, strict on proof'));
    expect(skill, contains('Fast path for most edits'));
    expect(skill, contains('Every command should reduce uncertainty'));
    expect(
      skill,
      contains('use the returned platform, device id, and capability metadata'),
    );
    expect(
      skill,
      contains(
        'Keep platform and device placeholders until `list-targets` returns real values',
      ),
    );
    expect(
      skill,
      contains(
        'read capabilities before choosing shell, recording, browser, or native paths',
      ),
    );
    expect(skill, contains('parameters=[name*:type[range](allowed|values)]'));
    expect(skill, contains('Do not guess payload keys'));
    expect(
      skill,
      contains(
        'Do not run recording, evidence profiles, bundle validation, or raw artifact reads just because they exist',
      ),
    );
  });

  test('flutter-cockpit skill keeps commands minimal and copy-ready', () {
    final skill = readRepoFile('skills/flutter-cockpit/SKILL.md');
    final cliReference = readRepoFile(
      'skills/flutter-cockpit/examples/cli-command-reference.md',
    );
    final rapidLoop = readRepoFile(
      'skills/flutter-cockpit/examples/rapid-dev-loop.md',
    );
    final runtimeValidation = readRepoFile(
      'skills/flutter-cockpit/examples/runtime-validation.md',
    );
    final acceptanceDelivery = readRepoFile(
      'skills/flutter-cockpit/examples/acceptance-delivery.md',
    );
    final hostSetup = readRepoFile(
      'skills/flutter-cockpit/examples/host-devtools-setup.md',
    );

    expect(skill, contains('list-targets'));
    expect(
      skill,
      contains(
        'launch-app --project-dir <dir> --platform <platform> --device-id <id>',
      ),
    );
    expect(skill, contains('read-app --profile minimal'));
    expect(skill, contains('analyze-files --path <changed-file>'));
    expect(skill, contains('hot-reload'));
    expect(skill, contains('read-errors --max-errors 10'));
    expect(skill, contains('run-command --command-file'));
    expect(skill, contains('capture-screenshot --name acceptance'));
    expect(skill, contains('run-batch --commands-file'));
    expect(skill, contains('start-recording'));
    expect(skill, contains('stop-recording'));
    expect(skill, contains('validate-task --config'));
    expect(skill, contains('--stdout-format json'));
    expect(skill, contains('--output <path>'));
    expect(skill, contains('--output-format json'));
    expect(skill, isNot(contains('--output-json')));
    expect(skill, isNot(contains('--output-ai')));

    final fastStart = skill.indexOf('## Fast Command Pack');
    final escalationStart = skill.indexOf('## Escalation Commands');
    expect(fastStart, isNonNegative);
    expect(escalationStart, greaterThan(fastStart));
    final fastSection = skill.substring(fastStart, escalationStart);
    final escalationSection = skill.substring(escalationStart);
    expect(fastSection, contains('run-command --command-file'));
    expect(fastSection, isNot(contains('start-recording')));
    expect(fastSection, isNot(contains('validate-task --config')));
    expect(escalationSection, contains('run-batch --commands-file'));
    expect(escalationSection, contains('start-recording'));
    expect(escalationSection, contains('stop-recording'));
    expect(escalationSection, contains('validate-task --config'));
    expect(
      escalationSection,
      contains('Use these only when the next claim needs them'),
    );

    expect(cliReference, contains('--output'));
    expect(cliReference, contains('--output-format json'));
    expect(cliReference, contains('--stdout-format json'));
    expect(cliReference, contains('launch-development-session'));
    expect(cliReference, contains('execute-remote-command-batch'));
    expect(cliReference, contains('capture-screenshot'));
    expect(cliReference, contains('read-task-bundle-summary'));
    expect(cliReference, contains('start-recording'));
    expect(cliReference, contains('stop-recording'));
    expect(
      cliReference,
      contains('Choose `--platform` and `--device-id` from `list-targets`'),
    );
    expect(cliReference, contains('Keep placeholders'));
    expect(cliReference, contains('discovery returns real values'));
    expect(cliReference, contains('--platform <platform-from-list-targets>'));
    expect(cliReference, contains('--device-id <device-id-from-list-targets>'));
    expect(cliReference, contains('parameters=[x*:integer'));
    expect(cliReference, contains('capabilities[].parameters[]'));
    expect(
      cliReference,
      contains('macOS host screenshots and\nrecordings need the app bundle id'),
    );
    expect(
      cliReference,
      contains(
        'Windows and Linux can target either the app\nid or a process id from launch metadata',
      ),
    );
    expect(cliReference, contains('--platform windows'));
    expect(cliReference, contains('--process-id <pid>'));
    expect(
      cliReference,
      contains('For desktop system recording, keep the same target context'),
    );
    expect(cliReference, isNot(contains('--output-json')));
    expect(cliReference, isNot(contains('--output-ai')));

    expect(
      rapidLoop,
      contains('Do not run `launch-app` with shell backgrounding'),
    );
    expect(rapidLoop, contains('Do not call `stop-app` after every loop'));
    expect(
      rapidLoop,
      contains('final explicit `capture-screenshot --name <proof-name>`'),
    );
    expect(
      rapidLoop,
      contains('use framework recording before external screen tools'),
    );
    expect(rapidLoop, contains('remoteUnavailable'));
    expect(rapidLoop, contains('smallest remaining step'));
    expect(rapidLoop, contains('`list-targets` if platform/device is unknown'));
    expect(
      rapidLoop,
      contains(
        'Choose shell, recording, browser, and native-surface commands from discovered capabilities',
      ),
    );
    expect(
      rapidLoop,
      contains('Before claiming delivery, release readiness, or acceptance'),
    );
    expect(
      rapidLoop,
      contains('specifically requires delivery, release readiness, acceptance'),
    );
    expect(
      rapidLoop,
      contains(
        'avoid bundle generation until the feature is ready for delivery, acceptance, release, or artifact-backed handoff',
      ),
    );
    expect(
      runtimeValidation,
      contains('fastest loop that answers the current question'),
    );
    expect(
      runtimeValidation,
      contains(
        '`list-targets` if the platform or device id is not already known',
      ),
    );
    expect(
      runtimeValidation,
      contains(
        'Read platform-specific behavior from discovered target metadata',
      ),
    );
    expect(
      runtimeValidation,
      contains('not a release checklist for every edit'),
    );
    expect(
      runtimeValidation,
      contains('only for an existing bundle or acceptance-facing claim'),
    );
    expect(
      runtimeValidation,
      contains(
        'Do not add recordings, full snapshots, target-first inspection, or bundle',
      ),
    );
    expect(
      runtimeValidation,
      contains('unless they reduce a concrete remaining'),
    );
    expect(
      acceptanceDelivery,
      contains('Do not use it for ordinary edit -> reload -> verify loops'),
    );
    expect(
      acceptanceDelivery,
      contains('confirm this is acceptance-facing work'),
    );
    expect(acceptanceDelivery, contains('smallest useful artifact paths'));
    expect(
      acceptanceDelivery,
      contains('return to the rapid loop instead of manufacturing extra'),
    );
    expect(acceptanceDelivery, contains('artifacts.'));
    expect(
      hostSetup,
      contains('low-cost public surface that answers the current task'),
    );
    expect(
      hostSetup,
      contains(
        'Do not expose or invoke delivery workflows as the normal edit loop',
      ),
    );
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
    for (final relativePath in exampleReferencePaths(skill)) {
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
    expect(runtimeValidation, contains('use flutter_cockpit recording first'));

    final install = docsByName['${skillDir.path}/INSTALL.md']!;
    expect(install, contains('Do not assume the current agent is Codex'));
    expect(install, contains('symlink'));
    expect(install, contains('not an older checkout or a deleted path'));
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
    expect(pressureScenarios, contains('random command picker'));
    expect(pressureScenarios, contains('Over-Validation Pressure'));
    expect(pressureScenarios, contains('cheapest live loop'));
    expect(
      pressureScenarios,
      contains('running heavy evidence just because it exists'),
    );
    expect(pressureScenarios, contains('Platform Discovery Pressure'));
    expect(
      pressureScenarios,
      contains(
        'start with `list-targets` whenever the platform or device id is unknown',
      ),
    );
    expect(
      pressureScenarios,
      contains(
        'copied commands use placeholders until real platform and device ids are known',
      ),
    );
    expect(
      pressureScenarios,
      contains('CLI reference launch examples use discovered placeholders'),
    );
  });
}
