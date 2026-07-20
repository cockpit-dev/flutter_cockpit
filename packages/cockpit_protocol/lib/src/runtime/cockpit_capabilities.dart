import 'package:collection/collection.dart';

import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import 'cockpit_capability_profile.dart';

final class CockpitCapabilities {
  CockpitCapabilities({
    required this.platform,
    required this.transportType,
    required this.supportsInAppControl,
    required this.supportsFlutterViewCapture,
    required this.supportsNativeScreenCapture,
    required this.supportsHostAutomation,
    List<CockpitCommandType> supportedCommands = const <CockpitCommandType>[],
    List<CockpitLocatorKind> supportedLocatorStrategies =
        const <CockpitLocatorKind>[],
    this.capabilityProfile,
  }) : supportedCommands = List.unmodifiable(supportedCommands),
       supportedLocatorStrategies = List.unmodifiable(
         supportedLocatorStrategies,
       );

  final String platform;
  final String transportType;
  final bool supportsInAppControl;
  final bool supportsFlutterViewCapture;
  final bool supportsNativeScreenCapture;
  final bool supportsHostAutomation;
  final List<CockpitCommandType> supportedCommands;
  final List<CockpitLocatorKind> supportedLocatorStrategies;
  final CockpitCapabilityProfile? capabilityProfile;

  static const ListEquality<CockpitCommandType> _commandListEquality =
      ListEquality<CockpitCommandType>();
  static const ListEquality<CockpitLocatorKind> _locatorListEquality =
      ListEquality<CockpitLocatorKind>();

  Map<String, Object?> toJson() => {
    'platform': platform,
    'transportType': transportType,
    'supportsInAppControl': supportsInAppControl,
    'supportsFlutterViewCapture': supportsFlutterViewCapture,
    'supportsNativeScreenCapture': supportsNativeScreenCapture,
    'supportsHostAutomation': supportsHostAutomation,
    'supportedCommands': supportedCommands
        .map((command) => command.name)
        .toList(),
    'supportedLocatorStrategies': supportedLocatorStrategies
        .map((kind) => kind.name)
        .toList(),
    if (capabilityProfile != null)
      'capabilityProfile': capabilityProfile!.toJson(),
  };

  factory CockpitCapabilities.fromJson(Map<String, Object?> json) {
    final capabilityProfileJson =
        json['capabilityProfile'] as Map<Object?, Object?>?;
    return CockpitCapabilities(
      platform: json['platform']! as String,
      transportType: json['transportType']! as String,
      supportsInAppControl: json['supportsInAppControl']! as bool,
      supportsFlutterViewCapture: json['supportsFlutterViewCapture']! as bool,
      supportsNativeScreenCapture: json['supportsNativeScreenCapture']! as bool,
      supportsHostAutomation: json['supportsHostAutomation']! as bool,
      supportedCommands:
          (json['supportedCommands'] as List<Object?>? ?? const <Object?>[])
              .map(CockpitCommandType.fromJson)
              .toList(growable: false),
      supportedLocatorStrategies:
          (json['supportedLocatorStrategies'] as List<Object?>? ??
                  const <Object?>[])
              .map(CockpitLocatorKind.fromJson)
              .toList(growable: false),
      capabilityProfile: capabilityProfileJson == null
          ? null
          : CockpitCapabilityProfile.fromJson(
              Map<String, Object?>.from(capabilityProfileJson),
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitCapabilities &&
            other.platform == platform &&
            other.transportType == transportType &&
            other.supportsInAppControl == supportsInAppControl &&
            other.supportsFlutterViewCapture == supportsFlutterViewCapture &&
            other.supportsNativeScreenCapture == supportsNativeScreenCapture &&
            other.supportsHostAutomation == supportsHostAutomation &&
            other.capabilityProfile == capabilityProfile &&
            _commandListEquality.equals(
              other.supportedCommands,
              supportedCommands,
            ) &&
            _locatorListEquality.equals(
              other.supportedLocatorStrategies,
              supportedLocatorStrategies,
            );
  }

  @override
  int get hashCode => Object.hash(
    platform,
    transportType,
    supportsInAppControl,
    supportsFlutterViewCapture,
    supportsNativeScreenCapture,
    supportsHostAutomation,
    capabilityProfile,
    _commandListEquality.hash(supportedCommands),
    _locatorListEquality.hash(supportedLocatorStrategies),
  );
}
