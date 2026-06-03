import 'package:collection/collection.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

enum CockpitSystemControlAction {
  tap,
  longPress,
  drag,
  typeText,
  pressKey,
  pressBack,
  pressHome,
  activateWindow,
  terminateApp,
  dismissSystemDialog,
  grantPermission,
  openUrl,
  setAppearance,
  setContentSize,
  setLocation,
  setClipboard,
  getClipboard,
  captureScreenshot,
  startRecording,
  stopRecording,
  readUiTree,
  readSystemState,
  runShell;

  static CockpitSystemControlAction fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

enum CockpitSystemControlAvailability {
  available,
  blocked,
  unsupported;

  static CockpitSystemControlAvailability fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitSystemControlCapability {
  const CockpitSystemControlCapability({
    required this.action,
    required this.plane,
    required this.availability,
    required this.strategy,
    this.requires = const <String>[],
    this.limitations = const <String>[],
    this.fallbackActions = const <CockpitSystemControlAction>[],
  });

  final CockpitSystemControlAction action;
  final CockpitPlaneKind plane;
  final CockpitSystemControlAvailability availability;
  final String strategy;
  final List<String> requires;
  final List<String> limitations;
  final List<CockpitSystemControlAction> fallbackActions;

  static const ListEquality<String> _stringListEquality =
      ListEquality<String>();
  static const ListEquality<CockpitSystemControlAction> _actionListEquality =
      ListEquality<CockpitSystemControlAction>();

  Map<String, Object?> toJson() => <String, Object?>{
    'action': action.name,
    'plane': plane.name,
    'availability': availability.name,
    'strategy': strategy,
    if (requires.isNotEmpty) 'requires': requires,
    if (limitations.isNotEmpty) 'limitations': limitations,
    if (fallbackActions.isNotEmpty)
      'fallbackActions': fallbackActions
          .map((action) => action.name)
          .toList(growable: false),
  };

  factory CockpitSystemControlCapability.fromJson(Map<String, Object?> json) {
    return CockpitSystemControlCapability(
      action: CockpitSystemControlAction.fromJson(json['action']),
      plane: CockpitPlaneKind.fromJson(json['plane']),
      availability: CockpitSystemControlAvailability.fromJson(
        json['availability'],
      ),
      strategy: json['strategy']! as String,
      requires: (json['requires'] as List<Object?>? ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      limitations: (json['limitations'] as List<Object?>? ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      fallbackActions:
          (json['fallbackActions'] as List<Object?>? ?? const <Object?>[])
              .map(CockpitSystemControlAction.fromJson)
              .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSystemControlCapability &&
            other.action == action &&
            other.plane == plane &&
            other.availability == availability &&
            other.strategy == strategy &&
            _stringListEquality.equals(other.requires, requires) &&
            _stringListEquality.equals(other.limitations, limitations) &&
            _actionListEquality.equals(other.fallbackActions, fallbackActions);
  }

  @override
  int get hashCode => Object.hash(
    action,
    plane,
    availability,
    strategy,
    _stringListEquality.hash(requires),
    _stringListEquality.hash(limitations),
    _actionListEquality.hash(fallbackActions),
  );
}

final class CockpitSystemControlProfile {
  const CockpitSystemControlProfile({
    required this.platform,
    required this.deviceId,
    this.appId,
    this.processId,
    required this.adapter,
    required this.preferredPlane,
    required this.fallbackOrder,
    required this.capabilities,
    required this.recommendedNextStep,
  });

  final String platform;
  final String? deviceId;
  final String? appId;
  final int? processId;
  final String adapter;
  final CockpitPlaneKind preferredPlane;
  final List<CockpitPlaneKind> fallbackOrder;
  final List<CockpitSystemControlCapability> capabilities;
  final String recommendedNextStep;

  static const ListEquality<CockpitPlaneKind> _planeListEquality =
      ListEquality<CockpitPlaneKind>();
  static const ListEquality<CockpitSystemControlCapability>
  _capabilityListEquality = ListEquality<CockpitSystemControlCapability>();

  List<CockpitSystemControlAction> get availableActions {
    return _actionsFor(CockpitSystemControlAvailability.available);
  }

  List<CockpitSystemControlAction> get blockedActions {
    return _actionsFor(CockpitSystemControlAvailability.blocked);
  }

  List<CockpitSystemControlAction> get unsupportedActions {
    return _actionsFor(CockpitSystemControlAvailability.unsupported);
  }

  CockpitSystemControlCapability? capabilityFor(
    CockpitSystemControlAction action,
  ) {
    for (final capability in capabilities) {
      if (capability.action == action) {
        return capability;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'platform': platform,
    if (deviceId != null) 'deviceId': deviceId,
    if (appId != null) 'appId': appId,
    if (processId != null) 'processId': processId,
    'adapter': adapter,
    'preferredPlane': preferredPlane.name,
    'fallbackOrder': fallbackOrder
        .map((plane) => plane.name)
        .toList(growable: false),
    'recommendedNextStep': recommendedNextStep,
    'availableActions': availableActions
        .map((action) => action.name)
        .toList(growable: false),
    'blockedActions': blockedActions
        .map((action) => action.name)
        .toList(growable: false),
    'unsupportedActions': unsupportedActions
        .map((action) => action.name)
        .toList(growable: false),
    'capabilities': capabilities
        .map((capability) => capability.toJson())
        .toList(growable: false),
  };

  List<CockpitSystemControlAction> _actionsFor(
    CockpitSystemControlAvailability availability,
  ) {
    return capabilities
        .where((capability) => capability.availability == availability)
        .map((capability) => capability.action)
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSystemControlProfile &&
            other.platform == platform &&
            other.deviceId == deviceId &&
            other.appId == appId &&
            other.processId == processId &&
            other.adapter == adapter &&
            other.preferredPlane == preferredPlane &&
            _planeListEquality.equals(other.fallbackOrder, fallbackOrder) &&
            _capabilityListEquality.equals(other.capabilities, capabilities) &&
            other.recommendedNextStep == recommendedNextStep;
  }

  @override
  int get hashCode => Object.hash(
    platform,
    deviceId,
    appId,
    processId,
    adapter,
    preferredPlane,
    _planeListEquality.hash(fallbackOrder),
    _capabilityListEquality.hash(capabilities),
    recommendedNextStep,
  );
}
