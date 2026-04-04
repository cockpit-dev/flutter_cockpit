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
          'appId': <String, Object?>{'type': 'string'},
          'appJson': <String, Object?>{'type': 'string'},
          'baseUrl': <String, Object?>{'type': 'string'},
          'quietWindowMs': <String, Object?>{'type': 'integer'},
          'timeoutMs': <String, Object?>{'type': 'integer'},
          'includeNetworkIdle': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _wait(
        CockpitWaitIdleRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
          baseUri: _readOptionalBaseUri(arguments),
          quietWindow: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'quietWindowMs') ?? 96,
          ),
          timeout: Duration(
            milliseconds:
                cockpitReadOptionalInt(arguments, 'timeoutMs') ?? 1600,
          ),
          includeNetworkIdle:
              cockpitReadOptionalBool(arguments, 'includeNetworkIdle') ?? true,
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
    final baseUrl = cockpitReadOptionalString(arguments, 'baseUrl');
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    return Uri.parse(baseUrl);
  }
}
