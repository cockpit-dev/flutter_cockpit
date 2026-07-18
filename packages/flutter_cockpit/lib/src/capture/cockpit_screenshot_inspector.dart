import 'dart:typed_data';
import 'dart:ui' as ui;

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

final class CockpitDartUiScreenshotInspector
    implements CockpitScreenshotInspector {
  const CockpitDartUiScreenshotInspector();

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

    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image = frame.image;

      final width = image.width;
      final height = image.height;
      if (width <= 0 || height <= 0) {
        throw const CockpitScreenshotValidationException(
          'screenshotInvalidDimensions',
          'Screenshot dimensions must be positive.',
        );
      }

      if (requireVisiblePixels) {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (rgba == null) {
          throw const CockpitScreenshotValidationException(
            'screenshotDecodeFailed',
            'Screenshot pixels could not be decoded.',
          );
        }

        var hasVisiblePixel = false;
        for (
          var alphaIndex = 3;
          alphaIndex < rgba.lengthInBytes;
          alphaIndex += 4
        ) {
          if (rgba.getUint8(alphaIndex) != 0) {
            hasVisiblePixel = true;
            break;
          }
        }
        if (!hasVisiblePixel) {
          throw const CockpitScreenshotValidationException(
            'screenshotFullyTransparent',
            'Screenshot contains no visible pixels.',
          );
        }
      }

      return CockpitScreenshotInspection(width: width, height: height);
    } on CockpitScreenshotValidationException {
      rethrow;
    } on Object catch (error) {
      throw CockpitScreenshotValidationException(
        'screenshotDecodeFailed',
        'Screenshot bytes could not be decoded: $error',
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }
}
