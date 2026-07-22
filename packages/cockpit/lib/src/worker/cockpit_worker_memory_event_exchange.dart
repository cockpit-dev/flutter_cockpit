import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_worker_protocol_request.dart';
import 'cockpit_worker_protocol_result.dart';
import 'cockpit_worker_server.dart';

final class CockpitWorkerMemoryEventExchange
    implements CockpitWorkerEventExchange {
  CockpitWorkerMemoryEventExchange({
    this.maximumRuns = 1024,
    this.maximumEventsPerRun = 4096,
  }) {
    if (maximumRuns < 1 ||
        maximumRuns > 16384 ||
        maximumEventsPerRun < 256 ||
        maximumEventsPerRun > 65536) {
      throw ArgumentError('Worker event memory bounds are invalid.');
    }
  }

  final int maximumRuns;
  final int maximumEventsPerRun;
  final Map<String, List<CockpitRunEvent>> _events =
      <String, List<CockpitRunEvent>>{};

  @override
  Future<CockpitWorkerPublishEventBatchResult> publish(
    CockpitWorkerPublishEventBatchRequest request,
  ) async {
    final existing = _events[request.runId];
    if (existing == null && _events.length >= maximumRuns) {
      throw const FormatException('Worker event run bound was exceeded.');
    }
    final events = existing ?? <CockpitRunEvent>[];
    final highest = events.isEmpty ? 0 : events.last.sequence;
    if (request.afterSequence > highest) {
      return CockpitWorkerPublishEventBatchResult(
        runId: request.runId,
        highestContiguousSequence: highest,
        replayAfterSequence: highest,
      );
    }
    for (final event in request.events) {
      if (event.sequence <= events.length) {
        final persisted = events[event.sequence - 1];
        if (jsonEncode(persisted.toJson()) != jsonEncode(event.toJson())) {
          throw const FormatException(
            'Published event conflicts with an existing sequence.',
          );
        }
        continue;
      }
      final expected = events.length + 1;
      if (event.sequence != expected) {
        return CockpitWorkerPublishEventBatchResult(
          runId: request.runId,
          highestContiguousSequence: events.length,
          replayAfterSequence: events.length,
        );
      }
      if (events.length >= maximumEventsPerRun) {
        throw const FormatException('Worker event run bound was exceeded.');
      }
      events.add(event);
    }
    _events[request.runId] = events;
    return CockpitWorkerPublishEventBatchResult(
      runId: request.runId,
      highestContiguousSequence: events.length,
    );
  }

  @override
  Future<CockpitWorkerReplayEventsResult> replay(
    CockpitWorkerReplayEventsRequest request,
  ) async {
    final events = _events[request.runId] ?? const <CockpitRunEvent>[];
    final start = request.afterSequence.clamp(0, events.length);
    final end = (start + 256).clamp(start, events.length);
    return CockpitWorkerReplayEventsResult(
      runId: request.runId,
      afterSequence: request.afterSequence,
      events: events.sublist(start, end),
    );
  }
}
