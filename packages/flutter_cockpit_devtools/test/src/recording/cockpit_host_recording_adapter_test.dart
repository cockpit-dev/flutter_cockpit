import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Unix liveness treats ps timeout after kill success as still alive',
    () async {
      final calls = <String>[];

      final isLive = await cockpitDefaultPidLivenessChecker(
        1234,
        runProcess: (executable, arguments, {required timeout}) async {
          calls.add('$executable ${arguments.join(' ')}');
          if (executable == '/bin/kill') {
            return ProcessResult(0, 0, '', '');
          }
          if (executable == '/bin/ps') {
            throw TimeoutException('/bin/ps timed out');
          }
          throw ProcessException(executable, arguments, 'unexpected command');
        },
      );

      expect(isLive, isTrue);
      expect(calls, <String>['/bin/kill -0 1234', '/bin/ps -o stat= -p 1234']);
    },
    skip: Platform.isWindows ? 'Unix process probing only.' : false,
  );
}
