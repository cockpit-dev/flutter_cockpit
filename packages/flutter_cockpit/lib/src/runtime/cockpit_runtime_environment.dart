// ignore_for_file: deprecated_member_use

import 'dart:io';

import '../model/cockpit_environment.dart';

const String _flutterCockpitFlutterVersionFromEnvironment =
    String.fromEnvironment('FLUTTER_PILOT_FLUTTER_VERSION');

CockpitEnvironment? resolveCockpitRuntimeEnvironment({
  required String platform,
  String? configuredFlutterVersion,
  String? runtimeVersion,
}) {
  final flutterVersion = _normalizeVersion(configuredFlutterVersion) ??
      _normalizeVersion(_flutterCockpitFlutterVersionFromEnvironment);
  final dartVersion = _parseDartVersion(runtimeVersion ?? Platform.version);
  if (flutterVersion == null || dartVersion == null) {
    return null;
  }

  return CockpitEnvironment(
    platform: platform,
    flutterVersion: flutterVersion,
    dartVersion: dartVersion,
  );
}

String? _normalizeVersion(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _parseDartVersion(String runtimeVersion) {
  final match = RegExp(r'^(\d+\.\d+\.\d+)').firstMatch(runtimeVersion.trim());
  return match?.group(1);
}
