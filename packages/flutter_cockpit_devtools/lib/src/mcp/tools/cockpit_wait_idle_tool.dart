import '../../application/cockpit_wait_idle_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitWaitIdleToolFunction = Future<CockpitWaitIdleResult> Function(
  CockpitWaitIdleRequest request,
);

final class CockpitWaitIdleTool extends CockpitMcpTool {
  CockpitWaitIdleTool({
    CockpitWaitIdleService? service,
    CockpitWaitIdleToolFunction? wait,
  }) : _wait = wait ?? (service ?? CockpitWaitIdleService()).wait;

  final CockpitWaitIdleToolFunction _wait;

  @override
  String get name => 'wait_idle';

  @override
  String get description =>
      'Wait for a running app UI to settle before the next action.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
          'base_url': <String, Object?>{'type': 'string'},
          'quiet_window_ms': <String, Object?>{'type': 'integer'},
          'timeout_ms': <String, Object?>{'type': 'integer'},
          'include_network_idle': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _wait(
        CockpitWaitIdleRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
          baseUri: _readOptionalBaseUri(arguments),
          quietWindow: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'quiet_window_ms') ?? 96,
          ),
          timeout: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'timeout_ms') ?? 1600,
          ),
          includeNetworkIdle:
              cockpitReadOptionalBool(arguments, 'include_network_idle') ??
                  true,
        ),
      );
      return cockpitMcpResult(
        text: 'UI idle wait completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  Uri? _readOptionalBaseUri(Map<String, Object?> arguments) {
    final baseUrl = cockpitReadOptionalString(arguments, 'base_url');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}
