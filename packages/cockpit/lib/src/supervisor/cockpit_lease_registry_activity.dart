import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../infrastructure/cockpit_monotonic_clock.dart';
import '../registry/cockpit_registry_models.dart';
import 'cockpit_lease_registry.dart';
import 'cockpit_lease_support.dart';

final class CockpitLeaseRegistryActivityController
    implements CockpitRegistryActivityController {
  CockpitLeaseRegistryActivityController({
    required CockpitLeaseRegistry leases,
    CockpitMonotonicClock? clock,
    Duration pollInterval = const Duration(milliseconds: 50),
  }) : _leases = leases,
       _clock = clock ?? CockpitSystemMonotonicClock(),
       _pollInterval = pollInterval {
    if (pollInterval <= Duration.zero ||
        pollInterval > const Duration(seconds: 1)) {
      throw ArgumentError.value(pollInterval, 'pollInterval');
    }
  }

  final CockpitLeaseRegistry _leases;
  final CockpitMonotonicClock _clock;
  final Duration _pollInterval;

  @override
  Future<void> drainWorkspaces(
    Set<String> workspaceIds,
    Duration timeout,
  ) async {
    if (timeout <= Duration.zero) {
      if (await _hasBlockingLeases(workspaceIds)) {
        throw const CockpitLeaseException(
          code: 'leaseDrainTimeout',
          message: 'Workspace lease drain exceeded its bounded timeout.',
        );
      }
      return;
    }
    final deadline = CockpitMonotonicDeadline.after(_clock, timeout);
    while (true) {
      if (!await _hasBlockingLeases(workspaceIds)) return;
      if (deadline.isExpired) {
        throw const CockpitLeaseException(
          code: 'leaseDrainTimeout',
          message: 'Workspace lease drain exceeded its bounded timeout.',
        );
      }
      await _clock.delay(deadline.clamp(_pollInterval));
    }
  }

  @override
  Future<void> forceWorkspaces(Set<String> workspaceIds) async {
    await _cancelWorkspaceLeases(workspaceIds, recoverQuarantine: true);
    if (await _hasBlockingLeases(workspaceIds)) {
      throw const CockpitLeaseException(
        code: 'leaseForceCleanupFailed',
        message: 'Forced workspace cleanup left active lease work.',
      );
    }
  }

  Future<void> _cancelWorkspaceLeases(
    Set<String> workspaceIds, {
    bool recoverQuarantine = false,
  }) async {
    final leases = await _leases.list();
    for (final lease in leases) {
      if (!workspaceIds.contains(lease.workspaceId) ||
          lease.state == CockpitLeaseState.released) {
        continue;
      }
      if (lease.state == CockpitLeaseState.quarantined) {
        if (recoverQuarantine) {
          await _leases.recoverResource(lease.resourceKind, lease.resourceId);
        }
        continue;
      }
      await _leases.cancel(lease.leaseId, holderId: lease.holderId);
    }
  }

  Future<bool> _hasBlockingLeases(Set<String> workspaceIds) async {
    final leases = await _leases.list();
    return leases.any(
      (lease) =>
          workspaceIds.contains(lease.workspaceId) &&
          lease.state != CockpitLeaseState.released &&
          lease.state != CockpitLeaseState.quarantined,
    );
  }
}
