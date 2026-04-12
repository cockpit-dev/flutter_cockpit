import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor cockpitDemoCreateLocalExecutor({required String name}) {
  return driftDatabase(
    name: name,
    web: _cockpitDemoWebOptions(),
  );
}

QueryExecutor cockpitDemoCreateInMemoryExecutor({required String name}) {
  return NativeDatabase.memory();
}

DriftWebOptions _cockpitDemoWebOptions() {
  return DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );
}
