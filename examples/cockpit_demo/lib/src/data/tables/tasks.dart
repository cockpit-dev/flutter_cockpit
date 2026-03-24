import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get notes => text().withDefault(const Constant(''))();

  IntColumn get priority => integer().withDefault(const Constant(1))();

  IntColumn get dueAtEpochMs => integer().nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  IntColumn get completedAtEpochMs => integer().nullable()();

  IntColumn get deletedAtEpochMs => integer().nullable()();

  IntColumn get displayOrder => integer()();

  TextColumn get tagIdsJson => text().withDefault(const Constant('[]'))();

  IntColumn get createdAtEpochMs => integer()();

  IntColumn get updatedAtEpochMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
