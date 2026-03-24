import '../../application/cockpit_run_remote_control_script_service.dart';
import '../../cli/cockpit_control_script.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunRemoteControlScriptFunction
    = Future<CockpitRunRemoteControlScriptResult> Function(
  CockpitRunRemoteControlScriptRequest request,
);

final class CockpitRunRemoteControlScriptTool extends CockpitMcpTool {
  CockpitRunRemoteControlScriptTool({
    CockpitRunRemoteControlScriptService? service,
    CockpitRunRemoteControlScriptFunction? run,
  }) : _run = run ?? (service ?? CockpitRunRemoteControlScriptService()).run;

  final CockpitRunRemoteControlScriptFunction _run;

  @override
  String get name => 'run_remote_control_script';

  @override
  String get description =>
      'Execute a structured flutter_cockpit control script and write a task-run bundle.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['script', 'output_root'],
        'properties': <String, Object?>{
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
          'script': <String, Object?>{'type': 'object'},
          'output_root': <String, Object?>{'type': 'string'},
          'persist_script_path': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final scriptJson = cockpitReadRequiredObject(arguments, 'script');
      late final CockpitControlScript script;
      try {
        script = CockpitControlScript.fromJson(scriptJson);
      } on FormatException catch (error) {
        throw CockpitMcpError.invalidArguments(
          error.message,
          details: <String, Object?>{
            'serviceCode': 'script_invalid',
            'argument': 'script',
          },
        );
      }

      final result = await _run(
        CockpitRunRemoteControlScriptRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
          script: script,
          outputRoot: cockpitReadRequiredString(arguments, 'output_root'),
          persistScriptPath: cockpitReadOptionalString(
            arguments,
            'persist_script_path',
          ),
        ),
      );

      return cockpitMcpResult(
        text: 'Remote control script executed and bundle written.',
        structuredContent: <String, Object?>{
          'bundle_dir': result.bundleDir.path,
          'manifest': result.manifest.toJson(),
          'handoff': result.handoff,
          'delivery': result.delivery,
          'artifact_paths': result.artifactPaths.toJson(),
          'session_handle': result.sessionHandle?.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
