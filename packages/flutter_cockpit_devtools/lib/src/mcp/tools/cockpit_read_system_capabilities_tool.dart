import '../../system_control/cockpit_system_control_service.dart';
import '../cockpit_mcp_tool.dart';

final class CockpitReadSystemCapabilitiesTool extends CockpitMcpTool {
  CockpitReadSystemCapabilitiesTool({
    CockpitSystemControlService service = const CockpitSystemControlService(),
    CockpitSystemControlDescribeFunction? describe,
  }) : _describe = describe ?? service.describe;

  final CockpitSystemControlDescribeFunction _describe;

  @override
  String get name => 'read_system_capabilities';

  @override
  String get description =>
      'Read the Native/System Control Plane capability matrix for a platform.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
    readOnly: true,
    destructive: false,
    idempotent: true,
    longRunning: false,
    requiresSession: false,
    producesBundleEvidence: false,
  );

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['platform'],
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
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _describe(
        CockpitSystemControlDescribeRequest(
          platform: cockpitReadRequiredString(arguments, 'platform'),
          deviceId: cockpitReadOptionalString(arguments, 'deviceId'),
          appId: cockpitReadOptionalString(arguments, 'appId'),
          processId: cockpitReadOptionalPositiveInt(arguments, 'processId'),
          metadata: _readMetadata(arguments),
        ),
      );
      return cockpitMcpResult(
        text: 'System capability matrix ready.',
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
