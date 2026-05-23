import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS Info.plist declares local network usage for physical-device remote control',
    () {
      final file = _resolveInfoPlist();
      final contents = file.readAsStringSync();

      expect(contents, contains('<key>NSLocalNetworkUsageDescription</key>'));
      expect(contents, contains('flutter_cockpit'));
    },
  );
}

File _resolveInfoPlist() {
  final candidates = <String>[
    'ios/Runner/Info.plist',
    'examples/cockpit_demo/ios/Runner/Info.plist',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }

  throw StateError('Unable to locate examples/cockpit_demo iOS Info.plist.');
}
