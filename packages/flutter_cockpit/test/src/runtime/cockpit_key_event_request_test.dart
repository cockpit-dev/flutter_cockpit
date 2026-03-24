import 'package:flutter/services.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses logical and physical keys from json-like input', () {
    final request = CockpitKeyEventRequest.fromJson(const <String, Object?>{
      'logicalKey': 'enter',
      'physicalKey': 'enter',
      'character': '\n',
    });

    expect(request.logicalKey, LogicalKeyboardKey.enter);
    expect(request.physicalKey, PhysicalKeyboardKey.enter);
    expect(request.character, '\n');
  });

  test('accepts numeric key ids for logical key lookup', () {
    final request = CockpitKeyEventRequest.fromJson(<String, Object?>{
      'logicalKey': LogicalKeyboardKey.tab.keyId,
    });

    expect(request.logicalKey, LogicalKeyboardKey.tab);
    expect(request.physicalKey, isNotNull);
  });
}
