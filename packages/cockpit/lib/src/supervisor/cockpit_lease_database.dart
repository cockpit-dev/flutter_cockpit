import '../foundation/cockpit_home.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../foundation/cockpit_permissions.dart';
import 'cockpit_lease_state.dart';

final class CockpitLeaseDatabase {
  CockpitLeaseDatabase(this._store);

  factory CockpitLeaseDatabase.create({
    required CockpitHomePaths paths,
    required CockpitPermissionHardener permissionHardener,
    required CockpitDirectorySyncer directorySyncer,
  }) => CockpitLeaseDatabase(
    CockpitLockedJsonStore<CockpitLeaseStateDocument>(
      path: paths.leaseRegistry,
      codec: const CockpitLeaseStateCodec(),
      createInitial: CockpitLeaseStateDocument.new,
      permissionHardener: permissionHardener,
      directorySyncer: directorySyncer,
    ),
  );

  final CockpitLockedJsonStore<CockpitLeaseStateDocument> _store;

  Future<CockpitLeaseStateDocument> read() => _store.read();

  Future<R> transact<R>(
    Future<CockpitLockedJsonUpdate<CockpitLeaseStateDocument, R>> Function(
      CockpitLeaseStateDocument state,
    )
    transaction,
  ) => _store.transact(transaction);
}
