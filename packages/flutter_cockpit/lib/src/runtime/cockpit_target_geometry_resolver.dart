import 'package:flutter/widgets.dart';

import 'cockpit_target.dart';
import 'cockpit_target_geometry.dart';

abstract final class CockpitTargetGeometryResolver {
  static CockpitTargetGeometry? maybeFromTarget(CockpitTarget target) {
    final explicitGeometry = target.geometryProvider?.call();
    if (explicitGeometry != null) {
      return explicitGeometry;
    }
    final diagnosticNode = target.diagnosticNodeProvider?.call();
    final element = diagnosticNode is Element ? diagnosticNode : null;
    if (element == null || !element.mounted) {
      return null;
    }
    return maybeFromElement(element);
  }

  static CockpitTargetGeometry? maybeFromElement(Element element) {
    if (!element.mounted) {
      return null;
    }

    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    if (!renderObject.hasSize) {
      return null;
    }

    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final view =
        View.maybeOf(element) ??
        WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      return null;
    }
    final logicalViewSize = view.physicalSize / view.devicePixelRatio;

    return CockpitTargetGeometry(
      left: origin.dx,
      top: origin.dy,
      width: size.width,
      height: size.height,
      viewportLeft: 0,
      viewportTop: 0,
      viewportWidth: logicalViewSize.width,
      viewportHeight: logicalViewSize.height,
      viewId: view.viewId,
    );
  }

  static CockpitTargetGeometry? maybeFromViewport(Element element) {
    if (!element.mounted) {
      return null;
    }
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) {
      return null;
    }
    if (!renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final view =
        View.maybeOf(element) ??
        WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      return null;
    }

    return CockpitTargetGeometry(
      left: origin.dx,
      top: origin.dy,
      width: size.width,
      height: size.height,
      viewportLeft: origin.dx,
      viewportTop: origin.dy,
      viewportWidth: size.width,
      viewportHeight: size.height,
      viewId: view.viewId,
    );
  }
}
