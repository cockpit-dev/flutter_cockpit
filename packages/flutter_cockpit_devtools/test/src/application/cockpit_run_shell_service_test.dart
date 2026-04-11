import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_run_shell_service.dart';
import 'package:test/test.dart';

void main() {
  test('run shell executes host commands and returns structured output',
      () async {
    final service = CockpitRunShellService(
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        return ProcessResult(0, 0, 'Dart SDK version: 3.10.8', '');
      },
    );

    final result = await service.run(
      const CockpitRunShellRequest(
        command: <String>['dart', '--version'],
      ),
    );

    expect(result.success, isTrue);
    expect(result.scope, 'host');
    expect(result.command, <String>['dart', '--version']);
    expect(result.recommendedNextStep, 'continue');
  });
}
