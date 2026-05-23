import 'package:drift/drift.dart';

import '../model/todo_settings.dart';
import 'cockpit_demo_database_executor.dart';
import 'tables/app_settings.dart';
import 'tables/tags.dart';
import 'tables/tasks.dart';

part 'cockpit_demo_database.g.dart';

@DriftDatabase(tables: <Type>[Tasks, Tags, AppSettings])
class CockpitDemoDatabase extends _$CockpitDemoDatabase {
  CockpitDemoDatabase(super.executor);

  factory CockpitDemoDatabase.local() {
    return CockpitDemoDatabase(
      cockpitDemoCreateLocalExecutor(name: 'cockpit_demo'),
    );
  }

  factory CockpitDemoDatabase.inMemory() {
    return CockpitDemoDatabase(
      cockpitDemoCreateInMemoryExecutor(name: 'cockpit_demo_test'),
    );
  }

  @override
  int get schemaVersion => 2;

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
      await customStatement(
        'CREATE TABLE task_sync_state ('
        'task_id TEXT NOT NULL PRIMARY KEY, '
        'sync_status TEXT NOT NULL DEFAULT \'idle\', '
        'local_revision INTEGER NOT NULL DEFAULT 0, '
        'remote_revision INTEGER NOT NULL DEFAULT 0, '
        'pending_change_json TEXT NOT NULL DEFAULT \'[]\', '
        'sync_conflict_json TEXT, '
        'last_sync_failure TEXT, '
        'last_synced_at_epoch_ms INTEGER'
        ')',
      );
      await customStatement(
        'CREATE INDEX task_sync_state_status_idx '
        'ON task_sync_state (sync_status)',
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
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await customStatement(
          'CREATE TABLE IF NOT EXISTS task_sync_state ('
          'task_id TEXT NOT NULL PRIMARY KEY, '
          'sync_status TEXT NOT NULL DEFAULT \'idle\', '
          'local_revision INTEGER NOT NULL DEFAULT 0, '
          'remote_revision INTEGER NOT NULL DEFAULT 0, '
          'pending_change_json TEXT NOT NULL DEFAULT \'[]\', '
          'sync_conflict_json TEXT, '
          'last_sync_failure TEXT, '
          'last_synced_at_epoch_ms INTEGER'
          ')',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS task_sync_state_status_idx '
          'ON task_sync_state (sync_status)',
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
