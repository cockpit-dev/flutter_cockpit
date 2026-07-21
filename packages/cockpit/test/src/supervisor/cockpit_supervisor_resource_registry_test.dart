import 'dart:io';

import 'package:cockpit/src/foundation/cockpit_home.dart';
import 'package:cockpit/src/foundation/cockpit_permissions.dart';
import 'package:cockpit/src/registry/cockpit_registry_models.dart';
import 'package:cockpit/src/registry/cockpit_workspace_registry.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_registry.dart';
import 'package:cockpit/src/supervisor/cockpit_lease_support.dart';
import 'package:cockpit/src/supervisor/cockpit_supervisor_resource_registry.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'cockpit_lease_test_support.dart';

void main() {
  test(
    'composite assembly fences workspace retirement with live leases',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'cockpit-resource-registry-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final platform = Platform.isWindows
          ? CockpitHostPlatform.windows
          : Platform.isMacOS
          ? CockpitHostPlatform.macos
          : CockpitHostPlatform.linux;
      final cleanup = TestLeaseCleanupProbe();
      final registry = await CockpitSupervisorResourceRegistry.initialize(
        cleanupProbes: CockpitLeaseCleanupProbeMap(
          <CockpitLeaseResourceKind, CockpitLeaseCleanupProbe>{
            for (final kind in CockpitLeaseResourceKind.values) kind: cleanup,
          },
        ),
        homeResolver: CockpitHomeResolver(
          platform: platform,
          environment: <String, String>{
            'COCKPIT_HOME': p.join(temporary.path, 'home'),
          },
          userHome: temporary.path,
        ),
        permissionHardener: Platform.isWindows
            ? const CockpitWindowsInheritedAclPermissionHardener()
            : const CockpitPosixPermissionHardener(),
        directorySyncer: const TestDirectorySyncer(),
        idGenerator: TestLeaseIdGenerator(),
      );
      final rootDirectory = await Directory(
        p.join(temporary.path, 'root'),
      ).create();
      final workspaceDirectory = await Directory(
        p.join(rootDirectory.path, 'workspace'),
      ).create();
      final root = await registry.identity.roots.register(rootDirectory.path);
      final workspace = await registry.identity.workspaces.register(
        rootId: root.rootId,
        path: workspaceDirectory.path,
      );
      final lease = await registry.leases.acquire(
        leaseRequest(
          key: 'assembly.lease',
          resourceId: 'assembly-device',
          workspaceId: workspace.workspaceId,
          waitTimeoutMs: 0,
        ),
      );

      await expectLater(
        registry.identity.workspaces.unregister(workspace.workspaceId),
        throwsA(
          isA<CockpitRegistryException>().having(
            (error) => error.code,
            'code',
            'workspaceInUse',
          ),
        ),
      );
      var drainCompleted = false;
      final drain = registry.identity.workspaces
          .unregister(
            workspace.workspaceId,
            policy: CockpitRemovalPolicy.drain,
            drainTimeout: const Duration(seconds: 2),
          )
          .then((result) {
            drainCompleted = true;
            return result;
          });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(drainCompleted, isFalse);
      expect(cleanup.contexts, isEmpty);
      await registry.leases.release(lease.leaseId, holderId: lease.holderId);
      await drain;
      expect(
        (await registry.leases.get(lease.leaseId)).state,
        CockpitLeaseState.released,
      );
      expect(cleanup.contexts.single.reason, CockpitLeaseCleanupReason.release);

      final forcedDirectory = await Directory(
        p.join(rootDirectory.path, 'forced-workspace'),
      ).create();
      final forcedWorkspace = await registry.identity.workspaces.register(
        rootId: root.rootId,
        path: forcedDirectory.path,
      );
      cleanup.enqueue(
        Future<CockpitLeaseCleanupResult>.value(
          CockpitLeaseCleanupResult.quarantined(
            testLeaseFailure('assembly.force.cleanup.failed'),
          ),
        ),
      );
      final forcedLease = await registry.leases.acquire(
        leaseRequest(
          key: 'assembly.force.lease',
          resourceId: 'assembly-force-device',
          workspaceId: forcedWorkspace.workspaceId,
          waitTimeoutMs: 0,
        ),
      );
      await registry.identity.workspaces.unregister(
        forcedWorkspace.workspaceId,
        policy: CockpitRemovalPolicy.force,
      );
      expect(
        (await registry.leases.get(forcedLease.leaseId)).state,
        CockpitLeaseState.quarantined,
      );
      expect(
        await registry.leases.activeReferenceCount(forcedWorkspace.workspaceId),
        0,
      );
    },
  );
}
