import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer()();

  TextColumn get themePreference => text()();

  TextColumn get sortMode => text()();

  BoolColumn get showCompletedInInbox => boolean()();

  BoolColumn get compactMode => boolean()();

  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
