import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_compare_development_probe_service.dart';
import '../cockpit_command_runner.dart';

typedef CockpitCompareDevelopmentProbeFunction
    = Future<CockpitCompareDevelopmentProbeResult> Function(
  CockpitCompareDevelopmentProbeRequest request,
);

final class CompareDevelopmentProbeCommand extends Command<int> {
  CompareDevelopmentProbeCommand({
    CockpitCompareDevelopmentProbeService? service,
    CockpitCompareDevelopmentProbeFunction? compare,
    StringSink? stdoutSink,
  })  : _compare = compare ??
            (service ?? const CockpitCompareDevelopmentProbeService()).compare,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('from-probe-json', help: 'Baseline development probe JSON.')
      ..addOption('to-probe-json', help: 'Updated development probe JSON.')
      ..addOption(
        'output-json',
        help: 'Optional file path where the diff payload should be written.',
      );
  }

  final CockpitCompareDevelopmentProbeFunction _compare;
  final StringSink _stdoutSink;

  @override
  String get name => 'compare-development-probe';

  @override
  String get description =>
      'Compare two development probes and summarize route/UI/network/runtime changes.';

  @override
  Future<int> run() async {
    final result = await _compare(
      CockpitCompareDevelopmentProbeRequest(
        fromProbePath: _readRequiredOption('from-probe-json'),
        toProbePath: _readRequiredOption('to-probe-json'),
      ),
    );
    final payload = const JsonEncoder.withIndent('  ').convert(result.toJson());
    final outputJson = argResults?['output-json'] as String?;
    if (outputJson == null || outputJson.isEmpty) {
      _stdoutSink.writeln(payload);
    } else {
      final file = File(outputJson);
      await file.parent.create(recursive: true);
      await file.writeAsString(payload);
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
