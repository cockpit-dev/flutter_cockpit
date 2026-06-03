import 'dart:convert';
import 'dart:io';

import '../../system_control/cockpit_system_control_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class ReadSystemCapabilitiesCommand extends CockpitCliCommand {
  ReadSystemCapabilitiesCommand({
    CockpitSystemControlService? service,
    CockpitSystemControlDescribeFunction? describe,
    StringSink? stdoutSink,
  }) : _describe =
           describe ??
           (service ?? const CockpitSystemControlService()).describe,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'platform',
        allowed: const <String>[
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
          'web',
        ],
        help:
            'Target platform. If omitted, the host platform is used for desktop scopes.',
      )
      ..addOption(
        'device-id',
        help:
            'Device, simulator, emulator, browser, or desktop target id when platform control needs one.',
      )
      ..addOption(
        'app-id',
        help:
            'Platform app id or bundle id for window-scoped desktop evidence capabilities.',
      )
      ..addOption(
        'process-id',
        help:
            'Process id for window-scoped desktop evidence capabilities when app id is ambiguous.',
      );
    cockpitAddOutputArgs(argParser);
  }

  final CockpitSystemControlDescribeFunction _describe;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-system-capabilities';

  @override
  String get description =>
      'Read the Native/System Control Plane capability matrix for a platform.';

  @override
  String get summary => 'Show system control capabilities and fallbacks.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use before native UI, system dialogs, host windows, simulator/emulator, or non-Flutter control when Flutter semantics cannot answer the task.';

  @override
  String get helpNeeds =>
      'A platform from list-targets, launch-target metadata, or an explicit user target. Device id is required only for platform actions that need a concrete device.';

  @override
  String get helpShape =>
      'Default stdout is a compact AI-readable matrix with available, blocked, and unsupported actions. Use --stdout-format json for jq pipelines.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-system-capabilities --platform android --device-id emulator-5554';

  @override
  String get helpWrites =>
      'A capability matrix with platform adapter, preferred plane, fallback order, action availability, strategies, requirements, and limitations.';

  @override
  Future<int> run() async {
    final platform =
        argResults?['platform'] as String? ??
        cockpitReadLaunchPlatform(argResults, usage);
    final result = await _describe(
      CockpitSystemControlDescribeRequest(
        platform: platform,
        deviceId: argResults?['device-id'] as String?,
        appId: argResults?['app-id'] as String?,
        processId: cockpitReadOptionalPositiveInt(
          argResults,
          'process-id',
          usage,
        ),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
