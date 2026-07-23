import 'package:cockpit/src/worker/cockpit_worker_memory_event_exchange.dart';
import 'package:cockpit/src/worker/cockpit_worker_protocol_request.dart';
import 'package:cockpit/src/worker/cockpit_worker_value_reader.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('reports event gaps and replays the contiguous prefix', () async {
    final exchange = CockpitWorkerMemoryEventExchange();
    final first = await exchange.publish(
      _publish(afterSequence: 0, events: <CockpitRunEvent>[_event(1)]),
    );
    expect(first.highestContiguousSequence, 1);
    expect(first.replayAfterSequence, isNull);

    final gap = await exchange.publish(
      _publish(afterSequence: 2, events: <CockpitRunEvent>[_event(3)]),
    );
    expect(gap.highestContiguousSequence, 1);
    expect(gap.replayAfterSequence, 1);

    final replay = await exchange.replay(_replay(afterSequence: 0));
    expect(replay.events.map((event) => event.sequence), <int>[1]);
    expect(replay.afterSequence, 0);
  });
}

CockpitWorkerPublishEventBatchRequest _publish({
  required int afterSequence,
  required List<CockpitRunEvent> events,
}) => CockpitWorkerPublishEventBatchRequest(
  protocolVersion: cockpitWorkerProtocolVersion,
  workspaceId: 'workspaceA',
  requestId: 'publish-$afterSequence-${events.first.sequence}',
  deadline: DateTime.utc(2026, 7, 22, 1),
  idempotencyKey: 'publish-$afterSequence-${events.first.sequence}',
  runId: 'runA',
  afterSequence: afterSequence,
  events: events,
);

CockpitWorkerReplayEventsRequest _replay({required int afterSequence}) =>
    CockpitWorkerReplayEventsRequest(
      protocolVersion: cockpitWorkerProtocolVersion,
      workspaceId: 'workspaceA',
      requestId: 'replay-$afterSequence',
      deadline: DateTime.utc(2026, 7, 22, 1),
      idempotencyKey: 'replay-$afterSequence',
      runId: 'runA',
      afterSequence: afterSequence,
    );

CockpitRunEvent _event(int sequence) => CockpitRunEvent(
  eventId: 'event$sequence',
  sequence: sequence,
  timestamp: DateTime.utc(2026, 7, 22),
  kind: 'run.progress',
  entityKind: CockpitRunEventEntityKind.run,
  projectId: 'projectA',
  workspaceId: 'workspaceA',
  runId: 'runA',
  caseId: 'caseA',
  lifecycle: CockpitRunLifecycle.running,
);
