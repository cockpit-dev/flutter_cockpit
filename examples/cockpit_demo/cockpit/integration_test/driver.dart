import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final reportPath = Platform.environment['COCKPIT_NATIVE_REPORT_PATH'];
  await integrationDriver(
    responseDataCallback: (data) async {
      if (reportPath == null || reportPath.trim().isEmpty || data == null) {
        return;
      }
      final file = File(reportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    },
    writeResponseOnFailure: true,
  );
}
