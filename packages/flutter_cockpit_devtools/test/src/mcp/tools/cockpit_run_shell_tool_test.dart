import 'package:flutter_cockpit_devtools/src/application/cockpit_run_shell_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_shell_tool.dart';
import 'package:test/test.dart';

void main() {
  test('run_shell executes host commands through the tool surface', () async {
    final tool = CockpitRunShellTool(
      runShell: (_) async => const CockpitRunShellResult(
        scope: 'host',
        command: <String>['dart', '--version'],
        exitCode: 0,
        stdout: 'Dart SDK version: 3.10.8',
        stderr: '',
        success: true,
        recommendedNextStep: 'continue',
      ),
    );

    final result = await tool.call(<String, Object?>{
      'command': <String>['dart', '--version'],
    });

    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
