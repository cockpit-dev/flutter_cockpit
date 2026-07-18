import 'dart:convert';
import 'dart:typed_data';

import 'package:cockpit/src/capture/cockpit_screenshot_inspector.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitImageScreenshotInspector', () {
    const inspector = CockpitImageScreenshotInspector();

    for (final fixture
        in <({String name, Uint8List bytes, int width, int height})>[
          (name: 'opaque color', bytes: _opaquePng, width: 2, height: 1),
          (name: 'opaque black', bytes: _opaqueBlackPng, width: 1, height: 1),
        ]) {
      for (final requireVisiblePixels in <bool>[false, true]) {
        test('${fixture.name} passes when requireVisiblePixels is '
            '$requireVisiblePixels', () async {
          final inspection = await inspector.inspect(
            fixture.bytes,
            requireVisiblePixels: requireVisiblePixels,
          );

          expect(inspection.width, fixture.width);
          expect(inspection.height, fixture.height);
        });
      }
    }

    test('fully transparent PNG passes structural inspection', () async {
      final inspection = await inspector.inspect(
        _transparentPng,
        requireVisiblePixels: false,
      );

      expect(inspection.width, 1);
      expect(inspection.height, 1);
    });

    test('fully transparent PNG fails visible-pixel inspection', () async {
      await _expectValidationFailure(
        inspector.inspect(_transparentPng, requireVisiblePixels: true),
        'screenshotFullyTransparent',
      );
    });

    test('empty bytes report screenshotEmpty', () async {
      await _expectValidationFailure(
        inspector.inspect(Uint8List(0), requireVisiblePixels: false),
        'screenshotEmpty',
      );
    });

    test('malformed bytes report screenshotDecodeFailed', () async {
      await _expectValidationFailure(
        inspector.inspect(_malformedBytes, requireVisiblePixels: false),
        'screenshotDecodeFailed',
      );
    });

    test('truncated PNG reports screenshotDecodeFailed', () async {
      await _expectValidationFailure(
        inspector.inspect(_truncatedPng, requireVisiblePixels: false),
        'screenshotDecodeFailed',
      );
    });

    test('corrupt zero-width PNG reports screenshotDecodeFailed', () async {
      await _expectValidationFailure(
        inspector.inspect(_corruptZeroWidthPng, requireVisiblePixels: false),
        'screenshotDecodeFailed',
      );
    });
  });
}

Future<void> _expectValidationFailure(
  Future<CockpitScreenshotInspection> inspection,
  String code,
) {
  return expectLater(
    inspection,
    throwsA(
      isA<CockpitScreenshotValidationException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    ),
  );
}

final Uint8List _opaquePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAEUlEQVQI12O8rmb7n4GBgQEADj0CO1/m6EIAAAAASUVORK5CYII=',
);
final Uint8List _opaqueBlackPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQI12NgYGD4DwABBAEApOCsMQAAAABJRU5ErkJggg==',
);
final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIAAAUAAeImBZsAAAAASUVORK5CYII=',
);
final Uint8List _truncatedPng = Uint8List.sublistView(_opaquePng, 0, 50);
final Uint8List _corruptZeroWidthPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAAAAAABCAYAAADw16+3AAAAAElFTkSuQmCC',
);
final Uint8List _malformedBytes = Uint8List.fromList(const <int>[
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
]);
