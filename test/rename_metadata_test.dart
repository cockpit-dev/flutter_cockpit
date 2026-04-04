import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('workspace metadata points at flutter_cockpit package paths', () {
    final rootPubspec = File('pubspec.yaml').readAsStringSync();

    expect(rootPubspec, contains('name: flutter_cockpit_workspace'));
    expect(rootPubspec, contains('workspace:'));
    expect(rootPubspec, contains('- packages/flutter_cockpit'));
    expect(rootPubspec, contains('- packages/flutter_cockpit_devtools'));
    expect(rootPubspec, contains('- examples/cockpit_demo'));
    expect(rootPubspec, contains('melos:'));
  });

  test('cockpit_demo depends on flutter_cockpit packages', () {
    final examplePubspec = File(
      'examples/cockpit_demo/pubspec.yaml',
    ).readAsStringSync();

    expect(examplePubspec, contains('flutter_cockpit: ^1.0.0'));
    expect(examplePubspec, contains('flutter_cockpit_devtools: ^1.0.0'));
    expect(examplePubspec, isNot(contains('flutter_pilot: ^1.0.0')));
    expect(examplePubspec, isNot(contains('flutter_pilot_devtools: ^1.0.0')));
  });
}
