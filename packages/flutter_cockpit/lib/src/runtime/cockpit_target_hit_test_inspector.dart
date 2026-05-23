import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'cockpit_target.dart';
import 'cockpit_target_geometry.dart';
import 'cockpit_target_geometry_resolver.dart';

final class CockpitTargetHitTestResult {
  const CockpitTargetHitTestResult({
    required this.hit,
    required this.position,
    required this.targetRenderObjectType,
    required this.withinTargetBounds,
    this.matchedRenderObjectType,
    this.hitPath = const <String>[],
  });

  final bool hit;
  final Offset position;
  final String targetRenderObjectType;
  final bool withinTargetBounds;
  final String? matchedRenderObjectType;
  final List<String> hitPath;

  Map<String, Object?> toJson() => <String, Object?>{
    'hit': hit,
    'withinTargetBounds': withinTargetBounds,
    'position': <String, double>{'dx': position.dx, 'dy': position.dy},
    'targetRenderObjectType': targetRenderObjectType,
    if (matchedRenderObjectType != null)
      'matchedRenderObjectType': matchedRenderObjectType,
    'hitPath': hitPath,
  };
}

abstract final class CockpitTargetHitTestInspector {
  static CockpitTargetHitTestResult? inspect(
    CockpitTarget target, {
    Offset? position,
  }) {
    final geometry = CockpitTargetGeometryResolver.maybeFromTarget(target);
    if (geometry == null) {
      return null;
    }

    final diagnosticNode = target.diagnosticNodeProvider?.call();
    final element = diagnosticNode is Element ? diagnosticNode : null;
    if (element == null || !element.mounted) {
      return null;
    }

    final renderObject = element.findRenderObject();
    if (renderObject is! RenderObject || !renderObject.attached) {
      return null;
    }

    final resolvedPosition = _resolvePosition(
      geometry,
      position ?? Offset(geometry.centerX, geometry.centerY),
    );
    final withinTargetBounds = geometry.containsPoint(
      dx: resolvedPosition.dx,
      dy: resolvedPosition.dy,
    );
    final hitTestResult = HitTestResult();
    GestureBinding.instance.hitTestInView(
      hitTestResult,
      resolvedPosition,
      geometry.viewId,
    );

    final renderPath = hitTestResult.path
        .map((entry) => entry.target)
        .whereType<RenderObject>()
        .toList(growable: false);
    String? matchedRenderObjectType;
    renderPath.any((entryTarget) {
      final matched = _belongsToTargetLineage(renderObject, entryTarget);
      if (matched && matchedRenderObjectType == null) {
        matchedRenderObjectType = entryTarget.runtimeType.toString();
      }
      return matched;
    });
    final primaryRenderObject = renderPath.isEmpty ? null : renderPath.first;
    final hit =
        primaryRenderObject != null &&
        _belongsToTargetLineage(renderObject, primaryRenderObject);

    return CockpitTargetHitTestResult(
      hit: hit,
      position: resolvedPosition,
      targetRenderObjectType: renderObject.runtimeType.toString(),
      withinTargetBounds: withinTargetBounds,
      matchedRenderObjectType: matchedRenderObjectType,
      hitPath: hitTestResult.path
          .map((entry) => entry.target.runtimeType.toString())
          .toList(growable: false),
    );
  }

  static Offset _resolvePosition(
    CockpitTargetGeometry geometry,
    Offset position,
  ) {
    return Offset(
      geometry.clampXToViewport(position.dx),
      geometry.clampYToViewport(position.dy),
    );
  }

  static bool _belongsToTargetLineage(
    RenderObject targetRenderObject,
    RenderObject hitRenderObject,
  ) {
    RenderObject? current = hitRenderObject;
    while (current != null) {
      if (identical(current, targetRenderObject)) {
        return true;
      }
      current = current.parent;
    }
    current = targetRenderObject;
    while (current != null) {
      if (identical(current, hitRenderObject)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
