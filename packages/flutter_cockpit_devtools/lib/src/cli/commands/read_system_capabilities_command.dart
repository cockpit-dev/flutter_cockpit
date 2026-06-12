import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_app_handle.dart';
import '../../system_control/cockpit_system_control_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';
import '../cockpit_system_control_cli_support.dart';

final class ReadSystemCapabilitiesCommand extends CockpitCliCommand {
  ReadSystemCapabilitiesCommand({
    CockpitSystemControlService? service,
    CockpitSystemControlDescribeFunction? describe,
    StringSink? stdoutSink,
  }) : _describe =
           describe ?? (service ?? CockpitSystemControlService()).describe,
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
            'Platform app id or bundle id for app/window-scoped capabilities; required for macOS host screenshots and recordings.',
      )
      ..addOption(
        'process-id',
        help:
            'Windows/Linux process id for window-scoped capabilities when app id is ambiguous.',
      )
      ..addOption('app-json', help: cockpitAppJsonOptionHelp)
      ..addOption(
        'wda-url',
        help:
            'iOS simulator WebDriverAgent endpoint for native UI and system dialog control. Defaults to FLUTTER_COCKPIT_IOS_WDA_URL or probes http://127.0.0.1:8100.',
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
    final app = cockpitReadSystemControlAppHandle(
      argResults: argResults,
      usage: usage,
    );
    final platform =
        argResults?['platform'] as String? ??
        app?.platform ??
        cockpitReadLaunchPlatform(argResults, usage);
    final appId = await _resolveAppId(app, platform);
    final result = await _describe(
      CockpitSystemControlDescribeRequest(
        platform: platform,
        deviceId: argResults?['device-id'] as String? ?? app?.deviceId,
        appId: appId,
        processId:
            cockpitReadOptionalPositiveInt(argResults, 'process-id', usage) ??
            app?.processId,
        metadata: _readMetadata(),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  Future<String?> _resolveAppId(CockpitAppHandle? app, String platform) async {
    return cockpitResolveSystemControlAppId(
      app: app,
      platform: platform,
      explicitAppId: argResults?['app-id'] as String?,
    );
  }

  Map<String, Object?> _readMetadata() {
    final wdaUrl =
        argResults?['wda-url'] as String? ??
        Platform.environment['FLUTTER_COCKPIT_IOS_WDA_URL'];
    if (wdaUrl == null || wdaUrl.trim().isEmpty) {
      return const <String, Object?>{};
    }
    return <String, Object?>{'wdaUrl': wdaUrl.trim()};
  }
}
