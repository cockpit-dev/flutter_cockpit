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
      if (_hasInvalidPngDimensions(bytes)) {
        throw const CockpitScreenshotValidationException(
          'screenshotInvalidDimensions',
          'Screenshot dimensions must be positive.',
        );
      }
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

bool _hasInvalidPngDimensions(Uint8List bytes) {
  const pngHeader = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) {
    return false;
  }
  for (var index = 0; index < pngHeader.length; index += 1) {
    if (bytes[index] != pngHeader[index]) {
      return false;
    }
  }
  if (bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    return false;
  }

  final dimensions = ByteData.sublistView(bytes, 16, 24);
  return dimensions.getUint32(0) == 0 || dimensions.getUint32(4) == 0;
}
