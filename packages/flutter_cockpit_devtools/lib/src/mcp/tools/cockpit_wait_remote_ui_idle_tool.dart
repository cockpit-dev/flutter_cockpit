import '../../application/cockpit_wait_remote_ui_idle_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitWaitRemoteUiIdleToolFunction
    = Future<CockpitWaitRemoteUiIdleResult> Function(
  CockpitWaitRemoteUiIdleRequest request,
);

final class CockpitWaitRemoteUiIdleTool extends CockpitMcpTool {
  CockpitWaitRemoteUiIdleTool({
    CockpitWaitRemoteUiIdleService? service,
    CockpitWaitRemoteUiIdleToolFunction? wait,
  }) : _wait = wait ?? (service ?? CockpitWaitRemoteUiIdleService()).wait;

  final CockpitWaitRemoteUiIdleToolFunction _wait;

  @override
  String get name => 'wait_remote_ui_idle';

  @override
  String get description =>
      'Wait for the remote UI to settle before the next interactive action.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: true,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'sessionHandle': <String, Object?>{'type': 'object'},
          'sessionHandlePath': <String, Object?>{'type': 'string'},
          'quietWindowMs': <String, Object?>{'type': 'integer'},
          'timeoutMs': <String, Object?>{'type': 'integer'},
          'includeNetworkIdle': <String, Object?>{'type': 'boolean'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _wait(
        CockpitWaitRemoteUiIdleRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
          quietWindow: Duration(
            milliseconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'quietWindowMs',
                ) ??
                96,
          ),
          timeout: Duration(
            milliseconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'timeoutMs',
                ) ??
                1600,
          ),
          includeNetworkIdle:
              cockpitReadOptionalBool(arguments, 'includeNetworkIdle') ?? true,
        ),
      );
      return cockpitMcpResult(
        text: 'Remote UI idle wait completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
