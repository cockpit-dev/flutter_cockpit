import 'dart:io';

import 'package:cockpit/src/remote/cockpit_local_session_port_resolver.dart';
import 'package:test/test.dart';

void main() {
  test('Supervisor-granted port cannot silently fall back', () async {
    var allocations = 0;
    await expectLater(
      cockpitResolveLocalSessionPort(
        platform: 'macos',
        deviceId: 'macos',
        preferredPort: 41000,
        allowFallbackAllocation: false,
        portAvailabilityChecker: (_) async => false,
        portAllocator: () async {
          allocations += 1;
          return 41001;
        },
      ),
      throwsA(isA<SocketException>()),
    );
    expect(allocations, 0);
  });

  test('legacy callers retain fallback allocation by default', () async {
    expect(
      await cockpitResolveLocalSessionPort(
        platform: 'macos',
        deviceId: 'macos',
        preferredPort: 41000,
        portAvailabilityChecker: (_) async => false,
        portAllocator: () async => 41001,
      ),
      41001,
    );
  });
}
