import 'dart:convert';

import 'package:cockpit/src/application/cockpit_latest_task_store.dart';
import 'package:cockpit/src/application/cockpit_read_latest_task_summary_service.dart';
import 'package:cockpit/src/application/cockpit_run_task_service.dart';
import 'package:cockpit/src/mcp/core/cockpit_mcp_resource.dart';
import 'package:cockpit/src/mcp/resources/cockpit_latest_task_resource.dart';
import 'package:test/test.dart';

void main() {
  test(
    'latest task resource includes warnings from the latest task snapshot',
    () async {
      final store = CockpitLatestTaskStore(
        now: () => DateTime.utc(2026, 5, 10, 12, 0, 0),
      );
      store.recordRunTask(
        const CockpitRunTaskResult(
          classification: CockpitRunTaskClassification.completed,
          recommendedNextStep: 'delivery_ready',
          warnings: <String>[
            'Automation cleanup failed after task orchestration: stop timeout.',
          ],
        ),
      );
      final resource = CockpitLatestTaskResource(
        service: CockpitReadLatestTaskSummaryService(store: store),
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(uri: 'cockpit://task/latest'),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      final decoded = jsonDecode(contents.text) as Map<String, Object?>;
      expect(decoded['recommendedNextStep'], 'delivery_ready');
      expect(decoded['warnings'], <String>[
        'Automation cleanup failed after task orchestration: stop timeout.',
      ]);
    },
  );
}
