import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_collect_development_probe_service.dart';
import '../../development/cockpit_development_probe.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitCollectDevelopmentProbeFunction =
    Future<CockpitCollectDevelopmentProbeResult> Function(
      CockpitCollectDevelopmentProbeRequest request,
    );

final class CollectDevelopmentProbeCommand extends CockpitCliCommand {
  CollectDevelopmentProbeCommand({
    CockpitCollectDevelopmentProbeService? service,
    CockpitCollectDevelopmentProbeFunction? collect,
    StringSink? stdoutSink,
  }) : _collect =
           collect ??
           (service ?? CockpitCollectDevelopmentProbeService()).collect,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('session-json', help: cockpitDevelopmentSessionJsonOptionHelp)
      ..addOption(
        'profile',
        help: 'Probe detail level.',
        allowed: CockpitDevelopmentProbeProfile.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentProbeProfile.quick.jsonValue,
      )
      ..addOption(
        'reason',
        help: 'Why the probe is being collected.',
        allowed: CockpitDevelopmentProbeReason.values
            .map((value) => value.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitDevelopmentProbeReason.manual.jsonValue,
      )
      ..addOption(
        'checkpoint',
        help: 'Short caller-defined checkpoint label for the probe.',
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
  String get summary => 'Collect development probe.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use after launch or reload to capture the smallest state needed for the next repair decision.';

  @override
  String get helpNeeds =>
      'A development session handle from --session-json or the default latest development session handle, plus optional bounded probe profile.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools collect-development-probe --checkpoint after_reload';

  @override
  String get helpWrites =>
      'Development probe JSON with snapshot summary, warnings, and effective snapshot options.';

  @override
  Future<int> run() async {
    final result = await _collect(
      CockpitCollectDevelopmentProbeRequest(
        sessionHandlePath: cockpitRequireResolvedDevelopmentSessionHandlePath(
          argResults,
          usage,
        ),
        profile: CockpitDevelopmentProbeProfile.fromJson(
          _readRequiredOption('profile'),
        ),
        reason: CockpitDevelopmentProbeReason.fromJson(
          _readRequiredOption('reason'),
        ),
        checkpoint: _readOptionalOption('checkpoint'),
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

  String? _readOptionalOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
