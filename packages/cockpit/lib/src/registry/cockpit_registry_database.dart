import '../foundation/cockpit_canonical_paths.dart';
import '../foundation/cockpit_home.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import 'cockpit_registry_state.dart';

final class CockpitRegistryDatabase {
  CockpitRegistryDatabase(this._store);

  factory CockpitRegistryDatabase.create({
    required CockpitHomePaths paths,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
    required CockpitLexicalPaths lexicalPaths,
  }) => CockpitRegistryDatabase(
    CockpitLockedJsonStore<CockpitRegistryState>(
      path: paths.identityRegistry,
      codec: CockpitRegistryStateCodec(lexicalPaths),
      createInitial: CockpitRegistryState.new,
      permissionHardener: permissionHardener,
      directorySyncer: directorySyncer,
    ),
  );

  final CockpitLockedJsonStore<CockpitRegistryState> _store;

  Future<CockpitRegistryState> read() => _store.read();

  Future<R> transact<R>(
    Future<CockpitLockedJsonUpdate<CockpitRegistryState, R>> Function(
      CockpitRegistryState state,
    )
    transaction,
  ) => _store.transact(transaction);
}
