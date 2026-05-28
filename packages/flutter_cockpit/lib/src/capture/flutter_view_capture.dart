import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../control/cockpit_screenshot_request.dart';
import '../model/cockpit_artifact_ref.dart';
import '../runtime/cockpit_snapshot.dart';
import 'cockpit_captured_screenshot.dart';
import 'cockpit_capture_paths.dart';

final class FlutterViewCapture {
  const FlutterViewCapture();

  Future<CockpitCapturedScreenshot> capture({
    required GlobalKey repaintBoundaryKey,
    required CockpitScreenshotRequest request,
    CockpitSnapshot? snapshot,
    double pixelRatio = 1.0,
  }) async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await WidgetsBinding.instance.endOfFrame;
    }

    final context = repaintBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('CockpitSurface capture boundary is not mounted.');
    }

    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError(
        'CockpitSurface capture boundary is not a RepaintBoundary.',
      );
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode CockpitSurface capture as PNG.');
    }

    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    if (bytes.isEmpty) {
      throw StateError('CockpitSurface capture encoded an empty PNG.');
    }

    return CockpitCapturedScreenshot(
      artifact: CockpitArtifactRef(
        role: 'screenshot',
        relativePath: cockpitScreenshotRelativePathFor(request),
      ),
      bytes: bytes,
      snapshot: snapshot,
    );
  }
}
