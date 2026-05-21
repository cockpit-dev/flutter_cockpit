import 'dart:io';

import 'package:flutter_cockpit_devtools/src/platform/windows/cockpit_windows_window_target.dart';
import 'package:test/test.dart';

void main() {
  test('passes process id to the Windows window resolver script', () async {
    late List<String> invocation;

    final target = await cockpitResolveWindowsWindowTarget(
      appId: 'cockpit_demo',
      processId: 4101,
      powershellExecutable: 'powershell',
      processRunner: (executable, arguments) async {
        expect(executable, 'powershell');
        invocation = List<String>.from(arguments);
        return ProcessResult(
          0,
          0,
          '{"title":"Cockpit Demo","handle":4242,"left":120,"top":48,"width":900,"height":640}',
          '',
        );
      },
      timeout: const Duration(seconds: 1),
      activationSettleDelay: const Duration(milliseconds: 250),
    );

    expect(invocation[0], '-NoProfile');
    expect(invocation[1], '-NonInteractive');
    expect(invocation[2], '-Command');
    expect(invocation[4], 'cockpit_demo');
    expect(invocation[5], '4101');
    expect(invocation[6], '250');
    expect(target.title, 'Cockpit Demo');
    expect(target.handle, 4242);
    expect(target.left, 120);
    expect(target.top, 48);
    expect(target.width, 900);
    expect(target.height, 640);
  });
}
