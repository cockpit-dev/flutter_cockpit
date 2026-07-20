import '../foundation/cockpit_canonical_paths.dart';
import '../foundation/cockpit_filesystem_identity.dart';
import '../foundation/cockpit_home.dart';
import '../foundation/cockpit_ids.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import '../infrastructure/cockpit_clock.dart';
import 'cockpit_allowed_root_registry.dart';
import 'cockpit_directory_ancestor_policy.dart';
import 'cockpit_directory_attestation.dart';
import 'cockpit_registry_database.dart';
import 'cockpit_registry_models.dart';
import 'cockpit_scoped_reference_index.dart';
import 'cockpit_workspace_marker_store.dart';
import 'cockpit_workspace_registry.dart';

final class CockpitIdentityRegistry {
  const CockpitIdentityRegistry({
    required this.homePaths,
    required this.roots,
    required this.workspaces,
    required this.references,
  });

  final CockpitHomePaths homePaths;
  final CockpitAllowedRootRegistry roots;
  final CockpitWorkspaceRegistry workspaces;
  final CockpitScopedReferenceIndex references;

  static Future<CockpitIdentityRegistry> initialize({
    CockpitHomeResolver? homeResolver,
    CockpitPermissionHardener? permissionHardener,
    CockpitDirectorySyncer? directorySyncer,
    CockpitCanonicalDirectoryResolver directoryResolver =
        const CockpitCanonicalDirectoryResolver(),
    CockpitPosixMetadataProvider? metadataProvider,
    CockpitFilesystemIdentityProvider? identityProvider,
    CockpitIdGenerator? idGenerator,
    CockpitClock clock = const SystemCockpitClock(),
    CockpitRegistryActivityController activityController =
        const CockpitPassiveRegistryActivityController(),
    List<CockpitRegistryReferenceOwner> referenceOwners =
        const <CockpitRegistryReferenceOwner>[],
  }) async {
    final resolver = homeResolver ?? CockpitHomeResolver.system();
    final hardener =
        permissionHardener ??
        (resolver.platform == CockpitHostPlatform.windows
            ? const CockpitWindowsAclPermissionHardener()
            : const CockpitPosixPermissionHardener());
    final syncer =
        directorySyncer ?? CockpitSystemDirectorySyncer(resolver.platform);
    final paths = await CockpitHome(
      paths: CockpitHomePaths(resolver.resolve()),
      permissionHardener: hardener,
    ).initialize();
    final posixMetadata =
        metadataProvider ??
        CockpitSystemPosixMetadataProvider(resolver.platform);
    final ids = idGenerator ?? CockpitSecureIdGenerator();
    final pathStyle = resolver.platform == CockpitHostPlatform.windows
        ? CockpitPathStyle.windows
        : CockpitPathStyle.posix;
    final lexicalPaths = CockpitLexicalPaths(pathStyle);
    final database = CockpitRegistryDatabase.create(
      paths: paths,
      permissionHardener: hardener,
      directorySyncer: syncer,
      lexicalPaths: lexicalPaths,
    );
    final security = CockpitDirectorySecurityInspector(
      platform: resolver.platform,
      metadataProvider: posixMetadata,
    );
    final ancestorPolicy = CockpitSystemDirectoryAncestorPolicy(
      platform: resolver.platform,
      metadataProvider: posixMetadata,
    );
    final markers = CockpitWorkspaceMarkerStore(
      CockpitAtomicJsonFile(
        permissionHardener: hardener,
        directorySyncer: syncer,
      ),
    );
    final attestor = identityProvider == null
        ? CockpitSystemDirectoryAttestor(
            platform: resolver.platform,
            directoryResolver: directoryResolver,
            metadataProvider: posixMetadata,
            ancestorPolicy: ancestorPolicy,
            lexicalPaths: lexicalPaths,
          )
        : CockpitDirectoryAttestor(
            directoryResolver: directoryResolver,
            identityProvider: identityProvider,
            securityInspector: security,
            ancestorPolicy: ancestorPolicy,
            lexicalPaths: lexicalPaths,
            requireStrongIdentity: false,
          );
    return CockpitIdentityRegistry(
      homePaths: paths,
      roots: CockpitAllowedRootRegistry(
        database: database,
        directoryAttestor: attestor,
        idGenerator: ids,
        clock: clock,
        lexicalPaths: lexicalPaths,
        activityController: activityController,
        referenceOwners: referenceOwners,
      ),
      workspaces: CockpitWorkspaceRegistry(
        database: database,
        markerStore: markers,
        directoryAttestor: attestor,
        idGenerator: ids,
        clock: clock,
        lexicalPaths: lexicalPaths,
        activityController: activityController,
        referenceOwners: referenceOwners,
      ),
      references: CockpitScopedReferenceIndex(database),
    );
  }
}
