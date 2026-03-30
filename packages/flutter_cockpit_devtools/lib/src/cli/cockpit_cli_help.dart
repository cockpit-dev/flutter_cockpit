import 'package:args/command_runner.dart';

final class CockpitCliCategory {
  static const String coreLoop = 'Core loop';
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
        'read-app',
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
      'Delivery',
      const <String>['run-script', 'run-task', 'validate-task'],
    );
    buffer.writeln();
    _writeSection(
      buffer,
      'Evidence',
      const <String>[
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
        'Fast loop:',
        '  list-targets',
        '  launch-app --project-dir <dir> --platform <platform> --app-json <app.json>',
        '  read-app --app-json <app.json> --profile minimal',
        '  run-command --app-json <app.json> --command-file <command.json>',
        '  stop-app --app-json <app.json>',
        'launch-app auto-detects cockpit/main.dart first, then lib/main.dart.',
        'Use --output-json when a result is too large for stdout. launch-app writes the app handle reused by most app commands.',
        'Delivery: run-script writes a bundle from a running app. run-task and validate-task launch, execute, classify, and validate end to end.',
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
