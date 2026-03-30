import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assembles a bundle summary with runtime-driven failure handoff', () {
    final assembler = CockpitBundleSummaryAssembler(
      now: () => DateTime.utc(2026, 3, 30, 10, 0, 5),
    );
    final bundle = assembler.assemble(
      session: CockpitSession(
        sessionId: 'session-runtime',
        taskId: 'task-runtime',
        platform: 'android',
        startedAt: DateTime.utc(2026, 3, 30, 10, 0, 0),
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'runtime_event',
          actionArgs: <String, Object?>{
            'eventId': 'runtime-1',
            'kind': CockpitRuntimeEventKind.flutterError.jsonValue,
            'severity': CockpitRuntimeEventSeverity.error.jsonValue,
            'message': 'setState() called after dispose()',
            'recordedAt': DateTime.utc(2026, 3, 30, 10, 0, 1).toIso8601String(),
          },
          observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
          status: CockpitCommandStatus.failed,
        ),
      ],
      status: CockpitTaskStatus.completed,
      capabilitiesUsed: const <String>['tap'],
    );

    expect(bundle.manifest.status, CockpitTaskStatus.failed);
    expect(bundle.manifest.runtimeErrorCount, 1);
    expect(bundle.handoff['status'], 'failed');
    expect(bundle.acceptanceMarkdown, contains('## Runtime'));
  });
}
