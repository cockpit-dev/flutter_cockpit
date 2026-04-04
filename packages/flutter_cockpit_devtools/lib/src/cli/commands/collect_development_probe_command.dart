import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_collect_development_probe_service.dart';
import '../../application/cockpit_compact_json.dart';
import '../../development/cockpit_development_probe.dart';
import '../cockpit_command_runner.dart';

typedef CockpitCollectDevelopmentProbeFunction
    = Future<CockpitCollectDevelopmentProbeResult> Function(
  CockpitCollectDevelopmentProbeRequest request,
);

final class CollectDevelopmentProbeCommand extends Command<int> {
  CollectDevelopmentProbeCommand({
    CockpitCollectDevelopmentProbeService? service,
    CockpitCollectDevelopmentProbeFunction? collect,
    StringSink? stdoutSink,
  })  : _collect = collect ??
            (service ?? CockpitCollectDevelopmentProbeService()).collect,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'session-json',
        help: 'Persisted development session handle JSON to inspect.',
      )
      ..addOption(
        'profile',
        allowed: CockpitDevelopmentProbeProfile.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentProbeProfile.quick.jsonValue,
      )
      ..addOption(
        'reason',
        allowed: CockpitDevelopmentProbeReason.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentProbeReason.manual.jsonValue,
      )
      ..addOption('checkpoint')
      ..addOption(
        'output-json',
        help: 'Optional file path where the probe payload should be written.',
      );
  }

  final CockpitCollectDevelopmentProbeFunction _collect;
  final StringSink _stdoutSink;

  @override
  String get name => 'collect-development-probe';

  @override
  String get description =>
      'Collect a lightweight or rich development probe from the current app state.';

  @override
  Future<int> run() async {
    final result = await _collect(
      CockpitCollectDevelopmentProbeRequest(
        sessionHandlePath: _readRequiredOption('session-json'),
        profile: CockpitDevelopmentProbeProfile.fromJson(
          _readRequiredOption('profile'),
        ),
        reason: CockpitDevelopmentProbeReason.fromJson(
          _readRequiredOption('reason'),
        ),
        checkpoint: _readOptionalOption('checkpoint'),
      ),
    );
    final payload = cockpitPrettyJsonText(result.toJson());
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

  String? _readOptionalOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
