import '../../system_control/cockpit_system_control_action_service.dart';
import '../cockpit_mcp_tool.dart';

final class CockpitRunSystemActionTool extends CockpitMcpTool {
  CockpitRunSystemActionTool({
    CockpitSystemControlActionService? service,
    CockpitSystemControlRunActionFunction? runAction,
  }) : _runAction =
           runAction ?? (service ?? CockpitSystemControlActionService()).run;

  final CockpitSystemControlRunActionFunction _runAction;

  @override
  String get name => 'run_system_action';

  @override
  String get description =>
      'Run one Native/System Control Plane action with bounded execution.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
    readOnly: false,
    destructive: true,
    idempotent: false,
    longRunning: false,
    requiresSession: false,
    producesBundleEvidence: false,
  );

  @override
  Map<String, Object?> get inputSchema => <String, Object?>{
    'type': 'object',
    'required': <String>['platform', 'action'],
    'properties': <String, Object?>{
      'platform': <String, Object?>{
        'type': 'string',
        'enum': <String>['android', 'ios', 'macos', 'windows', 'linux', 'web'],
      },
      'deviceId': <String, Object?>{'type': 'string'},
      'appId': <String, Object?>{'type': 'string'},
      'processId': <String, Object?>{'type': 'integer'},
      'wdaUrl': <String, Object?>{
        'type': 'string',
        'description':
            'iOS simulator WebDriverAgent endpoint for native UI and system dialog control.',
      },
      'action': <String, Object?>{
        'type': 'string',
        'enum': CockpitSystemControlAction.values
            .map((action) => action.name)
            .toList(growable: false),
      },
      'parameters': <String, Object?>{'type': 'object'},
      'timeoutSeconds': <String, Object?>{'type': 'integer'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _runAction(
        CockpitSystemControlActionRequest(
          platform: cockpitReadRequiredString(arguments, 'platform'),
          deviceId: cockpitReadOptionalString(arguments, 'deviceId'),
          appId: cockpitReadOptionalString(arguments, 'appId'),
          processId: cockpitReadOptionalPositiveInt(arguments, 'processId'),
          metadata: _readMetadata(arguments),
          action: CockpitSystemControlAction.fromJson(
            cockpitReadRequiredString(arguments, 'action'),
          ),
          parameters:
              cockpitReadOptionalObject(arguments, 'parameters') ??
              const <String, Object?>{},
          timeout: Duration(
            seconds:
                cockpitReadOptionalPositiveInt(arguments, 'timeoutSeconds') ??
                15,
          ),
        ),
      );
      return cockpitMcpResult(
        text: result.success
            ? 'System action completed.'
            : 'System action did not run.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  Map<String, Object?> _readMetadata(Map<String, Object?> arguments) {
    final wdaUrl = cockpitReadOptionalString(arguments, 'wdaUrl');
    if (wdaUrl == null) {
      return const <String, Object?>{};
    }
    return <String, Object?>{'wdaUrl': wdaUrl};
  }
}
