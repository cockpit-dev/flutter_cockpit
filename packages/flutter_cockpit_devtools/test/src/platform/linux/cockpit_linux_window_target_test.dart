import 'dart:io';

import 'package:flutter_cockpit_devtools/src/platform/linux/cockpit_linux_window_target.dart';
import 'package:test/test.dart';

void main() {
  test('resolves a Linux window by exact process id when provided', () async {
    final invocations = <String>[];

    final target = await cockpitResolveLinuxWindowTarget(
      appId: 'cockpit_demo',
      processId: 5102,
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        if (executable == 'wmctrl') {
          return ProcessResult(
            0,
            0,
            '''
0x02c00007 0 5101 0 0 400 300 cockpit_demo.Cockpit-demo host First Window
0x02c00008 0 5102 120 48 900 640 cockpit_demo.Cockpit-demo host Second Window
''',
            '',
          );
        }
        fail('Unexpected executable: $executable');
      },
      timeout: const Duration(seconds: 1),
    );

    expect(target.windowId, '0x02c00008');
    expect(target.left, 120);
    expect(target.top, 48);
    expect(target.width, 900);
    expect(target.height, 640);
    expect(invocations, <String>['wmctrl -lpGx']);
  });

  test('falls back to Linux window metadata when no process id is available',
      () async {
    final target = await cockpitResolveLinuxWindowTarget(
      appId: 'cockpit_demo',
      processId: null,
      processRunner: (executable, arguments) async {
        if (executable == 'pgrep') {
          return ProcessResult(0, 1, '', '');
        }
        if (executable == 'wmctrl') {
          return ProcessResult(
            0,
            0,
            '''
0x02c00008 0 5102 120 48 900 640 cockpit_demo.Cockpit-demo host Cockpit Demo
''',
            '',
          );
        }
        fail('Unexpected executable: $executable');
      },
      timeout: const Duration(seconds: 1),
    );

    expect(target.windowId, '0x02c00008');
    expect(target.width, 900);
    expect(target.height, 640);
  });
}
