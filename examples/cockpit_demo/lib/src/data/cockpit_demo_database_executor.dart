import 'package:drift/drift.dart';

import 'cockpit_demo_database_executor_native.dart'
    if (dart.library.js_interop) 'cockpit_demo_database_executor_web.dart'
    as executor;

QueryExecutor cockpitDemoCreateLocalExecutor({required String name}) {
  return executor.cockpitDemoCreateLocalExecutor(name: name);
}

QueryExecutor cockpitDemoCreateInMemoryExecutor({required String name}) {
  return executor.cockpitDemoCreateInMemoryExecutor(name: name);
}
