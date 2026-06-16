import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/platform/windows/cockpit_windows_window_target.dart';
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
    expect(invocation[2], '-EncodedCommand');
    final script = _decodeWindowsPowerShellEncodedCommand(invocation[3]);
    expect(script, contains(r'& {'));
    expect(script, contains(r'$appId = $args[0]'));
    expect(script, contains("} 'cockpit_demo' '4101' '250'"));
    expect(script, isNot(contains(r'$appId:')));
    expect(target.title, 'Cockpit Demo');
    expect(target.handle, 4242);
    expect(target.left, 120);
    expect(target.top, 48);
    expect(target.width, 900);
    expect(target.height, 640);
  });
}

String _decodeWindowsPowerShellEncodedCommand(String encoded) {
  final bytes = base64.decode(encoded);
  return String.fromCharCodes(<int>[
    for (var index = 0; index < bytes.length; index += 2)
      bytes[index] | (bytes[index + 1] << 8),
  ]);
}
