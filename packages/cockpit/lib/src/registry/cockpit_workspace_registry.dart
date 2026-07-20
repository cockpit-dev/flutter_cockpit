import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../foundation/cockpit_canonical_paths.dart';
import '../foundation/cockpit_filesystem_identity.dart';
import '../foundation/cockpit_ids.dart';
import '../foundation/cockpit_locked_json_store.dart';
import '../infrastructure/cockpit_clock.dart';
import 'cockpit_directory_attestation.dart';
import 'cockpit_registry_database.dart';
import 'cockpit_registry_invariants.dart';
import 'cockpit_registry_models.dart';
import 'cockpit_registry_records.dart';
import 'cockpit_registry_state.dart';
import 'cockpit_registry_value_reader.dart';
import 'cockpit_workspace_marker_store.dart';

part 'cockpit_workspace_registration.dart';
part 'cockpit_workspace_rebind.dart';
part 'cockpit_workspace_lifecycle.dart';
part 'cockpit_workspace_support.dart';

final class CockpitWorkspaceRegistry {
  const CockpitWorkspaceRegistry({
    required CockpitRegistryDatabase database,
    required CockpitWorkspaceMarkerStore markerStore,
    required CockpitDirectoryAttestationProvider directoryAttestor,
    required CockpitIdGenerator idGenerator,
    required CockpitClock clock,
    required CockpitLexicalPaths lexicalPaths,
    required CockpitRegistryActivityController activityController,
    List<CockpitRegistryReferenceOwner> referenceOwners =
        const <CockpitRegistryReferenceOwner>[],
  }) : _database = database,
       _markerStore = markerStore,
       _directoryAttestor = directoryAttestor,
       _idGenerator = idGenerator,
       _clock = clock,
       _lexicalPaths = lexicalPaths,
       _activityController = activityController,
       _referenceOwners = referenceOwners;

  final CockpitRegistryDatabase _database;
  final CockpitWorkspaceMarkerStore _markerStore;
  final CockpitDirectoryAttestationProvider _directoryAttestor;
  final CockpitIdGenerator _idGenerator;
  final CockpitClock _clock;
  final CockpitLexicalPaths _lexicalPaths;
  final CockpitRegistryActivityController _activityController;
  final List<CockpitRegistryReferenceOwner> _referenceOwners;
}
