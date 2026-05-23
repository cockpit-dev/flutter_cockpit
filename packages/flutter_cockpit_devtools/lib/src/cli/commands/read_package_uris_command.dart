import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_read_package_uris_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitReadPackageUrisFunction =
    Future<CockpitReadPackageUrisResult> Function(
      CockpitReadPackageUrisRequest request,
    );

final class ReadPackageUrisCommand extends CockpitCliCommand {
  ReadPackageUrisCommand({
    CockpitReadPackageUrisService? service,
    CockpitReadPackageUrisFunction? read,
    StringSink? stdoutSink,
  }) : _read = read ?? (service ?? CockpitReadPackageUrisService()).read,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser
      ..addMultiOption(
        'uri',
        help: 'package: or package-root: URI to resolve. Repeat as needed.',
      )
      ..addOption(
        'max-preview-chars',
        defaultsTo: '1200',
        help: 'Maximum preview size returned for text files.',
      )
      ..addOption(
        'max-entries',
        defaultsTo: '40',
        help: 'Maximum number of directory entries returned for package paths.',
      )
      ..addFlag(
        'include-full-text',
        defaultsTo: false,
        help:
            'Include full text when the file is textual and already fits inside the preview budget.',
      );
  }

  final CockpitReadPackageUrisFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-package-uris';

  @override
  String get description =>
      'Resolve package: and package-root: URIs from the workspace package_config.';

  @override
  String get summary => 'Read resolved dependency source paths.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after pub get when AI needs a dependency file or package-root directory without searching the whole pub cache.';

  @override
  String get helpNeeds =>
      'At least one --uri. workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-package-uris --uri package:flutter/material.dart';

  @override
  String get helpWrites =>
      'Resolved paths plus a bounded preview or directory listing for each requested URI.';

  @override
  Future<int> run() async {
    final uris = cockpitReadMultiStringOption(argResults, 'uri');
    if (uris.isEmpty) {
      throw UsageException('--uri is required at least once.', usage);
    }
    final workspaceRoot = cockpitReadWorkspaceRoot(argResults);
    final results = <Map<String, Object?>>[];
    for (final uri in uris) {
      final result = await _read(
        CockpitReadPackageUrisRequest(
          workspaceRoot: workspaceRoot,
          uri: uri,
          maxPreviewChars: cockpitReadRequiredPositiveIntOption(
            argResults,
            'max-preview-chars',
            usage,
          ),
          maxEntries: cockpitReadRequiredPositiveIntOption(
            argResults,
            'max-entries',
            usage,
          ),
          includeFullText: (argResults?['include-full-text'] as bool?) ?? false,
        ),
      );
      results.add(<String, Object?>{'uri': uri, ...result.toJson()});
    }
    await cockpitWriteWorkspacePayload(
      payload: <String, Object?>{
        'workspaceRoot': workspaceRoot,
        'results': results,
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
