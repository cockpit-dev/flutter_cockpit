import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_target_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchTargetToolFunction = Future<CockpitLaunchTargetResult>
    Function(
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
        'required': <String>[
          'projectDir',
          'platform',
          'deviceId',
          'sessionPort'
        ],
        'properties': <String, Object?>{
          'projectDir': <String, Object?>{'type': 'string'},
          'target': <String, Object?>{'type': 'string'},
          'platform': <String, Object?>{'type': 'string'},
          'deviceId': <String, Object?>{'type': 'string'},
          'sessionPort': <String, Object?>{'type': 'integer'},
          'targetKind': <String, Object?>{'type': 'string'},
          'mode': <String, Object?>{
            'type': 'string',
            'enum': <String>['development', 'automation'],
          },
          'launchTimeoutSeconds': <String, Object?>{'type': 'integer'},
          'targetJson': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _launch(
        CockpitLaunchTargetRequest(
          projectDir: cockpitReadRequiredString(arguments, 'projectDir'),
          target: cockpitReadOptionalString(arguments, 'target'),
          platform: cockpitReadRequiredString(arguments, 'platform'),
          deviceId: cockpitReadRequiredString(arguments, 'deviceId'),
          sessionPort: cockpitReadRequiredInt(arguments, 'sessionPort'),
          targetKind: CockpitTargetKind.fromJson(
            cockpitReadOptionalString(arguments, 'targetKind') ??
                CockpitTargetKind.flutterApp.name,
          ),
          mode: CockpitAppMode.fromJson(
            cockpitReadOptionalString(arguments, 'mode') ?? 'development',
          ),
          launchTimeout: Duration(
            seconds:
                cockpitReadOptionalInt(arguments, 'launchTimeoutSeconds') ??
                    120,
          ),
          targetHandlePath: cockpitReadOptionalString(arguments, 'targetJson'),
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
}
