import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../application/cockpit_application_service_exception.dart';
import 'cockpit_worker_resource_grant.dart';

abstract interface class CockpitWorkerForwardedPortHandoff {
  /// Invokes [launch] only after the Supervisor has released its reservation,
  /// and completes only after the Supervisor has accepted the bound owner.
  Future<T> launchWithGrant<T>({
    required CockpitWorkerResourceGrant grant,
    required DateTime deadline,
    required Future<T> Function(int port) launch,
  });
}

CockpitWorkerResourceGrant requireForwardedPortGrant({
  required String workspaceId,
  required List<CockpitWorkerResourceGrant> grants,
  required DateTime deadline,
}) {
  final matches = grants
      .where(
        (grant) =>
            grant.workspaceId == workspaceId &&
            grant.resourceKind == CockpitLeaseResourceKind.forwardedPort &&
            grant.port != null &&
            grant.handoffToken != null,
      )
      .toList(growable: false);
  if (matches.length != 1 ||
      !matches.single.expiresAt.isAfter(DateTime.now().toUtc()) ||
      !deadline.isAfter(DateTime.now().toUtc())) {
    throw const CockpitApplicationServiceException(
      code: 'forwardedPortGrantInvalid',
      message: 'Launch requires one active Supervisor forwarded-port grant.',
    );
  }
  return matches.single;
}
