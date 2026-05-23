import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_hot_reload_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitHotReloadFunction =
    Future<CockpitHotReloadResult> Function(CockpitHotReloadRequest request);

final class HotReloadCommand extends CockpitCliCommand {
  HotReloadCommand({
    CockpitHotReloadService? service,
    CockpitHotReloadFunction? reload,
    StringSink? stdoutSink,
  }) : _reload = reload ?? (service ?? CockpitHotReloadService()).reload,
       _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption('app-json', help: cockpitAppJsonOptionHelp);
  }

  final CockpitHotReloadFunction _reload;
  final StringSink _stdoutSink;

  @override
  String get name => 'hot-reload';

  @override
  String get description => 'Trigger hot reload for a development app.';

  @override
  String get summary => 'Apply source changes without restart.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Refresh code after editing while keeping as much app state as Flutter can preserve.';

  @override
  String get helpNeeds =>
      'A development app handle from launch-app. In the same workspace, the default latest_app.json handle is usually enough.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools hot-reload --app-json /tmp/app.json --stdout-format json | jq \'{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}\'';

  @override
  String get helpWrites =>
      'Updated app metadata and reload status for the running development session.';

  @override
  Future<int> run() async {
    final appJson = cockpitRequireResolvedAppHandlePath(argResults, usage);
    final result = await _reload(
      CockpitHotReloadRequest(appHandlePath: appJson),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
