import 'dart:typed_data';

import 'package:image/image.dart' as img;

final class CockpitScreenshotInspection {
  const CockpitScreenshotInspection({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

final class CockpitScreenshotValidationException implements Exception {
  const CockpitScreenshotValidationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

abstract interface class CockpitScreenshotInspector {
  Future<CockpitScreenshotInspection> inspect(
    Uint8List bytes, {
    required bool requireVisiblePixels,
  });
}

final class CockpitImageScreenshotInspector
    implements CockpitScreenshotInspector {
  const CockpitImageScreenshotInspector();

  @override
  Future<CockpitScreenshotInspection> inspect(
    Uint8List bytes, {
    required bool requireVisiblePixels,
  }) async {
    if (bytes.isEmpty) {
      throw const CockpitScreenshotValidationException(
        'screenshotEmpty',
        'Screenshot bytes are empty.',
      );
    }

    try {
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw const CockpitScreenshotValidationException(
          'screenshotDecodeFailed',
          'Screenshot bytes could not be decoded.',
        );
      }
      if (image.width <= 0 || image.height <= 0) {
        throw const CockpitScreenshotValidationException(
          'screenshotInvalidDimensions',
          'Screenshot dimensions must be positive.',
        );
      }
      if (requireVisiblePixels && !image.any((pixel) => pixel.a != 0)) {
        throw const CockpitScreenshotValidationException(
          'screenshotFullyTransparent',
          'Screenshot contains no visible pixels.',
        );
      }

      return CockpitScreenshotInspection(
        width: image.width,
        height: image.height,
      );
    } on CockpitScreenshotValidationException {
      rethrow;
    } on Object catch (error) {
      throw CockpitScreenshotValidationException(
        'screenshotDecodeFailed',
        'Screenshot bytes could not be decoded: $error',
      );
    }
  }
}
