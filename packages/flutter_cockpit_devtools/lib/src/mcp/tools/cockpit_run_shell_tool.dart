import '../../application/cockpit_run_shell_service.dart';
import '../../targets/cockpit_target_handle.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitRunShellToolFunction = Future<CockpitRunShellResult> Function(
  CockpitRunShellRequest request,
);

final class CockpitRunShellTool extends CockpitMcpTool {
  CockpitRunShellTool({
    CockpitRunShellService? service,
    CockpitRunShellToolFunction? runShell,
  }) : _runShell = runShell ?? (service ?? CockpitRunShellService()).run;

  final CockpitRunShellToolFunction _runShell;

  @override
  String get name => 'run_shell';

  @override
  String get description =>
      'Run a shell command against the current shell scope.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['command'],
        'properties': <String, Object?>{
          'scope': <String, Object?>{'type': 'string'},
          'command': <String, Object?>{'type': 'array'},
          'workingDirectory': <String, Object?>{'type': 'string'},
          'targetJson': <String, Object?>{'type': 'string'},
          'deviceId': <String, Object?>{'type': 'string'},
          'target': <String, Object?>{'type': 'object'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final command =
          (arguments['command'] as List<Object?>? ?? const <Object?>[])
              .map((part) => '$part')
              .toList(growable: false);
      final result = await _runShell(
        CockpitRunShellRequest(
          scope: cockpitReadOptionalString(arguments, 'scope') ?? 'host',
          command: command,
          target: _readOptionalTarget(arguments),
          targetHandlePath: cockpitReadOptionalString(arguments, 'targetJson'),
          deviceId: cockpitReadOptionalString(arguments, 'deviceId'),
          workingDirectory: cockpitReadOptionalString(
            arguments,
            'workingDirectory',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Shell command completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitTargetHandle? _readOptionalTarget(Map<String, Object?> arguments) {
    final targetJson = cockpitReadOptionalObject(arguments, 'target');
    if (targetJson == null) {
      return null;
    }
    return CockpitTargetHandle.fromJson(targetJson);
  }
}
