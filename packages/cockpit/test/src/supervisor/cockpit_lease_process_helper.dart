import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/foundation/cockpit_home.dart';
import 'package:cockpit/src/foundation/cockpit_locked_json_store.dart';
import 'package:cockpit/src/foundation/cockpit_permissions.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_registry.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_support.dart';
import 'package:cockpit/src/supervisor/cockpit_loopback_port_cleanup_probe.dart';
import 'package:cockpit/src/supervisor/cockpit_safe_port_allocator.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 7) {
      throw const FormatException('Expected seven helper arguments.');
    }
    final mode = arguments[0];
    final registry = CockpitLeaseRegistry.create(
      paths: CockpitHomePaths(arguments[1]),
      permissionHardener: Platform.isWindows
          ? const CockpitWindowsInheritedAclPermissionHardener()
          : const CockpitPosixPermissionHardener(),
      directorySyncer: const _NoopDirectorySyncer(),
      workspaceAuthority: const _HelperWorkspaceAuthority(),
      cleanupProbes: CockpitLeaseCleanupProbeMap(
        <CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>{
          for (final kind in CockpitLeaseResourceKind.values)
            kind: kind == CockpitLeaseResourceKind.forwardedPort
                ? const CockpitLoopbackPortCleanupProbe()
                : const _RestoredCleanupProbe(),
        },
      ),
      pollInterval: const Duration(milliseconds: 5),
      cleanupTimeout: const Duration(seconds: 5),
      cleanupClaimGrace: const Duration(seconds: 1),
    );
    switch (mode) {
      case 'lease':
        await _runLease(registry, arguments);
      case 'port':
        await _runPort(registry, arguments);
      default:
        throw FormatException('Unknown helper mode $mode.');
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    await stderr.flush();
    exitCode = 1;
  }
}

Future<void> _runLease(
  CockpitLeaseRegistry registry,
  List<String> arguments,
) async {
  final lease = await registry.acquire(
    CockpitLeaseRequest(
      workspaceId: arguments[2],
      resourceKind: CockpitLeaseResourceKind.device,
      resourceId: arguments[4],
      holderId: arguments[5],
      idempotencyKey: CockpitIdempotencyKey(arguments[3]),
      waitTimeoutMs: 20000,
      ttlMs: 30000,
    ),
  );
  await _emit(<String, Object?>{
    'event': 'acquired',
    'leaseId': lease.leaseId,
    'resourceId': lease.resourceId,
  });
  await _waitForSignal(arguments[6]);
  await registry.release(lease.leaseId, holderId: lease.holderId);
  await _emit(<String, Object?>{'event': 'released'});
}

Future<void> _runPort(
  CockpitLeaseRegistry registry,
  List<String> arguments,
) async {
  final reservation =
      await CockpitSafePortAllocator(
        leases: registry,
        probeInterval: const Duration(milliseconds: 5),
      ).reserve(
        workspaceId: arguments[2],
        holderId: arguments[5],
        idempotencyKey: CockpitIdempotencyKey(arguments[3]),
      );
  await _emit(<String, Object?>{
    'event': 'reserved',
    'leaseId': reservation.lease.leaseId,
    'port': reservation.port,
  });
  await _waitForSignal(arguments[6]);
  await reservation.release();
  await _emit(<String, Object?>{'event': 'released'});
}

Future<void> _emit(Map<String, Object?> event) async {
  stdout.writeln(jsonEncode(event));
  await stdout.flush();
}

Future<void> _waitForSignal(String path) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!File(path).existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Helper release signal timed out.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

final class _HelperWorkspaceAuthority
    implements CockpitLeaseWorkspaceAuthority {
  const _HelperWorkspaceAuthority();

  @override
  Future<CockpitLeaseWorkspaceScope> resolveActive(String workspaceId) async {
    final rootId = switch (workspaceId) {
      'workspaceA' => 'rootA',
      'workspaceB' => 'rootB',
      _ => null,
    };
    if (rootId == null) {
      throw const CockpitLeaseException(
        code: 'workspaceNotActive',
        message: 'Helper workspace is not active.',
      );
    }
    return CockpitLeaseWorkspaceScope(workspaceId: workspaceId, rootId: rootId);
  }
}

final class _RestoredCleanupProbe implements CockpitLeaseCleanupProbe {
  const _RestoredCleanupProbe();

  @override
  Future<CockpitLeaseCleanupResult> cleanupAndVerify(
    CockpitLeaseCleanupContext context,
  ) async => const CockpitLeaseCleanupResult.restored();
}

final class _NoopDirectorySyncer implements CockpitDirectorySyncer {
  const _NoopDirectorySyncer();

  @override
  Future<void> sync(String directoryPath) async {}
}
