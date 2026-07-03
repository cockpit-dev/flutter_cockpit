import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_target_service.dart';
import '../cockpit_flutter_launch_configuration_mcp.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchTargetToolFunction =
    Future<CockpitLaunchTargetResult> Function(
      CockpitLaunchTargetRequest request,
    );

final class CockpitLaunchTargetTool extends CockpitMcpTool {
  CockpitLaunchTargetTool({
    CockpitLaunchTargetService? service,
    CockpitLaunchTargetToolFunction? launch,
  }) : _launch = launch ?? (service ?? CockpitLaunchTargetService()).launch;

  final CockpitLaunchTargetToolFunction _launch;

  @override
  String get name => 'launch_target';

  @override
  String get description =>
      'Launch a target-first session and return a normalized target handle.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['projectDir', 'platform', 'sessionPort'],
    'properties': <String, Object?>{
      'projectDir': <String, Object?>{
        'type': 'string',
        'description': 'Flutter project directory to launch from.',
      },
      'target': <String, Object?>{
        'type': 'string',
        'description': 'Optional Dart entrypoint.',
      },
      'flavor': <String, Object?>{
        'type': 'string',
        'description': 'Optional Flutter flavor or Xcode scheme.',
      },
      'platform': <String, Object?>{
        'type': 'string',
        'description': 'android, ios, macos, windows, linux, or web.',
      },
      'deviceId': <String, Object?>{
        'type': 'string',
        'description':
            'Required for android, ios, and web. Desktop '
            'target-first launches default to the platform name.',
      },
      'sessionPort': <String, Object?>{
        'type': 'integer',
        'description': 'Cockpit port or browser bridge port to use.',
      },
      'targetKind': <String, Object?>{'type': 'string'},
      'mode': <String, Object?>{
        'type': 'string',
        'enum': <String>['development', 'automation'],
      },
      'launchTimeoutSeconds': <String, Object?>{'type': 'integer'},
      'targetJson': <String, Object?>{'type': 'string'},
      ...cockpitFlutterLaunchConfigurationMcpProperties,
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final platform = cockpitReadRequiredString(arguments, 'platform');
      final result = await _launch(
        CockpitLaunchTargetRequest(
          projectDir: cockpitReadRequiredString(arguments, 'projectDir'),
          target: cockpitReadOptionalString(arguments, 'target'),
          flavor: cockpitReadOptionalString(arguments, 'flavor'),
          platform: platform,
          deviceId: _readDeviceId(arguments, platform),
          sessionPort: cockpitReadRequiredPort(arguments, 'sessionPort'),
          targetKind: CockpitTargetKind.fromJson(
            cockpitReadOptionalString(arguments, 'targetKind') ??
                CockpitTargetKind.flutterApp.name,
          ),
          mode: CockpitAppMode.fromJson(
            cockpitReadOptionalString(arguments, 'mode') ?? 'development',
          ),
          launchTimeout: Duration(
            seconds:
                cockpitReadOptionalPositiveInt(
                  arguments,
                  'launchTimeoutSeconds',
                ) ??
                120,
          ),
          targetHandlePath: cockpitReadOptionalString(arguments, 'targetJson'),
          launchConfiguration: cockpitReadMcpFlutterLaunchConfiguration(
            arguments,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Target launched and ready.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  String _readDeviceId(Map<String, Object?> arguments, String platform) {
    final explicit = cockpitReadOptionalString(arguments, 'deviceId');
    if (explicit != null) {
      return explicit;
    }
    return switch (platform) {
      'macos' => 'macos',
      'windows' => 'windows',
      'linux' => 'linux',
      _ => throw CockpitMcpError.invalidArguments(
        'deviceId is required for this platform.',
        details: <String, Object?>{
          'argument': 'deviceId',
          'platform': platform,
        },
      ),
    };
  }
}
