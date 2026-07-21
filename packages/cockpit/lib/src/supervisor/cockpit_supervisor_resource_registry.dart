import '../foundation/cockpit_canonical_paths.dart';
import '../foundation/cockpit_filesystem_identity.dart';
import '../foundation/cockpit_home.dart';
import '../foundation/cockpit_ids.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import '../infrastructure/cockpit_clock.dart';
import '../infrastructure/cockpit_monotonic_clock.dart';
import '../registry/cockpit_identity_registry.dart';
import '../registry/cockpit_registry_models.dart';
import 'cockpit_lease_registry.dart';
import 'cockpit_lease_registry_activity.dart';
import 'cockpit_lease_support.dart';
import 'cockpit_lease_workspace_authority.dart';
import 'cockpit_safe_port_allocator.dart';

final class CockpitSupervisorResourceRegistry {
  const CockpitSupervisorResourceRegistry._({
    required this.identity,
    required this.leases,
    required this.leaseActivity,
  });

  final CockpitIdentityRegistry identity;
  final CockpitLeaseRegistry leases;
  final CockpitLeaseRegistryActivityController leaseActivity;

  CockpitSafePortAllocator createPortAllocator({
    CockpitTokenGenerator? tokenGenerator,
    CockpitMonotonicClock? clock,
    CockpitEphemeralLoopbackBinder bindEphemeral = cockpitBindEphemeralLoopback,
    Duration probeInterval = const Duration(milliseconds: 50),
  }) => CockpitSafePortAllocator(
    leases: leases,
    tokenGenerator: tokenGenerator,
    clock: clock,
    bindEphemeral: bindEphemeral,
    probeInterval: probeInterval,
  );

  static Future<CockpitSupervisorResourceRegistry> initialize({
    required CockpitLeaseCleanupProbeResolver cleanupProbes,
    CockpitHomeResolver? homeResolver,
    CockpitPermissionHardener? permissionHardener,
    CockpitDirectorySyncer? directorySyncer,
    CockpitCanonicalDirectoryResolver directoryResolver =
        const CockpitCanonicalDirectoryResolver(),
    CockpitPosixMetadataProvider? metadataProvider,
    CockpitFilesystemIdentityProvider? identityProvider,
    CockpitIdGenerator? idGenerator,
    CockpitClock wallClock = const SystemCockpitClock(),
    CockpitMonotonicClock? leaseClock,
  }) async {
    final resolver = homeResolver ?? CockpitHomeResolver.system();
    final hardener =
        permissionHardener ??
        (resolver.platform == CockpitHostPlatform.windows
            ? const CockpitWindowsAclPermissionHardener()
            : const CockpitPosixPermissionHardener());
    final syncer =
        directorySyncer ?? CockpitSystemDirectorySyncer(resolver.platform);
    final ids = idGenerator ?? CockpitSecureIdGenerator();
    final bridge = _CockpitLeaseCoordinationBridge();
    final identity = await CockpitIdentityRegistry.initialize(
      homeResolver: resolver,
      permissionHardener: hardener,
      directorySyncer: syncer,
      directoryResolver: directoryResolver,
      metadataProvider: metadataProvider,
      identityProvider: identityProvider,
      idGenerator: ids,
      clock: wallClock,
      activityController: bridge,
      referenceOwners: <CockpitRegistryReferenceOwner>[bridge],
    );
    final resolvedLeaseClock = leaseClock ?? CockpitSystemMonotonicClock();
    final leases = CockpitLeaseRegistry.create(
      paths: identity.homePaths,
      permissionHardener: hardener,
      directorySyncer: syncer,
      workspaceAuthority: CockpitRegistryLeaseWorkspaceAuthority(
        identity.workspaces,
      ),
      cleanupProbes: cleanupProbes,
      idGenerator: ids,
      clock: resolvedLeaseClock,
    );
    final activity = CockpitLeaseRegistryActivityController(
      leases: leases,
      clock: resolvedLeaseClock,
    );
    bridge.attach(owner: leases, activity: activity);
    await leases.recover();
    return CockpitSupervisorResourceRegistry._(
      identity: identity,
      leases: leases,
      leaseActivity: activity,
    );
  }
}

final class _CockpitLeaseCoordinationBridge
    implements
        CockpitRegistryReferenceOwner,
        CockpitRegistryActivityController {
  CockpitRegistryReferenceOwner? _owner;
  CockpitRegistryActivityController? _activity;

  void attach({
    required CockpitRegistryReferenceOwner owner,
    required CockpitRegistryActivityController activity,
  }) {
    if (_owner != null || _activity != null) {
      throw StateError('Lease coordination bridge is already attached.');
    }
    _owner = owner;
    _activity = activity;
  }

  @override
  Future<int> activeReferenceCount(String workspaceId) =>
      _requiredOwner.activeReferenceCount(workspaceId);

  @override
  Future<R> withAdmissionFence<R>(
    Set<String> rootIds,
    Set<String> workspaceIds,
    Future<R> Function() action,
  ) => _requiredOwner.withAdmissionFence(rootIds, workspaceIds, action);

  @override
  Future<void> drainWorkspaces(Set<String> workspaceIds, Duration timeout) =>
      _requiredActivity.drainWorkspaces(workspaceIds, timeout);

  @override
  Future<void> forceWorkspaces(Set<String> workspaceIds) =>
      _requiredActivity.forceWorkspaces(workspaceIds);

  CockpitRegistryReferenceOwner get _requiredOwner =>
      _owner ?? (throw StateError('Lease coordination is not attached.'));

  CockpitRegistryActivityController get _requiredActivity =>
      _activity ?? (throw StateError('Lease coordination is not attached.'));
}
