import 'package:args/command_runner.dart';

final class CockpitCliCategory {
  static const String coreLoop = 'Core loop';
  static const String workspace = 'Workspace';
  static const String evidence = 'Evidence';
  static const String delivery = 'Delivery';
  static const String server = 'Server';
}

final class CockpitCliRootRunner extends CommandRunner<int> {
  CockpitCliRootRunner()
      : super(
          'flutter_cockpit_devtools',
          'AI-first host tooling for flutter_cockpit.',
          usageLineLength: 96,
        );

  @override
  String get usage {
    final buffer = StringBuffer()
      ..writeln(description)
      ..writeln()
      ..writeln('Usage: $invocation')
      ..writeln()
      ..writeln('Global options:')
      ..writeln(argParser.usage)
      ..writeln()
      ..writeln('Available commands:')
      ..writeln();

    _writeSection(
      buffer,
      'Core loop',
      const <String>[
        'list-targets',
        'launch-app',
        'launch-target',
        'read-app',
        'read-target',
        'inspect-surface',
        'run-command',
        'run-batch',
        'inspect-ui',
        'wait-idle',
        'hot-reload',
        'hot-restart',
        'stop-app',
      ],
    );
    buffer.writeln();
    _writeSection(
      buffer,
      'Workspace',
      const <String>[
        'pub-dev-search',
        'pub',
        'run-shell',
        'read-package-uris',
        'grep-package-uris',
        'lsp',
        'analyze-files',
        'create-project',
        'analyze-workspace',
        'format-workspace',
        'run-tests',
        'apply-fixes',
      ],
    );
    buffer.writeln();
    _writeSection(
      buffer,
      'Delivery',
      const <String>['run-script', 'run-task', 'validate-task'],
    );
    buffer.writeln();
    _writeSection(
      buffer,
      'Evidence',
      const <String>[
        'read-network',
        'read-errors',
        'read-logs',
        'start-recording',
        'stop-recording',
      ],
    );
    buffer.writeln();
    _writeSection(buffer, 'Server', const <String>['serve-mcp']);
    buffer.writeln();
    buffer.writeln(
      'Run "$executableName help <command>" for more information about a command.',
    );
    if (usageFooter case final footer?) {
      buffer.write(footer);
    }
    return buffer.toString();
  }

  @override
  String? get usageFooter => <String>[
        'Fast loop (default app-first):',
        '  list-targets',
        '  launch-app --project-dir <dir> --platform <platform> [--device-id <id for android|ios|web>]',
        '  read-app --profile minimal',
        '  run-command --command-file <command.json>',
        '  stop-app',
        'Target-first loop (only when target truth matters more than an app handle):',
        '  launch-target --project-dir <dir> --platform <platform> --target-json /tmp/target.json --output-json /tmp/launch_target.json [--device-id <id when needed>]',
        '  read-target --target-json <target.json> --profile minimal',
        'Workspace loop:',
        '  analyze-files --path lib/main.dart',
        '  grep-package-uris --package flutter --query ThemeData | jq \'.packages[0].files[0].packageUri\'',
        '  lsp --command hover --path lib/main.dart --line 12 --column 8',
        '  pub --command get',
        'If a flag or JSON shape is unclear, run "flutter_cockpit_devtools help <command>" before guessing.',
        'launch-app auto-detects cockpit/main.dart first, then lib/main.dart.',
        'Most app-scoped commands reuse .dart_tool/flutter_cockpit/latest_app.json in the current working directory when it exists.',
        "launch-target --target-json persists target-first state only. If later app-scoped commands are needed, recover the embedded app handle from --output-json: jq '.app' /tmp/launch_target.json > /tmp/app.json",
        'Default JSON output goes to stdout, so short follow-up reads can use jq or other shell pipes immediately.',
        'Use --output-json only when the result is too large for stdout or a later step needs to reopen the full payload from disk.',
        'Prefer app-first unless target-first surface truth is the real question.',
        'Delivery loop:',
        '  run-task --config-json <task.json>',
        '  validate-task --config-json <validate_task.json>',
        'Delivery: run-script writes a bundle from a running app. run-task and validate-task launch, execute, classify, and validate end to end.',
        'Workspace commands default --workspace-root or --parent-directory to the current directory.',
      ].join('\n');

  void _writeSection(StringBuffer buffer, String title, List<String> names) {
    buffer.writeln(title);
    final width = names.fold<int>(0, (maxWidth, name) {
      return name.length > maxWidth ? name.length : maxWidth;
    });
    for (final name in names) {
      final command = commands[name];
      if (command == null) {
        continue;
      }
      final padding = ' ' * (width - name.length);
      buffer.writeln('  $name$padding   ${command.summary}');
    }
  }
}

abstract base class CockpitCliCommand extends Command<int> {
  @override
  bool get takesArguments => false;

  String? get helpWhen => null;

  String? get helpNeeds => null;

  String? get helpShape => null;

  String? get helpExample => null;

  String? get helpWrites => null;

  @override
  String? get usageFooter {
    final lines = <String>[
      if (helpWhen case final whenText?) 'When: $whenText',
      if (helpNeeds case final needs?) 'Needs: $needs',
      if (helpShape case final shape?) 'Shape: $shape',
      if (helpExample case final example?) 'Example: $example',
      if (helpWrites case final writes?) 'Writes: $writes',
    ];
    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }
}
