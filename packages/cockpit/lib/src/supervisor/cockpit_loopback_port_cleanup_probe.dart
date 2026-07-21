import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_lease_support.dart';

typedef CockpitLoopbackPortBinder =
    Future<ServerSocket> Function(InternetAddress address, int port);

final class CockpitLoopbackPortCleanupProbe
    implements CockpitLeaseCleanupProbe {
  const CockpitLoopbackPortCleanupProbe({
    CockpitLoopbackPortBinder bind = _bind,
  }) : _bindSocket = bind;

  static const resourcePrefix = 'loopback-v4:';

  final CockpitLoopbackPortBinder _bindSocket;

  static String resourceId(int port) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(port, 'port');
    }
    return '$resourcePrefix$port';
  }

  static int parseResourceId(String resourceId) {
    if (!resourceId.startsWith(resourcePrefix)) {
      throw const FormatException('Invalid loopback port resource id.');
    }
    final port = int.tryParse(resourceId.substring(resourcePrefix.length));
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('Invalid loopback port resource id.');
    }
    return port;
  }

  @override
  Future<CockpitLeaseCleanupResult> cleanupAndVerify(
    CockpitLeaseCleanupContext context,
  ) async {
    if (context.resourceKind != CockpitLeaseResourceKind.forwardedPort) {
      return CockpitLeaseCleanupResult.quarantined(
        _failure(
          'portCleanupKindMismatch',
          'Loopback cleanup probe received a non-port resource.',
        ),
      );
    }
    late final int port;
    try {
      port = parseResourceId(context.resourceId);
    } on FormatException {
      return CockpitLeaseCleanupResult.quarantined(
        _failure(
          'portResourceInvalid',
          'Loopback port resource identity is invalid.',
        ),
      );
    }
    ServerSocket? socket;
    try {
      socket = await _bindSocket(InternetAddress.loopbackIPv4, port);
      return const CockpitLeaseCleanupResult.restored();
    } on SocketException {
      return CockpitLeaseCleanupResult.quarantined(
        _failure(
          'portStillOwned',
          'Loopback port is still bound after cleanup.',
        ),
      );
    } finally {
      await socket?.close();
    }
  }

  static Future<ServerSocket> _bind(InternetAddress address, int port) =>
      ServerSocket.bind(address, port, shared: false);
}

CockpitFailure _failure(String code, String message) => CockpitFailure(
  primary: CockpitApiError(
    code: code,
    category: CockpitErrorCategory.resource,
    message: message,
    retryable: true,
    responsibleLayer: CockpitResponsibleLayer.supervisor,
  ),
);
