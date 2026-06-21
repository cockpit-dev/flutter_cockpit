import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../devtools/cockpit_devtools_server.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitDevtoolsWaitForShutdown = Future<void> Function();

final class DevtoolsCommand extends CockpitCliCommand {
  DevtoolsCommand({
    StringSink? stdoutSink,
    CockpitDevtoolsWaitForShutdown? waitForShutdown,
  }) : _stdoutSink = stdoutSink ?? stdout,
       _waitForShutdown = waitForShutdown ?? _defaultWaitForShutdown {
    argParser
      ..addOption(
        'history-root',
        defaultsTo: '.dart_tool/flutter_cockpit/history',
        help: 'Flutter Cockpit live history root.',
      )
      ..addOption(
        'host',
        defaultsTo: '127.0.0.1',
        help: 'Loopback host to bind.',
      )
      ..addOption(
        'port',
        defaultsTo: '0',
        help: 'Port to bind. Use 0 to choose a free port.',
      )
      ..addOption(
        'token',
        help:
            'Optional API token. If omitted, a secure per-server token is generated.',
      )
      ..addOption(
        'scope',
        defaultsTo: 'current',
        help:
            'Initial history scope for the board URL. Use current, latest, all, or a concrete session/task scope id.',
      );
  }

  final StringSink _stdoutSink;
  final CockpitDevtoolsWaitForShutdown _waitForShutdown;

  @override
  String get name => 'devtools';

  @override
  String get description =>
      'Start the Flutter Cockpit live observability dashboard.';

  @override
  String get summary => 'Serve the local live run dashboard.';

  @override
  String get category => CockpitCliCategory.server;

  @override
  String get helpWhen =>
      'Use when a human or agent needs a full-fidelity run board with state, timeline, screenshots, recordings, and bundle files.';

  @override
  String get helpNeeds =>
      'A Flutter Cockpit history root. The command intentionally stays running until interrupted.';

  @override
  String get helpExample =>
      'cockpit devtools --history-root .dart_tool/flutter_cockpit/history';

  @override
  String get helpWrites =>
      'A compact AI-readable launch record with the local dashboard URL.';

  @override
  Future<int> run() async {
    final historyRoot = _readRequiredOption('history-root');
    final host = _readRequiredOption('host');
    final address = InternetAddress.tryParse(host);
    if (address == null || !address.isLoopback) {
      throw UsageException('--host must be a loopback address.', usage);
    }
    final port = int.tryParse(_readRequiredOption('port'));
    if (port == null || port < 0 || port > 65535) {
      throw UsageException('--port must be between 0 and 65535.', usage);
    }
    final scope = _readRequiredOption('scope');
    final server = CockpitDevtoolsServer(
      historyRoot: historyRoot,
      address: address,
      port: port,
      token: argResults?['token'] as String?,
    );
    final handle = await server.start();
    final dashboardUri = handle.uri.replace(
      queryParameters: <String, String>{
        ...handle.uri.queryParameters,
        'scope': scope,
      },
    );
    await cockpitWriteJsonPayload(
      commandName: name,
      payload: <String, Object?>{
        'command': name,
        'url': dashboardUri.toString(),
        'historyRoot': historyRoot,
        'scope': scope,
        'host': host,
        'port': handle.uri.port,
        'stop': 'press Ctrl-C or terminate this process',
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    try {
      await _waitForShutdown();
    } finally {
      await handle.close();
    }
    return cockpitSuccessExitCode;
  }

  String _readRequiredOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      throw UsageException('--$name is required.', usage);
    }
    return value;
  }
}

Future<void> _defaultWaitForShutdown() async {
  final completer = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  void complete() {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  subscriptions.add(ProcessSignal.sigint.watch().listen((_) => complete()));
  if (!Platform.isWindows) {
    subscriptions.add(ProcessSignal.sigterm.watch().listen((_) => complete()));
  }
  try {
    await completer.future;
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
}
