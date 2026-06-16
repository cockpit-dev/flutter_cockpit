import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  test(
    'reuses an existing forward when the device port is already mapped',
    () async {
      final invocations = <List<String>>[];
      final forwarder = CockpitAndroidPortForwarder(
        processRunner: (executable, arguments) async {
          invocations.add(arguments);
          if (arguments.last == '--list') {
            return ProcessResult(
              0,
              0,
              'emulator-5554 tcp:48000 tcp:47331\n',
              '',
            );
          }
          throw StateError('forward should not be called when mapping exists');
        },
      );

      final hostPort = await forwarder.ensureForwarded(
        deviceId: 'emulator-5554',
        preferredHostPort: 47331,
        devicePort: 47331,
      );

      expect(hostPort, 48000);
      expect(invocations, <List<String>>[
        <String>['-s', 'emulator-5554', 'forward', '--list'],
      ]);
    },
  );

  test(
    'allocates a fallback host port when the preferred port is unavailable',
    () async {
      final invocations = <List<String>>[];
      final forwarder = CockpitAndroidPortForwarder(
        processRunner: (executable, arguments) async {
          invocations.add(arguments);
          if (arguments.last == '--list') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 0, '', '');
        },
        hostPortAllocator: () async => 48001,
        hostPortAvailabilityChecker: (port) async => port != 47331,
      );

      final hostPort = await forwarder.ensureForwarded(
        deviceId: 'emulator-5554',
        preferredHostPort: 47331,
        devicePort: 47331,
      );

      expect(hostPort, 48001);
      expect(invocations, <List<String>>[
        <String>['-s', 'emulator-5554', 'forward', '--list'],
        <String>['-s', 'emulator-5554', 'forward', 'tcp:48001', 'tcp:47331'],
      ]);
    },
  );
}
