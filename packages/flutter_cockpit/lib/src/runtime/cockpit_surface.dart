import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../capture/cockpit_captured_screenshot.dart';
import '../capture/flutter_view_capture.dart';
import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import '../gesture/cockpit_gesture_engine.dart';
import '../control/cockpit_screenshot_request.dart';
import '../gesture/cockpit_gesture_action.dart';
import '../gesture/cockpit_gesture_profile.dart';
import 'cockpit_discovery_engine.dart';
import 'cockpit_discovery_policy.dart';
import 'cockpit_rebuild_tracker.dart';
import 'cockpit_reveal_alignment.dart';
import 'cockpit_tap_feedback_overlay.dart';
import 'cockpit_diagnostic_builder.dart';
import 'cockpit_runtime_tree_visibility.dart';
import 'cockpit_semantics_bridge.dart';
import 'cockpit_snapshot.dart';
import 'cockpit_snapshot_options.dart';
import 'cockpit_target.dart';
import 'cockpit_target_geometry.dart';
import 'cockpit_target_geometry_resolver.dart';
import 'cockpit_target_registry.dart';

final class CockpitSurface extends StatefulWidget {
  const CockpitSurface({
    required this.routeName,
    required this.child,
    super.key,
    this.registry,
    this.gestureDelay,
    this.discoveryPolicy = const CockpitDiscoveryPolicy(),
    this.rebuildTracker,
    this.tapFeedbackController,
  });

  final String routeName;
  final Widget child;
  final CockpitTargetRegistry? registry;
  final CockpitGestureDelay? gestureDelay;
  final CockpitDiscoveryPolicy discoveryPolicy;
  final CockpitRebuildTracker? rebuildTracker;
  final CockpitTapFeedbackController? tapFeedbackController;

  static CockpitSurfaceState of(BuildContext context) {
    final state = maybeOf(context);
    if (state == null) {
      throw StateError('No CockpitSurface found in the current BuildContext.');
    }
    return state;
  }

  static CockpitSurfaceState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CockpitSurfaceScope>()
        ?.state;
  }

  @override
  State<CockpitSurface> createState() => CockpitSurfaceState();
}

final class CockpitSurfaceState extends State<CockpitSurface> {
  final GlobalKey _boundaryKey = GlobalKey(
    debugLabel: 'CockpitSurfaceBoundary',
  );
  final FlutterViewCapture _capture = const FlutterViewCapture();
  final CockpitDiagnosticBuilder _diagnosticBuilder =
      const CockpitDiagnosticBuilder();
  SemanticsHandle? _semanticsHandle;
  late CockpitDiscoveryEngine _discoveryEngine = CockpitDiscoveryEngine(
    policy: widget.discoveryPolicy,
  );
  late final CockpitGestureEngine _gestureEngine = CockpitGestureEngine(
    delay: widget.gestureDelay,
    viewportGeometryProvider: _viewportGeometry,
  );
  late final CockpitTargetRegistry _registry =
      widget.registry ?? CockpitTargetRegistry(routeName: widget.routeName);

  CockpitTargetRegistry get registry => _registry;

  @override
  void initState() {
    super.initState();
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
    _registry.discoveredTargetsProvider = _discoverNativeTargets;
  }

  @override
  void didUpdateWidget(covariant CockpitSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registry.routeName = widget.routeName;
    if (oldWidget.discoveryPolicy != widget.discoveryPolicy) {
      _discoveryEngine = CockpitDiscoveryEngine(policy: widget.discoveryPolicy);
    }
  }

  @override
  void dispose() {
    _registry.discoveredTargetsProvider = null;
    _semanticsHandle?.dispose();
    super.dispose();
  }

  CockpitSnapshot snapshot({
    CockpitSnapshotOptions options = const CockpitSnapshotOptions(),
  }) {
    final snapshot = options.profile == CockpitSnapshotProfile.live
        ? _registry.snapshot()
        : _diagnosticBuilder
            .build(
              routeName: _registry.routeName,
              visibleTargets: _registry.visibleTargets,
              options: options,
            )
            .snapshot;
    if (!options.includeRebuildActivity || widget.rebuildTracker == null) {
      return snapshot;
    }
    return snapshot.copyWith(
      rebuild: widget.rebuildTracker!.snapshot(
        maxEntries: options.maxRebuildEntries,
      ),
    );
  }

  Future<CockpitCapturedScreenshot> captureScreenshot(
    CockpitScreenshotRequest request, {
    double pixelRatio = 1.0,
  }) {
    return _capture.capture(
      repaintBoundaryKey: _boundaryKey,
      request: request,
      snapshot: request.includeSnapshot
          ? snapshot(
              options: request.snapshotOptions ??
                  const CockpitSnapshotOptions.live(),
            )
          : null,
      pixelRatio: pixelRatio,
    );
  }

  Future<void> performGesture(CockpitGestureAction action) {
    widget.tapFeedbackController?.record(action);
    return _gestureEngine.perform(action);
  }

  Future<bool> ensureLocatorVisible(
    CockpitLocator locator, {
    Duration duration = const Duration(milliseconds: 220),
    CockpitRevealAlignment alignment = CockpitRevealAlignment.nearest,
    double padding = 0,
  }) async {
    final rootContext = _boundaryKey.currentContext;
    if (rootContext is! Element) {
      return false;
    }

    final match = _findMountedElementForLocator(rootContext, locator);
    if (match == null) {
      return false;
    }

    final binding = WidgetsBinding.instance;
    final effectiveDuration =
        _isTestBinding(binding) ? Duration.zero : duration;
    final revealRequest = _resolveRevealRequest(
      match,
      alignment: alignment,
      padding: padding,
    );
    if (revealRequest == null) {
      return true;
    }
    await Scrollable.ensureVisible(
      match,
      alignment: revealRequest.alignment,
      duration: effectiveDuration,
      curve: Curves.easeOutCubic,
      alignmentPolicy: revealRequest.alignmentPolicy,
    );
    await _applyRevealAdjustment(
      match,
      alignment: alignment,
      padding: padding,
      duration: effectiveDuration,
    );
    return true;
  }

  List<CockpitTarget> _discoverNativeTargets() {
    final rootContext = _boundaryKey.currentContext;
    if (rootContext == null) {
      return const <CockpitTarget>[];
    }

    return _discoveryEngine.discover(
      rootContext: rootContext,
      routeName: _registry.routeName,
      explicitTargets: _registry.registeredTargets,
    );
  }

  CockpitTargetGeometry? _viewportGeometry() {
    final rootContext = _boundaryKey.currentContext;
    if (rootContext is! Element) {
      return null;
    }
    return CockpitTargetGeometryResolver.maybeFromViewport(rootContext);
  }

  Future<bool> scrollByViewport({
    bool reverse = false,
    double viewportFraction = 0.8,
    String? scrollableKey,
    Duration duration = const Duration(milliseconds: 220),
    CockpitGestureProfile gestureProfile = CockpitGestureProfile.userLike,
    bool continuous = false,
    bool postScrollEnsureVisible = true,
  }) async {
    final rootContext = _boundaryKey.currentContext;
    if (rootContext == null) {
      return false;
    }

    final scrollables =
        _discoverScrollables(rootContext as Element).where((candidate) {
      final position = candidate.state.position;
      if (!position.haveDimensions || position.maxScrollExtent <= 0) {
        return false;
      }
      if (scrollableKey == null || scrollableKey.isEmpty) {
        return true;
      }
      return candidate.keyValue == scrollableKey;
    }).toList(growable: false);
    if (scrollables.isEmpty) {
      return false;
    }

    scrollables.sort((left, right) {
      final viewportCompare = right.state.position.viewportDimension.compareTo(
        left.state.position.viewportDimension,
      );
      if (viewportCompare != 0) {
        return viewportCompare;
      }
      return right.depth.compareTo(left.depth);
    });

    final position = scrollables.first.state.position;
    final axisSign = switch (position.axisDirection) {
      AxisDirection.down || AxisDirection.right => 1.0,
      AxisDirection.up || AxisDirection.left => -1.0,
    };
    final delta =
        position.viewportDimension * viewportFraction.clamp(0.1, 0.95);
    final directionSign = reverse ? -axisSign : axisSign;
    final nextPixels = (position.pixels + (delta * directionSign)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final acceptsUserOffset = position.physics.shouldAcceptUserOffset(position);
    if ((nextPixels - position.pixels).abs() < 0.5) {
      return false;
    }

    final semanticScrollAction = cockpitResolveSemanticScrollAction(
      axisDirection: position.axisDirection,
      forward: nextPixels > position.pixels,
    );
    final scrollGeometry = CockpitTargetGeometryResolver.maybeFromElement(
      scrollables.first.element,
    );
    if (scrollGeometry != null) {
      final initialPixels = position.pixels;
      try {
        await _gestureEngine.perform(
          CockpitGestureAction.drag(
            geometry: scrollGeometry,
            delta: _scrollDragDelta(
              axisDirection: position.axisDirection,
              distance: delta,
              forward: nextPixels > position.pixels,
            ),
            duration: duration,
            moveEventCount: continuous ? 24 : 0,
            profile: gestureProfile,
            touchSlopX: 8,
            touchSlopY: 8,
          ),
        );
        if (postScrollEnsureVisible) {
          await Future<void>.microtask(() {});
        }
        if ((position.pixels - initialPixels).abs() >= 0.5) {
          return true;
        }
        if (acceptsUserOffset) {
          return true;
        }
      } on StateError {
        // Fall through to semantics or direct position adjustment.
      } on ArgumentError {
        // Fall through to semantics or direct position adjustment.
      }
    }
    if (semanticScrollAction != null) {
      final initialPixels = position.pixels;
      final semanticAction = scrollables.first.semanticScrollActionHandler(
        semanticScrollAction,
      );
      if (semanticAction != null) {
        semanticAction();
        await Future<void>.microtask(() {});
        if ((position.pixels - initialPixels).abs() >= 0.5) {
          return true;
        }
        if (acceptsUserOffset) {
          return true;
        }
      }
    }

    return false;
  }

  Offset _scrollDragDelta({
    required AxisDirection axisDirection,
    required double distance,
    required bool forward,
  }) {
    return switch ((axisDirection, forward)) {
      (AxisDirection.down, true) => Offset(0, -distance),
      (AxisDirection.down, false) => Offset(0, distance),
      (AxisDirection.up, true) => Offset(0, distance),
      (AxisDirection.up, false) => Offset(0, -distance),
      (AxisDirection.right, true) => Offset(-distance, 0),
      (AxisDirection.right, false) => Offset(distance, 0),
      (AxisDirection.left, true) => Offset(distance, 0),
      (AxisDirection.left, false) => Offset(-distance, 0),
    };
  }

  List<_CockpitScrollableCandidate> _discoverScrollables(Element rootElement) {
    final candidates = <_CockpitScrollableCandidate>[];
    final policy = widget.discoveryPolicy;

    void visit(Element element, int depth) {
      if (!cockpitIsVisibleInRuntimeTree(element) ||
          policy.ignoresSubtree(element)) {
        return;
      }
      if (element is StatefulElement && element.state is ScrollableState) {
        candidates.add(
          _CockpitScrollableCandidate(
            state: element.state as ScrollableState,
            depth: depth,
            keyValue: _scrollableKeyValue(element),
            element: element,
          ),
        );
        if (policy.marksScrollableBoundary(element)) {
          return;
        }
      }
      if (policy.stopsTraversal(element)) {
        return;
      }

      element.visitChildElements((child) => visit(child, depth + 1));
    }

    visit(rootElement, 0);
    return candidates;
  }

  String? _stableKeyValue(Key? key) {
    return switch (key) {
      ValueKey<Object?>(value: final value) => value?.toString(),
      ObjectKey(value: final value) => value.toString(),
      _ => null,
    };
  }

  String? _scrollableKeyValue(Element element) {
    final ownKey = _stableKeyValue(element.widget.key);
    if (ownKey != null && ownKey.isNotEmpty) {
      return ownKey;
    }

    String? ancestorKey;
    element.visitAncestorElements((ancestor) {
      ancestorKey = _stableKeyValue(ancestor.widget.key);
      return ancestorKey == null || ancestorKey!.isEmpty;
    });
    return ancestorKey;
  }

  Element? _findMountedElementForLocator(
      Element rootElement, CockpitLocator locator) {
    for (final candidate in _flatten(locator)) {
      final match = _visitForLocator(rootElement, candidate);
      if (match != null) {
        return match;
      }
    }
    return null;
  }

  Iterable<CockpitLocator> _flatten(CockpitLocator locator) sync* {
    yield locator;
    for (final fallback in locator.fallbacks) {
      yield* _flatten(fallback);
    }
  }

  Element? _visitForLocator(Element rootElement, CockpitLocator locator) {
    Element? bestMatch;

    void visit(Element element) {
      if (!element.mounted ||
          widget.discoveryPolicy.ignoresSubtree(element) ||
          !cockpitIsVisibleInRuntimeTree(element)) {
        return;
      }
      if (_elementMatchesLocator(element, locator)) {
        bestMatch = element;
      }
      if (bestMatch != null || widget.discoveryPolicy.stopsTraversal(element)) {
        return;
      }
      element.visitChildElements(visit);
    }

    visit(rootElement);
    return bestMatch;
  }

  bool _elementMatchesLocator(Element element, CockpitLocator locator) {
    return switch (locator.kind) {
      CockpitLocatorKind.cockpitId => false,
      CockpitLocatorKind.semanticId => false,
      CockpitLocatorKind.key =>
        _stableKeyValue(element.widget.key) == locator.value,
      CockpitLocatorKind.text => _elementTextSignals(element).any(
          (candidate) => _matchesTextSignal(candidate, locator.value),
        ),
      CockpitLocatorKind.tooltip => _elementTooltip(element) == locator.value,
      CockpitLocatorKind.type =>
        element.widget.runtimeType.toString() == locator.value,
      CockpitLocatorKind.route => false,
    };
  }

  Iterable<String?> _elementTextSignals(Element element) sync* {
    final widget = element.widget;
    if (widget case Text(data: final data)) {
      yield data;
      yield widget.semanticsLabel;
    } else if (widget is RichText) {
      yield widget.text.toPlainText();
    } else if (widget case EditableText(controller: final controller)) {
      yield controller.text;
    }
    yield _elementTooltip(element);
  }

  String? _elementTooltip(Element element) {
    return null;
  }

  bool _matchesTextSignal(String? candidate, String expected) {
    final normalizedCandidate = _normalizeText(candidate);
    final normalizedExpected = _normalizeText(expected);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return false;
    }
    return normalizedCandidate == normalizedExpected ||
        normalizedCandidate.contains(normalizedExpected);
  }

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  bool _isTestBinding(WidgetsBinding binding) {
    return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  Future<void> _applyRevealAdjustment(
    Element targetElement, {
    required CockpitRevealAlignment alignment,
    required double padding,
    required Duration duration,
  }) async {
    final scrollableState = Scrollable.maybeOf(targetElement);
    final targetRenderObject = targetElement.findRenderObject();
    final viewportRenderObject =
        _resolveViewportRenderObject(targetRenderObject);
    if (scrollableState == null ||
        targetRenderObject is! RenderBox ||
        !targetRenderObject.hasSize ||
        viewportRenderObject is! RenderBox ||
        !viewportRenderObject.hasSize) {
      return;
    }

    final axisDirection = scrollableState.position.axisDirection;
    final axis = switch (axisDirection) {
      AxisDirection.down || AxisDirection.up => Axis.vertical,
      AxisDirection.left || AxisDirection.right => Axis.horizontal,
    };
    final viewportExtent = axis == Axis.vertical
        ? viewportRenderObject.size.height
        : viewportRenderObject.size.width;
    final targetExtent = axis == Axis.vertical
        ? targetRenderObject.size.height
        : targetRenderObject.size.width;
    final availableExtent = viewportExtent - targetExtent;
    if (availableExtent <= 0) {
      return;
    }

    final origin = targetRenderObject.localToGlobal(
      Offset.zero,
      ancestor: viewportRenderObject,
    );
    final leadingEdge = axis == Axis.vertical ? origin.dy : origin.dx;
    final trailingEdge = leadingEdge + targetExtent;
    final clampedPadding = padding.clamp(0, availableExtent).toDouble();
    final desiredLeadingEdge = switch (alignment) {
      CockpitRevealAlignment.start => clampedPadding,
      CockpitRevealAlignment.center => availableExtent / 2,
      CockpitRevealAlignment.end =>
        viewportExtent - targetExtent - clampedPadding,
      CockpitRevealAlignment.nearest => leadingEdge < clampedPadding
          ? clampedPadding
          : trailingEdge > viewportExtent - clampedPadding
              ? viewportExtent - targetExtent - clampedPadding
              : leadingEdge,
    };
    final viewportDelta = leadingEdge - desiredLeadingEdge;
    if (viewportDelta.abs() < 0.5) {
      return;
    }

    final scrollSign = switch (axisDirection) {
      AxisDirection.down || AxisDirection.right => 1.0,
      AxisDirection.up || AxisDirection.left => -1.0,
    };
    final nextPixels =
        (scrollableState.position.pixels + (viewportDelta * scrollSign)).clamp(
      scrollableState.position.minScrollExtent,
      scrollableState.position.maxScrollExtent,
    );
    if ((nextPixels - scrollableState.position.pixels).abs() < 0.5) {
      return;
    }

    if (duration == Duration.zero) {
      scrollableState.position.jumpTo(nextPixels);
      return;
    }

    await scrollableState.position.animateTo(
      nextPixels,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  _CockpitRevealRequest? _resolveRevealRequest(
    Element targetElement, {
    required CockpitRevealAlignment alignment,
    required double padding,
  }) {
    final scrollableState = Scrollable.maybeOf(targetElement);
    final targetRenderObject = targetElement.findRenderObject();
    final viewportRenderObject =
        _resolveViewportRenderObject(targetRenderObject);
    if (targetRenderObject is! RenderBox ||
        !targetRenderObject.hasSize ||
        viewportRenderObject is! RenderBox ||
        !viewportRenderObject.hasSize) {
      return switch (alignment) {
        CockpitRevealAlignment.nearest => const _CockpitRevealRequest(
            alignment: 1,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        CockpitRevealAlignment.start => const _CockpitRevealRequest(
            alignment: 0,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
        CockpitRevealAlignment.center => const _CockpitRevealRequest(
            alignment: 0.5,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
        CockpitRevealAlignment.end => const _CockpitRevealRequest(
            alignment: 1,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          ),
      };
    }

    final axis = switch (scrollableState!.position.axisDirection) {
      AxisDirection.down || AxisDirection.up => Axis.vertical,
      AxisDirection.left || AxisDirection.right => Axis.horizontal,
    };
    final viewportExtent = axis == Axis.vertical
        ? viewportRenderObject.size.height
        : viewportRenderObject.size.width;
    final targetExtent = axis == Axis.vertical
        ? targetRenderObject.size.height
        : targetRenderObject.size.width;
    final availableExtent = viewportExtent - targetExtent;
    if (availableExtent <= 0) {
      return const _CockpitRevealRequest(
        alignment: 0,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }

    final clampedPadding = padding.clamp(0, availableExtent).toDouble();
    final targetOrigin = targetRenderObject.localToGlobal(
      Offset.zero,
      ancestor: viewportRenderObject,
    );
    final leadingEdge =
        axis == Axis.vertical ? targetOrigin.dy : targetOrigin.dx;
    final trailingEdge = leadingEdge + targetExtent;
    final paddedLeadingEdge = clampedPadding;
    final paddedTrailingEdge = viewportExtent - clampedPadding;

    return switch (alignment) {
      CockpitRevealAlignment.start => _CockpitRevealRequest(
          alignment: clampedPadding / availableExtent,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        ),
      CockpitRevealAlignment.center => const _CockpitRevealRequest(
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        ),
      CockpitRevealAlignment.end => _CockpitRevealRequest(
          alignment: 1 - (clampedPadding / availableExtent),
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        ),
      CockpitRevealAlignment.nearest =>
        (leadingEdge >= paddedLeadingEdge && trailingEdge <= paddedTrailingEdge)
            ? null
            : trailingEdge > paddedTrailingEdge
                ? _CockpitRevealRequest(
                    alignment: 1 - (clampedPadding / availableExtent),
                    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                  )
                : _CockpitRevealRequest(
                    alignment: clampedPadding / availableExtent,
                    alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                  ),
    };
  }

  RenderObject? _resolveViewportRenderObject(RenderObject? targetRenderObject) {
    if (targetRenderObject == null) {
      return null;
    }
    try {
      return RenderAbstractViewport.of(targetRenderObject) as RenderObject?;
    } on FlutterError {
      return null;
    } on StateError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _registry.routeName = widget.routeName;

    return _CockpitSurfaceScope(
      state: this,
      child: RepaintBoundary(key: _boundaryKey, child: widget.child),
    );
  }
}

final class _CockpitRevealRequest {
  const _CockpitRevealRequest({
    required this.alignment,
    required this.alignmentPolicy,
  });

  final double alignment;
  final ScrollPositionAlignmentPolicy alignmentPolicy;
}

final class _CockpitScrollableCandidate {
  const _CockpitScrollableCandidate({
    required this.state,
    required this.depth,
    required this.keyValue,
    required this.element,
  });

  final ScrollableState state;
  final int depth;
  final String? keyValue;
  final Element element;

  VoidCallback? semanticScrollActionHandler(SemanticsAction action) {
    return cockpitResolveSemanticsTargetInfo(element)?.actionHandler(action);
  }
}

final class _CockpitSurfaceScope extends InheritedWidget {
  const _CockpitSurfaceScope({required this.state, required super.child});

  final CockpitSurfaceState state;

  @override
  bool updateShouldNotify(_CockpitSurfaceScope oldWidget) {
    return oldWidget.state != state;
  }
}

final class CockpitTargetNode extends StatefulWidget {
  const CockpitTargetNode({
    required this.registrationId,
    required this.child,
    super.key,
    this.cockpitId,
    this.semanticId,
    this.text,
    this.tooltip,
    this.typeName,
    this.supportedCommands = const <CockpitCommandType>{},
    this.onTap,
    this.onEnterText,
  });

  final String registrationId;
  final String? cockpitId;
  final String? semanticId;
  final String? text;
  final String? tooltip;
  final String? typeName;
  final Set<CockpitCommandType> supportedCommands;
  final CockpitTapHandler? onTap;
  final CockpitEnterTextHandler? onEnterText;
  final Widget child;

  @override
  State<CockpitTargetNode> createState() => _CockpitTargetNodeState();
}

final class _CockpitTargetNodeState extends State<CockpitTargetNode> {
  CockpitTargetRegistry? _registry;
  final GlobalKey _diagnosticKey = GlobalKey(debugLabel: 'CockpitTargetNode');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerTarget();
  }

  @override
  void didUpdateWidget(covariant CockpitTargetNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registerTarget();
  }

  @override
  void dispose() {
    _registry?.unregister(widget.registrationId);
    super.dispose();
  }

  void _registerTarget() {
    final surface = CockpitSurface.maybeOf(context);
    final registry = surface?.registry;
    if (registry == null) {
      return;
    }

    if (!identical(_registry, registry)) {
      _registry?.unregister(widget.registrationId);
      _registry = registry;
    }

    registry.register(
      CockpitTarget(
        registrationId: widget.registrationId,
        cockpitId: widget.cockpitId,
        semanticId: widget.semanticId,
        text: widget.text,
        tooltip: widget.tooltip,
        typeName: widget.typeName,
        routeName: registry.routeName ?? '',
        supportedCommands: widget.supportedCommands,
        onTap: widget.onTap,
        onEnterText: widget.onEnterText,
        diagnosticNodeProvider: () => _diagnosticKey.currentContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _diagnosticKey, child: widget.child);
  }
}
