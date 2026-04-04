import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_pub_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitPubFunction = Future<CockpitPubResult> Function(
  CockpitPubRequest request,
);

final class PubCommand extends CockpitCliCommand {
  PubCommand({
    CockpitPubService? service,
    CockpitPubFunction? run,
    StringSink? stdoutSink,
  })  : _run = run ?? (service ?? CockpitPubService()).run,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser
      ..addOption(
        'command',
        allowed: CockpitPubCommand.values
            .map((command) => command.name)
            .toList(growable: false),
        help: 'Bounded pub command to run in the workspace.',
      )
      ..addMultiOption(
        'package',
        help: 'Package name. Repeat for multiple packages on add or remove.',
      )
      ..addOption(
        'max-output-chars',
        defaultsTo: '1600',
        help: 'Maximum preview size returned from stdout or stderr.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '240',
        help: 'Time budget for the pub command.',
      );
    cockpitAddWorkspaceOutputJsonOption(argParser);
  }

  final CockpitPubFunction _run;
  final StringSink _stdoutSink;

  @override
  String get name => 'pub';

  @override
  String get description =>
      'Run bounded pub commands inside the current or chosen workspace root.';

  @override
  String get summary => 'Run one bounded pub command.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use for dependency edits or dependency status checks without dumping the full pub log into context.';

  @override
  String get helpNeeds =>
      'command is required. Repeat --package only for add and remove. workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools pub --command add --package riverpod';

  @override
  String get helpWrites =>
      'A bounded summary plus truncated stdout and stderr previews when present.';

  @override
  Future<int> run() async {
    final result = await _run(
      CockpitPubRequest(
        workspaceRoot: cockpitReadWorkspaceRoot(argResults),
        command: _commandFromArgument(
          cockpitReadRequiredStringOption(argResults, 'command', usage),
        ),
        packages: cockpitReadMultiStringOption(argResults, 'package'),
        maxOutputChars: cockpitReadRequiredIntOption(
          argResults,
          'max-output-chars',
          usage,
        ),
        timeout: Duration(
          seconds: cockpitReadRequiredIntOption(
            argResults,
            'timeout-seconds',
            usage,
          ),
        ),
      ),
    );
    await cockpitWriteWorkspacePayload(
      payload: result.toJson(),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  CockpitPubCommand _commandFromArgument(String value) {
    return CockpitPubCommand.values.firstWhere(
      (command) => command.name == value,
      orElse: () =>
          throw UsageException('Unsupported pub command: $value', usage),
    );
  }
}
