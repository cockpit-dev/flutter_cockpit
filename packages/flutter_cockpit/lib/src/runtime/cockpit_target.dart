import 'package:collection/collection.dart';

import '../control/cockpit_command_type.dart';
import 'cockpit_snapshot.dart';
import 'cockpit_target_geometry.dart';
import 'cockpit_text_input_request.dart';

typedef CockpitTapHandler = void Function();
typedef CockpitLongPressHandler = void Function();
typedef CockpitDoubleTapHandler = void Function();
typedef CockpitEnterTextHandler = void Function(String text);
typedef CockpitTextInputHandler = void Function(
    CockpitTextInputRequest request);
typedef CockpitSemanticActionHandler = void Function();
typedef CockpitDiagnosticNodeProvider = Object? Function();
typedef CockpitTargetGeometryProvider = CockpitTargetGeometry? Function();

final class CockpitTarget {
  const CockpitTarget({
    required this.registrationId,
    this.cockpitId,
    this.semanticId,
    this.keyValue,
    this.text,
    this.tooltip,
    this.typeName,
    required this.routeName,
    this.isVisible = true,
    this.supportedCommands = const <CockpitCommandType>{},
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onEnterText,
    this.onTextInput,
    this.onSemanticTap,
    this.onSemanticLongPress,
    this.onSemanticEnterText,
    this.onSemanticTextInput,
    this.onSemanticShowOnScreen,
    this.onSemanticIncrease,
    this.onSemanticDecrease,
    this.onSemanticDismiss,
    this.diagnosticNodeProvider,
    this.geometryProvider,
  });

  final String registrationId;
  final String? cockpitId;
  final String? semanticId;
  final String? keyValue;
  final String? text;
  final String? tooltip;
  final String? typeName;
  final String routeName;
  final bool isVisible;
  final Set<CockpitCommandType> supportedCommands;
  final CockpitTapHandler? onTap;
  final CockpitLongPressHandler? onLongPress;
  final CockpitDoubleTapHandler? onDoubleTap;
  final CockpitEnterTextHandler? onEnterText;
  final CockpitTextInputHandler? onTextInput;
  final CockpitTapHandler? onSemanticTap;
  final CockpitLongPressHandler? onSemanticLongPress;
  final CockpitEnterTextHandler? onSemanticEnterText;
  final CockpitTextInputHandler? onSemanticTextInput;
  final CockpitSemanticActionHandler? onSemanticShowOnScreen;
  final CockpitSemanticActionHandler? onSemanticIncrease;
  final CockpitSemanticActionHandler? onSemanticDecrease;
  final CockpitSemanticActionHandler? onSemanticDismiss;
  final CockpitDiagnosticNodeProvider? diagnosticNodeProvider;
  final CockpitTargetGeometryProvider? geometryProvider;

  static const SetEquality<CockpitCommandType> _commandSetEquality =
      SetEquality<CockpitCommandType>();

  String? get displayLabel =>
      cockpitId ?? semanticId ?? text ?? tooltip ?? keyValue ?? typeName;

  CockpitSnapshotTarget toSnapshotTarget() {
    return CockpitSnapshotTarget(
      registrationId: registrationId,
      cockpitId: cockpitId,
      semanticId: semanticId,
      keyValue: keyValue,
      text: text,
      tooltip: tooltip,
      typeName: typeName,
      routeName: routeName,
      supportedCommands: supportedCommands.toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitTarget &&
            other.registrationId == registrationId &&
            other.cockpitId == cockpitId &&
            other.semanticId == semanticId &&
            other.keyValue == keyValue &&
            other.text == text &&
            other.tooltip == tooltip &&
            other.typeName == typeName &&
            other.routeName == routeName &&
            other.isVisible == isVisible &&
            other.diagnosticNodeProvider == diagnosticNodeProvider &&
            _commandSetEquality.equals(
              other.supportedCommands,
              supportedCommands,
            );
  }

  @override
  int get hashCode => Object.hash(
        registrationId,
        cockpitId,
        semanticId,
        keyValue,
        text,
        tooltip,
        typeName,
        routeName,
        isVisible,
        diagnosticNodeProvider,
        _commandSetEquality.hash(supportedCommands),
      );
}
