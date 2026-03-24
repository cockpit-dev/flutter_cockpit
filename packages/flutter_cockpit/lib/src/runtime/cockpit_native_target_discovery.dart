// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../control/cockpit_command_type.dart';
import 'cockpit_discovery_policy.dart';
import 'cockpit_runtime_tree_visibility.dart';
import 'cockpit_semantics_bridge.dart';
import 'cockpit_target.dart';
import 'cockpit_target_geometry_resolver.dart';
import 'cockpit_text_input_request.dart';

final class CockpitNativeTargetDiscovery {
  const CockpitNativeTargetDiscovery({
    this.policy = const CockpitDiscoveryPolicy(),
  });

  final CockpitDiscoveryPolicy policy;

  List<CockpitTarget> discover({
    required BuildContext rootContext,
    required String? routeName,
    List<CockpitTarget> explicitTargets = const <CockpitTarget>[],
  }) {
    final rootElement = rootContext as Element;
    final rootViewport = _viewportBoundsFor(rootElement);
    final explicitElements = explicitTargets
        .map((target) => target.diagnosticNodeProvider?.call())
        .whereType<Element>()
        .toList(growable: false);
    final discoveredTargets = <CockpitTarget>[];

    void visit(Element element, String path, bool insideActionableTarget) {
      if (!element.mounted ||
          policy.ignoresSubtree(element) ||
          !cockpitIsVisibleInRuntimeTree(element) ||
          _isCoveredByExplicitTarget(element, explicitElements)) {
        return;
      }

      final targetRouteName = cockpitResolvedElementRouteName(
        element,
        fallbackRouteName: routeName,
      );

      final candidate =
          _isRenderable(element) && _overlapsViewport(element, rootViewport)
              ? _buildTarget(
                  element,
                  routeName: targetRouteName,
                  path: path,
                  insideActionableTarget: insideActionableTarget,
                )
              : null;
      final hasMeaningfulViewportExposure = candidate == null ||
          _hasMeaningfulViewportExposure(
            element,
            rootViewport,
            strictVisibility: candidate.supportedCommands.isEmpty,
          );
      final createsActionableScope = candidate != null &&
          hasMeaningfulViewportExposure &&
          candidate.supportedCommands.isNotEmpty;
      if (candidate != null && hasMeaningfulViewportExposure) {
        discoveredTargets.add(candidate);
      }
      if (policy.stopsTraversal(element)) {
        return;
      }

      var childIndex = 0;
      element.visitChildElements((child) {
        visit(
          child,
          '$path.$childIndex',
          insideActionableTarget || createsActionableScope,
        );
        childIndex += 1;
      });
    }

    visit(rootElement, 'root', false);
    return _deduplicateDiscoveredTargets(discoveredTargets);
  }

  List<CockpitTarget> _deduplicateDiscoveredTargets(
    List<CockpitTarget> targets,
  ) {
    final deduplicated = <CockpitTarget>[];
    for (final target in targets) {
      final duplicateIndex = deduplicated.indexWhere(
        (existing) => _isDuplicatePassiveTextTarget(existing, target),
      );
      if (duplicateIndex == -1) {
        deduplicated.add(target);
        continue;
      }
      deduplicated[duplicateIndex] = _preferredDuplicateTarget(
        deduplicated[duplicateIndex],
        target,
      );
    }
    return deduplicated;
  }

  bool _isDuplicatePassiveTextTarget(CockpitTarget left, CockpitTarget right) {
    if (left.supportedCommands.isNotEmpty ||
        right.supportedCommands.isNotEmpty) {
      return false;
    }
    if (left.routeName != right.routeName || left.text != right.text) {
      return false;
    }
    final text = left.text;
    if (text == null || text.isEmpty) {
      return false;
    }

    final leftElement = left.diagnosticNodeProvider?.call();
    final rightElement = right.diagnosticNodeProvider?.call();
    if (leftElement is Element && rightElement is Element) {
      if (!_areRelatedElements(leftElement, rightElement)) {
        return false;
      }
    }

    final leftGeometry = CockpitTargetGeometryResolver.maybeFromTarget(left);
    final rightGeometry = CockpitTargetGeometryResolver.maybeFromTarget(right);
    if (leftGeometry == null || rightGeometry == null) {
      return true;
    }

    final leftRect = Rect.fromLTWH(
      leftGeometry.left,
      leftGeometry.top,
      leftGeometry.width,
      leftGeometry.height,
    );
    final rightRect = Rect.fromLTWH(
      rightGeometry.left,
      rightGeometry.top,
      rightGeometry.width,
      rightGeometry.height,
    );
    final intersection = leftRect.intersect(rightRect);
    if (intersection.isEmpty) {
      return false;
    }
    final overlapArea = intersection.width * intersection.height;
    final minArea = (leftRect.width * leftRect.height).clamp(
      1.0,
      double.infinity,
    );
    final rightArea = (rightRect.width * rightRect.height).clamp(
      1.0,
      double.infinity,
    );
    final requiredArea = minArea < rightArea ? minArea : rightArea;
    return overlapArea >= requiredArea * 0.9;
  }

  bool _areRelatedElements(Element left, Element right) {
    if (identical(left, right)) {
      return true;
    }

    var related = false;
    left.visitAncestorElements((ancestor) {
      if (identical(ancestor, right)) {
        related = true;
        return false;
      }
      return true;
    });
    if (related) {
      return true;
    }

    right.visitAncestorElements((ancestor) {
      if (identical(ancestor, left)) {
        related = true;
        return false;
      }
      return true;
    });
    return related;
  }

  CockpitTarget _preferredDuplicateTarget(
    CockpitTarget existing,
    CockpitTarget candidate,
  ) {
    final existingElement = existing.diagnosticNodeProvider?.call();
    final candidateElement = candidate.diagnosticNodeProvider?.call();
    final existingType = existing.typeName;
    final candidateType = candidate.typeName;
    final existingIsSemantics = existingType == 'Semantics';
    final candidateIsSemantics = candidateType == 'Semantics';
    if (existingIsSemantics != candidateIsSemantics) {
      return candidateIsSemantics ? existing : candidate;
    }

    if (existingElement is Element && candidateElement is Element) {
      if (_isAncestorOf(existingElement, candidateElement)) {
        return candidate;
      }
      if (_isAncestorOf(candidateElement, existingElement)) {
        return existing;
      }
    }

    final existingGeometry = CockpitTargetGeometryResolver.maybeFromTarget(
      existing,
    );
    final candidateGeometry = CockpitTargetGeometryResolver.maybeFromTarget(
      candidate,
    );
    if (existingGeometry != null && candidateGeometry != null) {
      final existingArea = existingGeometry.width * existingGeometry.height;
      final candidateArea = candidateGeometry.width * candidateGeometry.height;
      if (candidateArea < existingArea) {
        return candidate;
      }
      if (existingArea < candidateArea) {
        return existing;
      }
    }

    return existing.registrationId.compareTo(candidate.registrationId) <= 0
        ? existing
        : candidate;
  }

  bool _isAncestorOf(Element ancestor, Element descendant) {
    var isAncestor = false;
    descendant.visitAncestorElements((candidate) {
      if (identical(candidate, ancestor)) {
        isAncestor = true;
        return false;
      }
      return true;
    });
    return isAncestor;
  }

  Rect? _viewportBoundsFor(Element rootElement) {
    final renderObject = rootElement.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  CockpitTarget? _buildTarget(
    Element element, {
    required String? routeName,
    required String path,
    required bool insideActionableTarget,
  }) {
    final semantics = cockpitResolveSemanticsTargetInfo(element);
    final tapHandler = _tapHandlerForElement(element);
    final longPressHandler = _longPressHandlerForElement(element);
    final doubleTapHandler = _doubleTapHandlerForElement(element);
    final enterTextHandler = _enterTextHandlerForElement(element);
    final textInputHandler = _textInputHandlerForElement(element);
    final hasDirectHandlers = tapHandler != null ||
        longPressHandler != null ||
        doubleTapHandler != null ||
        enterTextHandler != null ||
        textInputHandler != null;
    final supportedCommands = <CockpitCommandType>{
      if (tapHandler != null) CockpitCommandType.tap,
      if (longPressHandler != null) CockpitCommandType.longPress,
      if (doubleTapHandler != null) CockpitCommandType.doubleTap,
      if (enterTextHandler != null || textInputHandler != null)
        CockpitCommandType.enterText,
      if (textInputHandler != null) ...<CockpitCommandType>{
        CockpitCommandType.focusTextInput,
        CockpitCommandType.setTextEditingValue,
        CockpitCommandType.sendTextInputAction,
      },
      if (semantics != null) ...semantics.supportedCommands,
    };
    final typeName = element.widget.runtimeType.toString();

    if (insideActionableTarget) {
      return null;
    }

    if (!hasDirectHandlers &&
        supportedCommands.isNotEmpty &&
        _shouldDeferSemanticsOnlyCandidate(element, semantics)) {
      return null;
    }

    if (supportedCommands.isNotEmpty) {
      final metadata = _extractInteractiveMetadata(
        element,
        semantics: semantics,
      );
      return CockpitTarget(
        registrationId: _registrationId(
          routeName: routeName,
          path: path,
          typeName: typeName,
          bestLabel: metadata.displayLabel,
        ),
        semanticId: metadata.semanticId,
        keyValue: metadata.keyValue,
        text: metadata.text,
        tooltip: metadata.tooltip,
        typeName: typeName,
        routeName: routeName ?? '',
        supportedCommands: supportedCommands,
        onTap: tapHandler,
        onLongPress: longPressHandler,
        onDoubleTap: doubleTapHandler,
        onEnterText: enterTextHandler,
        onTextInput: textInputHandler,
        onSemanticTap: semantics?.actionHandler(SemanticsAction.tap),
        onSemanticLongPress: semantics?.actionHandler(
          SemanticsAction.longPress,
        ),
        onSemanticShowOnScreen: semantics?.actionHandler(
          SemanticsAction.showOnScreen,
        ),
        onSemanticIncrease: semantics?.actionHandler(SemanticsAction.increase),
        onSemanticDecrease: semantics?.actionHandler(SemanticsAction.decrease),
        onSemanticDismiss: semantics?.actionHandler(SemanticsAction.dismiss),
        onSemanticEnterText: semantics == null ||
                !semantics.supports(SemanticsAction.setText)
            ? null
            : (text) => semantics.performAction(SemanticsAction.setText, text),
        onSemanticTextInput:
            semantics == null || !semantics.supports(SemanticsAction.setText)
                ? null
                : (request) {
                    final text =
                        request.text ?? (request.clearExisting ? '' : null);
                    if (text != null) {
                      semantics.performAction(SemanticsAction.setText, text);
                    }
                  },
        diagnosticNodeProvider: () => element,
      );
    }

    final metadata = _extractPassiveMetadata(element, semantics: semantics);
    if (!_hasAnyMetadata(metadata)) {
      return null;
    }
    if (_shouldDeferPassiveCandidate(element, semantics)) {
      return null;
    }

    return CockpitTarget(
      registrationId: _registrationId(
        routeName: routeName,
        path: path,
        typeName: typeName,
        bestLabel: metadata.displayLabel,
      ),
      semanticId: metadata.semanticId,
      keyValue: metadata.keyValue,
      text: metadata.text,
      tooltip: metadata.tooltip,
      typeName: typeName,
      routeName: routeName ?? '',
      diagnosticNodeProvider: () => element,
    );
  }

  bool _hasAnyMetadata(_TargetMetadata metadata) {
    return <String?>[
      metadata.text,
      metadata.keyValue,
      metadata.semanticId,
      metadata.tooltip,
    ].any((value) => value != null && value.isNotEmpty);
  }

  bool _isRenderable(Element element) {
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderObject || !renderObject.attached) {
      return false;
    }
    if (renderObject is RenderBox) {
      if (!renderObject.hasSize) {
        return false;
      }
      final size = renderObject.size;
      return size.width > 0 && size.height > 0;
    }
    return true;
  }

  bool _overlapsViewport(Element element, Rect? viewportBounds) {
    final effectiveViewport = _effectiveViewportBoundsForElement(
      element,
      viewportBounds,
    );
    if (effectiveViewport == null) {
      return true;
    }
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    final bounds = origin & renderObject.size;
    return bounds.overlaps(effectiveViewport);
  }

  bool _hasMeaningfulViewportExposure(
    Element element,
    Rect? viewportBounds, {
    required bool strictVisibility,
  }) {
    final effectiveViewport = _effectiveViewportBoundsForElement(
      element,
      viewportBounds,
    );
    if (effectiveViewport == null) {
      return true;
    }
    final renderObject = element.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }
    final origin = renderObject.localToGlobal(Offset.zero);
    final bounds = origin & renderObject.size;
    if (!bounds.overlaps(effectiveViewport)) {
      return false;
    }
    final intersection = bounds.intersect(effectiveViewport);
    if (intersection.isEmpty) {
      return false;
    }
    final widthRatio = intersection.width / bounds.width;
    final heightRatio = intersection.height / bounds.height;
    final requiredHeightRatio = strictVisibility ? 0.8 : 0.5;
    return widthRatio >= 0.5 && heightRatio >= requiredHeightRatio;
  }

  Rect? _effectiveViewportBoundsForElement(
    Element element,
    Rect? rootViewport,
  ) {
    Rect? effectiveViewport = rootViewport;

    void intersectWithViewport(Element candidate) {
      final viewport = _viewportBoundsFor(candidate);
      if (viewport == null) {
        return;
      }
      effectiveViewport = switch (effectiveViewport) {
        null => viewport,
        final Rect current => current.intersect(viewport),
      };
    }

    if (_marksViewportBoundary(element)) {
      intersectWithViewport(element);
    }
    element.visitAncestorElements((ancestor) {
      if (_marksViewportBoundary(ancestor)) {
        intersectWithViewport(ancestor);
      }
      return true;
    });
    return effectiveViewport;
  }

  bool _marksViewportBoundary(Element element) {
    return (element is StatefulElement && element.state is ScrollableState) ||
        policy.marksScrollableBoundary(element);
  }

  bool _isCoveredByExplicitTarget(
    Element element,
    List<Element> explicitElements,
  ) {
    for (final explicitElement in explicitElements) {
      if (identical(element, explicitElement)) {
        return true;
      }

      var isDescendant = false;
      element.visitAncestorElements((ancestor) {
        if (identical(ancestor, explicitElement)) {
          isDescendant = true;
          return false;
        }
        return true;
      });
      if (isDescendant) {
        return true;
      }
    }
    return false;
  }

  bool _shouldDeferSemanticsOnlyCandidate(
    Element element,
    CockpitSemanticsTargetInfo? semantics,
  ) {
    final widget = element.widget;
    final typeName = widget.runtimeType.toString();
    if (typeName.startsWith('_')) {
      return true;
    }
    if (widget is Semantics ||
        widget is Dismissible ||
        widget is Listener ||
        widget is MouseRegion ||
        widget is IgnorePointer ||
        widget is ExcludeSemantics ||
        widget is MergeSemantics ||
        widget is InheritedWidget ||
        widget is ParentDataWidget<ParentData> ||
        widget is Focus) {
      return true;
    }
    if (policy.matchesInteractiveWidget(element)) {
      return false;
    }

    final localKey = _keyValueForElement(element);
    final localSemanticId = _semanticIdForElement(element);
    final localTooltip = _tooltipForElement(element);
    final localText = _passiveTextForElement(element);
    if ((widget is StatelessWidget || widget is StatefulWidget) &&
        localKey != null &&
        localSemanticId == null &&
        localTooltip == null &&
        localText == null) {
      return true;
    }

    final selfSignals = <String?>[
      localKey,
      localSemanticId,
      localTooltip,
      localText,
    ].where((value) => value != null && value.isNotEmpty);

    return selfSignals.isEmpty;
  }

  bool _shouldDeferPassiveCandidate(
    Element element,
    CockpitSemanticsTargetInfo? semantics,
  ) {
    final widget = element.widget;
    final typeName = widget.runtimeType.toString();
    if (typeName.startsWith('_')) {
      return true;
    }
    if (widget is InheritedWidget ||
        widget is ParentDataWidget<ParentData> ||
        widget is Focus ||
        widget is Listener ||
        widget is IgnorePointer ||
        widget is MouseRegion ||
        widget is ExcludeSemantics ||
        widget is MergeSemantics) {
      return true;
    }

    final localSignals = <String?>[
      _keyValueForElement(element),
      _semanticIdForElement(element),
      _tooltipForElement(element),
      _passiveTextForElement(element),
    ].where((value) => value != null && value.isNotEmpty);
    if (localSignals.isNotEmpty) {
      return false;
    }

    return semantics != null;
  }

  CockpitTapHandler? _tapHandlerForElement(Element element) {
    final customHandler = policy.tapHandlerForElement?.call(element);
    if (customHandler != null) {
      return customHandler;
    }
    final widget = element.widget;
    if (widget is ButtonStyleButton) {
      return widget.onPressed;
    }
    if (widget is IconButton) {
      return widget.onPressed;
    }
    if (widget is FloatingActionButton) {
      return widget.onPressed;
    }
    if (widget is InkWell) {
      return widget.onTap;
    }
    if (widget is GestureDetector) {
      return widget.onTap;
    }
    if (widget is ListTile) {
      return widget.onTap;
    }
    if (widget is ActionChip) {
      return widget.onPressed;
    }
    if (widget is ChoiceChip && widget.onSelected != null) {
      return () => widget.onSelected!.call(!widget.selected);
    }
    if (widget is FilterChip && widget.onSelected != null) {
      return () => widget.onSelected!.call(!widget.selected);
    }
    if (widget is InputChip) {
      if (widget.onPressed != null) {
        return widget.onPressed;
      }
      if (widget.onSelected != null) {
        return () => widget.onSelected!.call(!widget.selected);
      }
    }
    if (widget is Checkbox && widget.onChanged != null) {
      return () => widget.onChanged!.call(!(widget.value ?? false));
    }
    if (widget is CheckboxListTile && widget.onChanged != null) {
      return () => widget.onChanged!.call(!(widget.value ?? false));
    }
    if (widget is Switch && widget.onChanged != null) {
      return () => widget.onChanged!.call(!widget.value);
    }
    if (widget is SwitchListTile && widget.onChanged != null) {
      return () => widget.onChanged!.call(!widget.value);
    }
    final editableState = _editableTextStateForElement(element);
    if (editableState != null) {
      final state = editableState;
      return () => state.widget.focusNode.requestFocus();
    }
    return null;
  }

  CockpitEnterTextHandler? _enterTextHandlerForElement(Element element) {
    final customHandler = policy.enterTextHandlerForElement?.call(element);
    if (customHandler != null) {
      return customHandler;
    }
    final textInputHandler = _textInputHandlerForElement(element);
    if (textInputHandler == null) {
      return null;
    }
    return (text) => textInputHandler(CockpitTextInputRequest(text: text));
  }

  CockpitTextInputHandler? _textInputHandlerForElement(Element element) {
    final customHandler = policy.textInputHandlerForElement?.call(element);
    if (customHandler != null) {
      return customHandler;
    }
    final editableState = _editableTextStateForElement(element);
    if (editableState == null) {
      return null;
    }

    final state = editableState;
    return (request) {
      if (request.requestFocus) {
        state.widget.focusNode.requestFocus();
      }
      final currentValue = state.widget.controller.value;
      final nextText = request.text ?? (request.clearExisting ? '' : null);
      final resolvedText = nextText ?? currentValue.text;
      final selectionBase = request.selectionBase;
      final selectionExtent = request.selectionExtent ?? selectionBase;
      final selection = selectionBase == null
          ? (request.text != null || request.clearExisting
              ? TextSelection.collapsed(offset: resolvedText.length)
              : currentValue.selection)
          : TextSelection(
              baseOffset: selectionBase.clamp(0, resolvedText.length),
              extentOffset: (selectionExtent ?? selectionBase).clamp(
                0,
                resolvedText.length,
              ),
            );
      final shouldUpdateValue =
          request.hasEditingMutation || request.requestFocus;
      if (shouldUpdateValue) {
        final value = currentValue.copyWith(
          text: resolvedText,
          selection: selection,
          composing: TextRange.empty,
        );
        state.userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
      }
      final action = request.inputAction;
      if (action != null) {
        state.performAction(_mapTextInputAction(action));
      }
    };
  }

  TextInputAction _mapTextInputAction(CockpitTextInputAction action) {
    return switch (action) {
      CockpitTextInputAction.done => TextInputAction.done,
      CockpitTextInputAction.next => TextInputAction.next,
      CockpitTextInputAction.previous => TextInputAction.previous,
      CockpitTextInputAction.search => TextInputAction.search,
      CockpitTextInputAction.send => TextInputAction.send,
      CockpitTextInputAction.go => TextInputAction.go,
      CockpitTextInputAction.newline => TextInputAction.newline,
      CockpitTextInputAction.none => TextInputAction.none,
      CockpitTextInputAction.unspecified => TextInputAction.unspecified,
      CockpitTextInputAction.continueAction => TextInputAction.continueAction,
      CockpitTextInputAction.emergencyCall => TextInputAction.emergencyCall,
      CockpitTextInputAction.join => TextInputAction.join,
      CockpitTextInputAction.route => TextInputAction.route,
    };
  }

  CockpitLongPressHandler? _longPressHandlerForElement(Element element) {
    final customHandler = policy.longPressHandlerForElement?.call(element);
    if (customHandler != null) {
      return customHandler;
    }
    final widget = element.widget;
    if (widget is InkWell) {
      return widget.onLongPress;
    }
    if (widget is GestureDetector) {
      return widget.onLongPress;
    }
    if (widget is ListTile) {
      return widget.onLongPress;
    }
    return null;
  }

  CockpitDoubleTapHandler? _doubleTapHandlerForElement(Element element) {
    final customHandler = policy.doubleTapHandlerForElement?.call(element);
    if (customHandler != null) {
      return customHandler;
    }
    final widget = element.widget;
    if (widget is InkWell) {
      return widget.onDoubleTap;
    }
    if (widget is GestureDetector) {
      return widget.onDoubleTap;
    }
    return null;
  }

  EditableTextState? _editableTextStateForElement(Element element) {
    if (element is StatefulElement && element.state is EditableTextState) {
      return element.state as EditableTextState;
    }

    final widget = element.widget;
    if (widget is! TextField &&
        widget is! TextFormField &&
        widget is! EditableText) {
      return null;
    }

    EditableTextState? editableState;

    void visit(Element candidate) {
      if (editableState != null || !candidate.mounted) {
        return;
      }
      if (candidate is StatefulElement &&
          candidate.state is EditableTextState) {
        editableState = candidate.state as EditableTextState;
        return;
      }
      candidate.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    return editableState;
  }

  _TargetMetadata _extractInteractiveMetadata(
    Element element, {
    required CockpitSemanticsTargetInfo? semantics,
  }) {
    final text = _firstNonEmpty(<String?>[
      policy.extractText?.call(element),
      semantics?.label,
      semantics?.value,
      semantics?.hint,
      _interactiveTextForElement(element),
      _passiveTextForElement(element),
      _inputLabelForElement(element),
    ]);
    return _TargetMetadata(
      text: text,
      keyValue: _keyValueForElement(element),
      semanticId: _firstNonEmpty(<String?>[
        semantics?.identifier,
        _semanticIdForElement(element),
      ]),
      tooltip: _firstNonEmpty(<String?>[
        semantics?.tooltip,
        _tooltipForElement(element),
      ]),
    );
  }

  _TargetMetadata _extractPassiveMetadata(
    Element element, {
    required CockpitSemanticsTargetInfo? semantics,
  }) {
    final selfText = _passiveTextForElement(element);
    return _TargetMetadata(
      text: selfText,
      keyValue: _keyValueForElement(element),
      semanticId: _firstNonEmpty(<String?>[
        semantics?.identifier,
        _semanticIdForElement(element),
      ]),
      tooltip: _firstNonEmpty(<String?>[
        semantics?.tooltip,
        _tooltipForElement(element),
      ]),
    );
  }

  String? _interactiveTextForElement(Element element) {
    return _firstNonEmpty(<String?>[
      policy.extractText?.call(element),
      _textFromWidget(element.widget),
      _collectDescendantText(element),
      _inputLabelForElement(element),
    ]);
  }

  String? _passiveTextForElement(Element element) {
    return _firstNonEmpty(<String?>[
      policy.extractText?.call(element),
      _textFromWidget(element.widget),
      _textFromSemanticsWidget(element.widget),
      _inputLabelFromWidget(element.widget),
    ]);
  }

  String? _textFromSemanticsWidget(Widget widget) {
    if (widget is! Semantics) {
      return null;
    }
    return _firstNonEmpty(<String?>[
      _normalizeText(widget.properties.label),
      _normalizeText(widget.properties.value),
      _normalizeText(widget.properties.hint),
    ]);
  }

  String? _textFromWidget(Widget widget) {
    if (widget is Text) {
      return _normalizeText(widget.data ?? widget.textSpan?.toPlainText());
    }
    if (widget is RichText) {
      return _normalizeText(widget.text.toPlainText());
    }
    if (widget is EditableText) {
      return _normalizeText(widget.controller.text);
    }
    if (widget is TextField) {
      return _normalizeText(
        widget.controller?.text.isNotEmpty == true
            ? widget.controller?.text
            : widget.decoration?.labelText ?? widget.decoration?.hintText,
      );
    }
    return null;
  }

  String? _inputLabelForElement(Element element) {
    final selfLabel = _inputLabelFromWidget(element.widget);
    if (selfLabel != null) {
      return selfLabel;
    }

    String? label;
    element.visitAncestorElements((ancestor) {
      label = _inputLabelFromWidget(ancestor.widget);
      return label == null;
    });
    return label;
  }

  String? _inputLabelFromWidget(Widget widget) {
    if (widget is TextField) {
      return _normalizeText(
        widget.decoration?.labelText ?? widget.decoration?.hintText,
      );
    }
    return null;
  }

  String? _stableKeyValue(Key? key) {
    final value = switch (key) {
      ValueKey<Object?>(value: final value) => _normalizeText(
          value?.toString(),
        ),
      ObjectKey(value: final value) => _normalizeText(value.toString()),
      _ => null,
    };
    if (value == null || value.startsWith('_')) {
      return null;
    }
    return value;
  }

  String? _semanticIdForElement(Element element) {
    final customSemanticId = _normalizeText(
      policy.extractSemanticId?.call(element),
    );
    if (customSemanticId != null) {
      return customSemanticId;
    }
    final selfSemantic = _semanticIdFromWidget(element.widget);
    if (selfSemantic != null) {
      return selfSemantic;
    }

    String? semanticId;
    element.visitAncestorElements((ancestor) {
      final customAncestorSemanticId = _normalizeText(
        policy.extractSemanticId?.call(ancestor),
      );
      if (customAncestorSemanticId != null) {
        semanticId = customAncestorSemanticId;
        return false;
      }
      semanticId = _semanticIdFromWidget(ancestor.widget);
      return semanticId == null;
    });
    return semanticId;
  }

  String? _semanticIdFromWidget(Widget widget) {
    if (widget is Semantics) {
      return _firstNonEmpty(<String?>[
        _normalizeText(widget.properties.identifier),
        _normalizeText(widget.properties.label),
        _normalizeText(widget.properties.hint),
      ]);
    }
    return null;
  }

  String? _tooltipForElement(Element element) {
    final customTooltip = _normalizeText(policy.extractTooltip?.call(element));
    if (customTooltip != null) {
      return customTooltip;
    }
    final selfTooltip = _tooltipFromWidget(element.widget);
    if (selfTooltip != null) {
      return selfTooltip;
    }

    String? tooltip;
    element.visitAncestorElements((ancestor) {
      final customAncestorTooltip = _normalizeText(
        policy.extractTooltip?.call(ancestor),
      );
      if (customAncestorTooltip != null) {
        tooltip = customAncestorTooltip;
        return false;
      }
      tooltip = _tooltipFromWidget(ancestor.widget);
      return tooltip == null;
    });
    return tooltip;
  }

  String? _keyValueForElement(Element element) {
    final customKey = _normalizeText(policy.extractKey?.call(element));
    if (customKey != null) {
      return customKey;
    }
    return _stableKeyValue(element.widget.key);
  }

  String? _tooltipFromWidget(Widget widget) {
    if (widget is Tooltip) {
      return _normalizeText(widget.message);
    }
    if (widget is Semantics) {
      return _normalizeText(widget.properties.tooltip);
    }
    return null;
  }

  String? _collectDescendantText(Element element) {
    final values = <String>[];

    void visit(Element child) {
      if (values.length >= 3) {
        return;
      }
      final text = _textFromWidget(child.widget);
      if (text != null && text.isNotEmpty) {
        values.add(text);
        return;
      }
      child.visitChildElements(visit);
    }

    element.visitChildElements(visit);
    if (values.isEmpty) {
      return null;
    }
    return values.join(' ').trim();
  }

  String _registrationId({
    required String? routeName,
    required String path,
    required String typeName,
    required String? bestLabel,
  }) {
    final routeSegment = _slugify(routeName ?? 'unknown');
    final typeSegment = _slugify(typeName);
    final labelSegment = _slugify(bestLabel ?? typeName);
    return 'native.$routeSegment.$typeSegment.$labelSegment.$path';
  }

  String _slugify(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.toLowerCase().codeUnits) {
      final isAlphaNumeric = (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 97 && codeUnit <= 122);
      if (isAlphaNumeric) {
        buffer.writeCharCode(codeUnit);
      } else if (buffer.isEmpty || buffer.toString().endsWith('-')) {
        continue;
      } else {
        buffer.write('-');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp(r'-+$'), '');
    return slug.isEmpty ? 'value' : slug;
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final normalized = _normalizeText(candidate);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

final class _TargetMetadata {
  const _TargetMetadata({
    this.text,
    this.keyValue,
    this.semanticId,
    this.tooltip,
  });

  final String? text;
  final String? keyValue;
  final String? semanticId;
  final String? tooltip;

  String? get displayLabel => text ?? semanticId ?? tooltip ?? keyValue;
}
