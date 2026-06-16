import '../../application/cockpit_read_logs_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReadLogsToolFunction =
    Future<CockpitReadLogsResult> Function(CockpitReadLogsRequest request);

final class CockpitReadLogsTool extends CockpitMcpTool {
  CockpitReadLogsTool({
    required CockpitReadLogsService service,
    CockpitReadLogsToolFunction? read,
  }) : _read = read ?? service.read;

  final CockpitReadLogsToolFunction _read;

  @override
  String get name => 'read_logs';

  @override
  String get description =>
      'Read the latest app-centric logs for a tracked app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
      'baseUrl': <String, Object?>{'type': 'string'},
      'androidDeviceId': <String, Object?>{'type': 'string'},
      'maxLines': <String, Object?>{'type': 'integer'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final appId = cockpitReadOptionalString(arguments, 'appId');
      final appHandlePath = cockpitReadOptionalString(arguments, 'appJson');
      final baseUri = _readOptionalBaseUri(arguments);
      if ((appId == null || appId.isEmpty) &&
          (appHandlePath == null || appHandlePath.isEmpty) &&
          baseUri == null) {
        throw CockpitMcpError.invalidArguments(
          'Either appId, appJson, or baseUrl is required.',
          details: const <String, Object?>{
            'arguments': <String>['appId', 'appJson', 'baseUrl'],
          },
        );
      }
      final result = await _read(
        CockpitReadLogsRequest(
          appId: appId,
          appHandlePath: appHandlePath,
          baseUri: baseUri,
          androidDeviceId: cockpitReadOptionalString(
            arguments,
            'androidDeviceId',
          ),
          maxLines:
              cockpitReadOptionalPositiveInt(arguments, 'maxLines') ?? 200,
        ),
      );
      return cockpitMcpResult(
        text: 'App logs loaded.',
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
