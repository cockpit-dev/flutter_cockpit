import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../model/todo_settings.dart';
import 'tables/app_settings.dart';
import 'tables/tags.dart';
import 'tables/tasks.dart';

part 'cockpit_demo_database.g.dart';

@DriftDatabase(tables: <Type>[Tasks, Tags, AppSettings])
class CockpitDemoDatabase extends _$CockpitDemoDatabase {
  CockpitDemoDatabase(super.executor);

  factory CockpitDemoDatabase.local() {
    return CockpitDemoDatabase(driftDatabase(name: 'cockpit_demo'));
  }

  factory CockpitDemoDatabase.inMemory() {
    return CockpitDemoDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator migrator) async {
          await migrator.createAll();
          await customStatement(
            'CREATE INDEX tasks_active_order_idx '
            'ON tasks (deleted_at_epoch_ms, is_completed, display_order)',
          );
          await customStatement(
            'CREATE INDEX tasks_due_idx '
            'ON tasks (due_at_epoch_ms)',
          );
          await customStatement(
            'CREATE INDEX tasks_updated_idx '
            'ON tasks (updated_at_epoch_ms)',
          );
          await into(appSettings).insert(
            AppSettingsCompanion.insert(
              id: const Value<int>(1),
              themePreference: TodoThemePreference.light.name,
              sortMode: TodoSortMode.manual.name,
              showCompletedInInbox: true,
              compactMode: false,
              updatedAtEpochMs: 0,
            ),
          );
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
