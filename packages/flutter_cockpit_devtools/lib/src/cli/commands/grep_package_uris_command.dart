import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_grep_package_uris_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitGrepPackageUrisFunction = Future<CockpitGrepPackageUrisResult>
    Function(
  CockpitGrepPackageUrisRequest request,
);

final class GrepPackageUrisCommand extends CockpitCliCommand {
  GrepPackageUrisCommand({
    CockpitGrepPackageUrisService? service,
    CockpitGrepPackageUrisFunction? grep,
    StringSink? stdoutSink,
  })  : _grep = grep ?? (service ?? CockpitGrepPackageUrisService()).grep,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser
      ..addMultiOption(
        'package',
        help: 'Dependency package name to search. Repeat as needed.',
      )
      ..addOption(
        'query',
        help: 'Literal text or regular expression to search for.',
      )
      ..addOption(
        'search-dir',
        defaultsTo: 'lib',
        help:
            'Directory or file path relative to the dependency package root. Use an empty value to search the whole package root.',
      )
      ..addFlag(
        'use-regex',
        defaultsTo: false,
        help: 'Interpret --query as a regular expression.',
      )
      ..addFlag(
        'case-sensitive',
        defaultsTo: false,
        help: 'Match case exactly instead of using case-insensitive search.',
      )
      ..addOption(
        'max-matches',
        defaultsTo: '60',
        help: 'Maximum total number of matches returned across all packages.',
      )
      ..addOption(
        'max-matches-per-file',
        defaultsTo: '5',
        help: 'Maximum number of matches returned for any single file.',
      )
      ..addOption(
        'max-line-length',
        defaultsTo: '240',
        help: 'Maximum preview length kept for each matching line.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '20',
        help: 'Maximum search time before the command fails.',
      );
  }

  final CockpitGrepPackageUrisFunction _grep;
  final StringSink _stdoutSink;

  @override
  String get name => 'grep-package-uris';

  @override
  String get description =>
      'Search bounded matches inside resolved dependency packages.';

  @override
  String get summary => 'Search inside resolved dependency packages.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after pub get when AI needs symbol or string hits across dependency packages without opening the whole pub cache.';

  @override
  String get helpNeeds =>
      'At least one --package and one --query. workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools grep-package-uris --package flutter --query ThemeData --stdout-format json | jq -r \'.packages[0].files[0].packageUri\'';

  @override
  String get helpWrites =>
      'Bounded structured matches with package-root and package URIs that AI can feed into read-package-uris.';

  @override
  Future<int> run() async {
    final packageNames = cockpitReadMultiStringOption(argResults, 'package');
    if (packageNames.isEmpty) {
      throw UsageException('--package is required at least once.', usage);
    }
    final query = cockpitReadRequiredStringOption(argResults, 'query', usage);
    final result = await _grep(
      CockpitGrepPackageUrisRequest(
        workspaceRoot: cockpitReadWorkspaceRoot(argResults),
        packageNames: packageNames,
        query: query,
        searchDir: (argResults?['search-dir'] as String?) ?? 'lib',
        useRegex: (argResults?['use-regex'] as bool?) ?? false,
        caseSensitive: (argResults?['case-sensitive'] as bool?) ?? false,
        maxMatches: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-matches',
          usage,
        ),
        maxMatchesPerFile: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-matches-per-file',
          usage,
        ),
        maxLineLength: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-line-length',
          usage,
        ),
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
}
