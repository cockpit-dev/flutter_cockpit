import 'dart:io';

import '../../application/cockpit_pub_dev_search_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitPubDevSearchFunction = Future<CockpitPubDevSearchResult>
    Function(CockpitPubDevSearchRequest request);

final class PubDevSearchCommand extends CockpitCliCommand {
  PubDevSearchCommand({
    CockpitPubDevSearchService? service,
    CockpitPubDevSearchFunction? search,
    StringSink? stdoutSink,
  })  : _search = search ?? (service ?? CockpitPubDevSearchService()).search,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'query',
        help: 'Package search query for pub.dev.',
      )
      ..addOption(
        'max-results',
        defaultsTo: '5',
        help: 'Maximum number of package summaries to return.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '20',
        help: 'Network time budget for pub.dev lookups.',
      );
  }

  final CockpitPubDevSearchFunction _search;
  final StringSink _stdoutSink;

  @override
  String get name => 'pub-dev-search';

  @override
  String get description =>
      'Search pub.dev and return bounded package quality summaries.';

  @override
  String get summary => 'Search pub.dev for candidate packages.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use before adding a dependency when you need a short package shortlist instead of browsing pub.dev manually.';

  @override
  String get helpNeeds =>
      'A short query. Lower max-results when you only need one likely package.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools pub-dev-search --query state management --max-results 3';

  @override
  String get helpWrites =>
      'Bounded package summaries with versions, scores, and optional warnings.';

  @override
  Future<int> run() async {
    final result = await _search(
      CockpitPubDevSearchRequest(
        query: cockpitReadRequiredStringOption(argResults, 'query', usage),
        maxResults: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-results',
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
