import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production iOS Info.plist excludes Cockpit local network metadata', () {
    final file = _resolveInfoPlist();
    final contents = file.readAsStringSync();

    expect(
      contents,
      isNot(contains('<key>NSLocalNetworkUsageDescription</key>')),
    );
    expect(contents, isNot(contains('<key>NSAllowsLocalNetworking</key>')));
    expect(contents, isNot(contains('flutter_cockpit')));
  });
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
