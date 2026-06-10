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
  pressVolumeUp,
  pressVolumeDown,
  pressVolumeMute,
  activateWindow,
  terminateApp,
  installApp,
  uninstallApp,
  clearAppData,
  dismissSystemDialog,
  dismissKeyboard,
  grantPermission,
  revokePermission,
  resetPermission,
  preparePermissions,
  openUrl,
  openSystemSettings,
  setAppearance,
  setContentSize,
  setLocation,
  setOrientation,
  setNetworkSpeed,
  setNetworkDelay,
  setStatusBar,
  clearStatusBar,
  expandNotifications,
  expandQuickSettings,
  collapseSystemUi,
  postNotification,
  clearNotifications,
  tapNotification,
  recoverToApp,
  resolveBlockers,
  stabilizeForScreenshot,
  setClipboard,
  getClipboard,
  pushFile,
  pullFile,
  addMedia,
  captureScreenshot,
  startRecording,
  stopRecording,
  readUiTree,
  readProcessList,
  readWindows,
  readSystemState,
  readDeviceInfo,
  readFocusState,
  readNotificationState,
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

enum CockpitSystemControlParameterType {
  string,
  integer,
  number,
  boolean,
  stringList;

  static CockpitSystemControlParameterType fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitSystemControlGroups {
  const CockpitSystemControlGroups._();

  static const input = 'input';
  static const lifecycle = 'lifecycle';
  static const permissions = 'permissions';
  static const nativeDialog = 'nativeDialog';
  static const navigation = 'navigation';
  static const settings = 'settings';
  static const deviceState = 'deviceState';
  static const network = 'network';
  static const systemUi = 'systemUi';
  static const notifications = 'notifications';
  static const clipboard = 'clipboard';
  static const files = 'files';
  static const media = 'media';
  static const evidence = 'evidence';
  static const inspection = 'inspection';
  static const shell = 'shell';
}

List<CockpitSystemControlCapability> cockpitCompleteSystemControlCapabilities(
  List<CockpitSystemControlCapability> capabilities, {
  required CockpitPlaneKind plane,
  required CockpitSystemControlAvailability availability,
  required String strategy,
  List<String> requires = const <String>[],
  List<String> limitations = const <String>[],
}) {
  final declared = capabilities.map((capability) => capability.action).toSet();
  return <CockpitSystemControlCapability>[
    ...capabilities,
    for (final action in CockpitSystemControlAction.values)
      if (!declared.contains(action))
        CockpitSystemControlCapability(
          action: action,
          plane: plane,
          availability: availability,
          strategy: strategy,
          requires: requires,
          limitations: limitations,
        ),
  ];
}

final class CockpitSystemControlParameter {
  const CockpitSystemControlParameter({
    required this.name,
    required this.valueType,
    this.required = false,
    this.allowedValues = const <String>[],
    this.minimum,
    this.maximum,
    this.description,
  });

  final String name;
  final CockpitSystemControlParameterType valueType;
  final bool required;
  final List<String> allowedValues;
  final num? minimum;
  final num? maximum;
  final String? description;

  static const ListEquality<String> _stringListEquality =
      ListEquality<String>();

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'required': required,
    'valueType': valueType.name,
    if (allowedValues.isNotEmpty) 'allowedValues': allowedValues,
    if (minimum != null) 'minimum': minimum,
    if (maximum != null) 'maximum': maximum,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };

  factory CockpitSystemControlParameter.fromJson(Map<String, Object?> json) {
    return CockpitSystemControlParameter(
      name: json['name']! as String,
      required: json['required'] as bool? ?? false,
      valueType: CockpitSystemControlParameterType.fromJson(json['valueType']),
      allowedValues:
          (json['allowedValues'] as List<Object?>? ?? const <Object?>[])
              .cast<String>()
              .toList(growable: false),
      minimum: json['minimum'] as num?,
      maximum: json['maximum'] as num?,
      description: json['description'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSystemControlParameter &&
            other.name == name &&
            other.valueType == valueType &&
            other.required == required &&
            _stringListEquality.equals(other.allowedValues, allowedValues) &&
            other.minimum == minimum &&
            other.maximum == maximum &&
            other.description == description;
  }

  @override
  int get hashCode => Object.hash(
    name,
    valueType,
    required,
    _stringListEquality.hash(allowedValues),
    minimum,
    maximum,
    description,
  );
}

final class CockpitSystemControlCapability {
  const CockpitSystemControlCapability({
    required this.action,
    required this.plane,
    required this.availability,
    required this.strategy,
    this.groups = const <String>[],
    this.requires = const <String>[],
    this.limitations = const <String>[],
    this.parameters = const <CockpitSystemControlParameter>[],
    this.fallbackActions = const <CockpitSystemControlAction>[],
  });

  final CockpitSystemControlAction action;
  final CockpitPlaneKind plane;
  final CockpitSystemControlAvailability availability;
  final String strategy;
  final List<String> groups;
  final List<String> requires;
  final List<String> limitations;
  final List<CockpitSystemControlParameter> parameters;
  final List<CockpitSystemControlAction> fallbackActions;

  List<String> get effectiveGroups {
    if (groups.isNotEmpty) {
      return groups;
    }
    return _defaultGroupsForAction(action);
  }

  static const ListEquality<String> _stringListEquality =
      ListEquality<String>();
  static const ListEquality<CockpitSystemControlParameter>
  _parameterListEquality = ListEquality<CockpitSystemControlParameter>();
  static const ListEquality<CockpitSystemControlAction> _actionListEquality =
      ListEquality<CockpitSystemControlAction>();

  Map<String, Object?> toJson() => <String, Object?>{
    'action': action.name,
    'plane': plane.name,
    'availability': availability.name,
    'strategy': strategy,
    if (effectiveGroups.isNotEmpty) 'groups': effectiveGroups,
    if (requires.isNotEmpty) 'requires': requires,
    if (limitations.isNotEmpty) 'limitations': limitations,
    if (parameters.isNotEmpty)
      'parameters': parameters
          .map((parameter) => parameter.toJson())
          .toList(growable: false),
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
      groups: (json['groups'] as List<Object?>? ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      requires: (json['requires'] as List<Object?>? ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      limitations: (json['limitations'] as List<Object?>? ?? const <Object?>[])
          .cast<String>()
          .toList(growable: false),
      parameters: (json['parameters'] as List<Object?>? ?? const <Object?>[])
          .map((value) {
            return CockpitSystemControlParameter.fromJson(
              (value as Map<Object?, Object?>).cast<String, Object?>(),
            );
          })
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
            _stringListEquality.equals(
              other.effectiveGroups,
              effectiveGroups,
            ) &&
            _stringListEquality.equals(other.requires, requires) &&
            _stringListEquality.equals(other.limitations, limitations) &&
            _parameterListEquality.equals(other.parameters, parameters) &&
            _actionListEquality.equals(other.fallbackActions, fallbackActions);
  }

  @override
  int get hashCode => Object.hash(
    action,
    plane,
    availability,
    strategy,
    _stringListEquality.hash(effectiveGroups),
    _stringListEquality.hash(requires),
    _stringListEquality.hash(limitations),
    _parameterListEquality.hash(parameters),
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
    'actionGroups': actionGroups,
    'capabilities': capabilities
        .map((capability) => capability.toJson())
        .toList(growable: false),
  };

  Map<String, Object?> get actionGroups {
    final groups = <String, Map<String, List<String>>>{};
    for (final capability in capabilities) {
      for (final group in capability.effectiveGroups) {
        final bucket = groups.putIfAbsent(
          group,
          () => <String, List<String>>{
            'available': <String>[],
            'blocked': <String>[],
            'unsupported': <String>[],
          },
        );
        bucket[capability.availability.name]!.add(capability.action.name);
      }
    }

    return <String, Object?>{
      for (final entry in groups.entries)
        entry.key: <String, Object?>{
          for (final bucket in entry.value.entries)
            if (bucket.value.isNotEmpty) bucket.key: bucket.value,
        },
    };
  }

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

List<String> _defaultGroupsForAction(CockpitSystemControlAction action) {
  return switch (action) {
    CockpitSystemControlAction.tap ||
    CockpitSystemControlAction.longPress ||
    CockpitSystemControlAction.drag ||
    CockpitSystemControlAction.typeText ||
    CockpitSystemControlAction.pressKey => const <String>[
      CockpitSystemControlGroups.input,
    ],
    CockpitSystemControlAction.pressBack ||
    CockpitSystemControlAction.pressHome => const <String>[
      CockpitSystemControlGroups.input,
      CockpitSystemControlGroups.navigation,
    ],
    CockpitSystemControlAction.pressVolumeUp ||
    CockpitSystemControlAction.pressVolumeDown ||
    CockpitSystemControlAction.pressVolumeMute => const <String>[
      CockpitSystemControlGroups.deviceState,
    ],
    CockpitSystemControlAction.activateWindow ||
    CockpitSystemControlAction.terminateApp ||
    CockpitSystemControlAction.installApp ||
    CockpitSystemControlAction.uninstallApp ||
    CockpitSystemControlAction.clearAppData => const <String>[
      CockpitSystemControlGroups.lifecycle,
    ],
    CockpitSystemControlAction.dismissSystemDialog => const <String>[
      CockpitSystemControlGroups.nativeDialog,
      CockpitSystemControlGroups.permissions,
    ],
    CockpitSystemControlAction.dismissKeyboard => const <String>[
      CockpitSystemControlGroups.input,
      CockpitSystemControlGroups.nativeDialog,
    ],
    CockpitSystemControlAction.grantPermission ||
    CockpitSystemControlAction.revokePermission ||
    CockpitSystemControlAction.resetPermission ||
    CockpitSystemControlAction.preparePermissions => const <String>[
      CockpitSystemControlGroups.permissions,
    ],
    CockpitSystemControlAction.openUrl => const <String>[
      CockpitSystemControlGroups.navigation,
    ],
    CockpitSystemControlAction.openSystemSettings ||
    CockpitSystemControlAction.setAppearance ||
    CockpitSystemControlAction.setContentSize => const <String>[
      CockpitSystemControlGroups.settings,
    ],
    CockpitSystemControlAction.setLocation ||
    CockpitSystemControlAction.setOrientation ||
    CockpitSystemControlAction.setStatusBar ||
    CockpitSystemControlAction.clearStatusBar => const <String>[
      CockpitSystemControlGroups.deviceState,
    ],
    CockpitSystemControlAction.setNetworkSpeed ||
    CockpitSystemControlAction.setNetworkDelay => const <String>[
      CockpitSystemControlGroups.network,
    ],
    CockpitSystemControlAction.expandNotifications ||
    CockpitSystemControlAction.postNotification ||
    CockpitSystemControlAction.clearNotifications ||
    CockpitSystemControlAction.tapNotification ||
    CockpitSystemControlAction.readNotificationState => const <String>[
      CockpitSystemControlGroups.notifications,
      CockpitSystemControlGroups.systemUi,
    ],
    CockpitSystemControlAction.expandQuickSettings ||
    CockpitSystemControlAction.collapseSystemUi ||
    CockpitSystemControlAction.recoverToApp ||
    CockpitSystemControlAction.resolveBlockers ||
    CockpitSystemControlAction.stabilizeForScreenshot => const <String>[
      CockpitSystemControlGroups.systemUi,
      CockpitSystemControlGroups.navigation,
    ],
    CockpitSystemControlAction.setClipboard ||
    CockpitSystemControlAction.getClipboard => const <String>[
      CockpitSystemControlGroups.clipboard,
    ],
    CockpitSystemControlAction.pushFile ||
    CockpitSystemControlAction.pullFile => const <String>[
      CockpitSystemControlGroups.files,
    ],
    CockpitSystemControlAction.addMedia => const <String>[
      CockpitSystemControlGroups.files,
      CockpitSystemControlGroups.media,
    ],
    CockpitSystemControlAction.captureScreenshot ||
    CockpitSystemControlAction.startRecording ||
    CockpitSystemControlAction.stopRecording => const <String>[
      CockpitSystemControlGroups.evidence,
    ],
    CockpitSystemControlAction.readUiTree ||
    CockpitSystemControlAction.readProcessList ||
    CockpitSystemControlAction.readWindows ||
    CockpitSystemControlAction.readSystemState ||
    CockpitSystemControlAction.readDeviceInfo ||
    CockpitSystemControlAction.readFocusState => const <String>[
      CockpitSystemControlGroups.inspection,
    ],
    CockpitSystemControlAction.runShell => const <String>[
      CockpitSystemControlGroups.shell,
    ],
  };
}
