import 'dart:io';

import '../platform/ios/cockpit_ios_device_connection.dart';
import 'cockpit_android_port_forwarder.dart';

Future<int> cockpitResolveLocalSessionPort({
  required String platform,
  required String deviceId,
  required int preferredPort,
  bool allowFallbackAllocation = true,
  CockpitHostPortAllocator portAllocator = cockpitAllocateHostPort,
  CockpitHostPortAvailabilityChecker portAvailabilityChecker =
      cockpitIsHostPortAvailable,
}) async {
  if (!_usesHostVisibleSessionPort(platform: platform, deviceId: deviceId)) {
    return preferredPort;
  }

  if (await portAvailabilityChecker(preferredPort)) {
    return preferredPort;
  }

  if (!allowFallbackAllocation) {
    throw const SocketException(
      'Supervisor-granted session port is unavailable after handoff.',
    );
  }

  return portAllocator();
}

bool _usesHostVisibleSessionPort({
  required String platform,
  required String deviceId,
}) {
  if (platform == 'android') {
    return false;
  }
  if (platform == 'ios' && !cockpitLooksLikeIosSimulatorDeviceId(deviceId)) {
    return false;
  }
  return true;
}

Future<int> cockpitAllocateHostPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

Future<bool> cockpitIsHostPortAvailable(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}
