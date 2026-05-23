import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_create_project_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitCreateProjectFunction = Future<CockpitCreateProjectResult>
    Function(CockpitCreateProjectRequest request);

final class CreateProjectCommand extends CockpitCliCommand {
  CreateProjectCommand({
    CockpitCreateProjectService? service,
    CockpitCreateProjectFunction? create,
    StringSink? stdoutSink,
  })  : _create = create ?? (service ?? CockpitCreateProjectService()).create,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddParentDirectoryOption(argParser);
    argParser
      ..addOption(
        'project-name',
        help: 'Directory name for the new project.',
      )
      ..addOption(
        'template',
        allowed: const <String>['dart-cli', 'flutter-app'],
        help: 'Project template to create.',
      )
      ..addOption(
        'organization',
        help: 'Optional organization passed through to flutter create.',
      )
      ..addMultiOption(
        'platform',
        help: 'Flutter target platform. Repeat as needed for flutter-app.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '300',
        help: 'Time budget for project creation.',
      );
  }

  final CockpitCreateProjectFunction _create;
  final StringSink _stdoutSink;

  @override
  String get name => 'create-project';

  @override
  String get description =>
      'Create a new Dart CLI or Flutter app project in the current or chosen parent directory.';

  @override
  String get summary => 'Create a new project scaffold.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use at the start of a new feature or demo workspace when AI needs a real Dart or Flutter scaffold instead of manual boilerplate.';

  @override
  String get helpNeeds =>
      'project-name and template are required. parent-directory defaults to the current directory. This creates stock Dart or Flutter scaffolds only.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools create-project --project-name demo_app --template flutter-app --platform macos';

  @override
  String get helpWrites =>
      'Project directory, create command details, and captured stdout or stderr.';

  @override
  Future<int> run() async {
    final result = await _create(
      CockpitCreateProjectRequest(
        parentDirectory: cockpitReadParentDirectory(argResults),
        projectName:
            cockpitReadRequiredStringOption(argResults, 'project-name', usage),
        template: _templateFromArgument(
          cockpitReadRequiredStringOption(argResults, 'template', usage),
        ),
        organization: cockpitReadOptionalStringOption(
          argResults,
          'organization',
        ),
        platforms: cockpitReadMultiStringOption(argResults, 'platform'),
        timeout: Duration(
          seconds: cockpitReadRequiredPositiveIntOption(
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

  CockpitProjectTemplate _templateFromArgument(String value) {
    return switch (value) {
      'dart-cli' => CockpitProjectTemplate.dartCli,
      'flutter-app' => CockpitProjectTemplate.flutterApp,
      _ => throw UsageException('Unsupported template: $value', usage),
    };
  }
}
