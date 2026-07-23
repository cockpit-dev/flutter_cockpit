import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../session/cockpit_remote_session_handle.dart';

String cockpitCanonicalDeviceResourceId({
  required String platform,
  required String deviceId,
}) => _canonicalResourceId('device', <String>[
  platform.trim().toLowerCase(),
  deviceId.trim(),
]);

String cockpitCanonicalSessionResourceId({
  required String deviceResourceId,
  required CockpitRemoteSessionHandle handle,
}) => _canonicalResourceId('session', <String>[
  deviceResourceId,
  handle.platform.trim().toLowerCase(),
  handle.deviceId.trim(),
  (handle.effectivePlatformAppId ?? handle.appId).trim(),
  '${handle.devicePort}',
]);

String cockpitCanonicalSystemSessionResourceId({
  required String deviceResourceId,
  required String targetId,
  required String targetKind,
  required String? appId,
}) => _canonicalResourceId('session', <String>[
  deviceResourceId,
  targetId,
  targetKind,
  appId ?? '',
]);

String cockpitCanonicalWorkspaceResourceId(String workspaceId) =>
    _canonicalResourceId('workspace', <String>[workspaceId]);

String _canonicalResourceId(String kind, List<String> parts) {
  final digest = sha256.convert(utf8.encode(parts.join('\u0000'))).toString();
  return '${kind}_$digest';
}
