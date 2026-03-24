import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime event and snapshot round-trip through json', () {
    final event = CockpitRuntimeEvent(
      eventId: 'runtime-1',
      kind: CockpitRuntimeEventKind.flutterError,
      severity: CockpitRuntimeEventSeverity.error,
      message: 'RenderFlex overflowed.',
      recordedAt: DateTime.utc(2026, 3, 22, 2, 0),
      routeName: '/inbox',
      source: 'widgets library',
      details: const <String, String>{'context': 'during layout'},
      stackTracePreview: '#0      RenderFlex.performLayout',
      stackTraceTruncated: true,
    );
    final snapshot = CockpitRuntimeSnapshot(
      totalEntryCount: 3,
      errorCount: 1,
      warningCount: 1,
      entries: <CockpitRuntimeEvent>[event],
      capturedEntryCount: 3,
      query: const CockpitRuntimeQuery(onlyErrors: true),
      truncated: true,
    );

    expect(CockpitRuntimeEvent.fromJson(event.toJson()), event);
    expect(CockpitRuntimeSnapshot.fromJson(snapshot.toJson()), snapshot);
    expect(
      CockpitRuntimeQuery.fromJson(
        const CockpitRuntimeQuery(
          onlyErrors: true,
          messageContains: 'overflow',
        ).toJson(),
      ),
      const CockpitRuntimeQuery(onlyErrors: true, messageContains: 'overflow'),
    );
  });
}
