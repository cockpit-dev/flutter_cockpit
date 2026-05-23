import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_compare_development_probe_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitCompareDevelopmentProbeFunction
    = Future<CockpitCompareDevelopmentProbeResult> Function(
  CockpitCompareDevelopmentProbeRequest request,
);

final class CompareDevelopmentProbeCommand extends CockpitCliCommand {
  CompareDevelopmentProbeCommand({
    CockpitCompareDevelopmentProbeService? service,
    CockpitCompareDevelopmentProbeFunction? compare,
    StringSink? stdoutSink,
  })  : _compare = compare ??
            (service ?? const CockpitCompareDevelopmentProbeService()).compare,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('from-probe-json', help: 'Baseline development probe JSON.')
      ..addOption('to-probe-json', help: 'Updated development probe JSON.');
  }

  final CockpitCompareDevelopmentProbeFunction _compare;
  final StringSink _stdoutSink;

  @override
  String get name => 'compare-development-probe';

  @override
  String get description =>
      'Compare two development probes and summarize route/UI/network/runtime changes.';

  @override
  String get summary => 'Compare probes.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use after a reload or action to compare compact before/after app state.';

  @override
  String get helpNeeds =>
      'Two probe JSON files collected from the same task loop.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools compare-development-probe --from-probe-json /tmp/before.json --to-probe-json /tmp/after.json';

  @override
  String get helpWrites =>
      'A bounded delta payload covering route, UI, network, runtime, and rebuild changes.';

  @override
  Future<int> run() async {
    final result = await _compare(
      CockpitCompareDevelopmentProbeRequest(
        fromProbePath: _readRequiredOption('from-probe-json'),
        toProbePath: _readRequiredOption('to-probe-json'),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: result.toJson(),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
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
