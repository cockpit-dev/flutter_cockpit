import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor cockpitDemoCreateLocalExecutor({required String name}) {
  return driftDatabase(name: name, web: _cockpitDemoWebOptions());
}

QueryExecutor cockpitDemoCreateInMemoryExecutor({required String name}) {
  return DatabaseConnection.delayed(
    Future<DatabaseConnection>(() async {
      final sqlite3 = await WasmSqlite3.loadFromUrl(
        _cockpitDemoWebOptions().sqlite3Wasm,
      );
      return DatabaseConnection(WasmDatabase.inMemory(sqlite3));
    }),
  );
}

DriftWebOptions _cockpitDemoWebOptions() {
  return DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );
}
