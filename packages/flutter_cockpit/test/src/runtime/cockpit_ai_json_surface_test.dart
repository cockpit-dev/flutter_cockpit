import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('snapshot models omit optional null fields at the source', () {
    final snapshotJson = CockpitSnapshot(
      routeName: null,
      visibleTargets: <CockpitSnapshotTarget>[
        CockpitSnapshotTarget(
          registrationId: 'target-1',
          routeName: '/inbox',
          content: const CockpitSnapshotContent(),
          style: const CockpitSnapshotStyle(),
          layout: const CockpitSnapshotLayout(
            width: 120,
            height: 48,
            dx: 0,
            dy: 0,
          ),
          ancestors: const <CockpitSnapshotAncestor>[
            CockpitSnapshotAncestor(typeName: 'Column'),
          ],
        ),
      ],
    ).toJson();

    expect(snapshotJson.containsKey('routeName'), isFalse);
    expect(snapshotJson.containsKey('diagnosticsArtifactRef'), isFalse);
    expect(snapshotJson.containsKey('summary'), isFalse);
    expect(snapshotJson.containsKey('network'), isFalse);
    expect(snapshotJson.containsKey('runtime'), isFalse);
    expect(snapshotJson.containsKey('rebuild'), isFalse);
    expect(snapshotJson.containsKey('accessibility'), isFalse);

    final targetJson =
        (snapshotJson['visibleTargets']! as List<Object?>).single
            as Map<String, Object?>;
    expect(targetJson.containsKey('cockpitId'), isFalse);
    expect(targetJson.containsKey('semanticId'), isFalse);
    expect(targetJson.containsKey('scrollablePath'), isFalse);

    final contentJson = targetJson['content']! as Map<String, Object?>;
    expect(contentJson, isEmpty);

    final styleJson = targetJson['style']! as Map<String, Object?>;
    expect(styleJson, isEmpty);

    final layoutJson = targetJson['layout']! as Map<String, Object?>;
    expect(layoutJson.containsKey('constraintsSummary'), isFalse);

    final ancestorJson =
        (targetJson['ancestors']! as List<Object?>).single
            as Map<String, Object?>;
    expect(ancestorJson.containsKey('cockpitId'), isFalse);
    expect(ancestorJson.containsKey('routeName'), isFalse);
  });

  test('command and bundle models omit optional null fields', () {
    final commandJson = CockpitCommand(
      commandId: 'tap-inbox',
      commandType: CockpitCommandType.tap,
    ).toJson();
    expect(commandJson.containsKey('locator'), isFalse);
    expect(commandJson.containsKey('timeoutMs'), isFalse);
    expect(commandJson.containsKey('snapshotOptions'), isFalse);
    expect(commandJson.containsKey('screenshotRequest'), isFalse);

    final commandResultJson = CockpitCommandResult(
      success: true,
      commandId: 'tap-inbox',
      commandType: CockpitCommandType.tap,
      durationMs: 42,
    ).toJson();
    expect(commandResultJson.containsKey('locatorResolution'), isFalse);
    expect(commandResultJson.containsKey('snapshot'), isFalse);
    expect(commandResultJson.containsKey('requestedCaptureProfile'), isFalse);
    expect(commandResultJson.containsKey('resolvedCaptureKind'), isFalse);
    expect(commandResultJson.containsKey('degradationReason'), isFalse);
    expect(commandResultJson.containsKey('error'), isFalse);

    final stepJson = CockpitStepRecord(
      index: 0,
      actionType: 'tap',
      actionArgs: const <String, Object?>{},
      observedAt: DateTime.utc(2026, 4, 5),
    ).toJson();
    expect(stepJson.containsKey('observation'), isFalse);
    expect(stepJson.containsKey('snapshot'), isFalse);
    expect(stepJson.containsKey('commandType'), isFalse);
    expect(stepJson.containsKey('locator'), isFalse);
    expect(stepJson.containsKey('locatorResolution'), isFalse);
    expect(stepJson.containsKey('durationMs'), isFalse);
    expect(stepJson.containsKey('status'), isFalse);
    expect(stepJson.containsKey('requestedCaptureProfile'), isFalse);
    expect(stepJson.containsKey('resolvedCaptureKind'), isFalse);
    expect(stepJson.containsKey('degradationReason'), isFalse);

    final recordingJson = CockpitRecordingResult(
      state: CockpitRecordingState.failed,
    ).toJson();
    expect(recordingJson.containsKey('purpose'), isFalse);
    expect(recordingJson.containsKey('recordingKind'), isFalse);
    expect(recordingJson.containsKey('artifact'), isFalse);
    expect(recordingJson.containsKey('durationMs'), isFalse);
    expect(recordingJson.containsKey('bytes'), isFalse);
    expect(recordingJson.containsKey('sourceFilePath'), isFalse);
    expect(recordingJson.containsKey('failureReason'), isFalse);

    final manifestJson = CockpitRunManifest(
      sessionId: 'session-1',
      taskId: 'task-1',
      platform: 'macos',
      status: CockpitTaskStatus.running,
      startedAt: DateTime.utc(2026, 4, 5),
    ).toJson();
    expect(manifestJson.containsKey('finishedAt'), isFalse);
    expect(manifestJson.containsKey('failureSummary'), isFalse);
  });

  test('network and runtime payloads omit null detail fields', () {
    final networkQueryJson = const CockpitNetworkQuery().toJson();
    expect(networkQueryJson.containsKey('method'), isFalse);
    expect(networkQueryJson.containsKey('uriContains'), isFalse);
    expect(networkQueryJson.containsKey('statusCodeAtLeast'), isFalse);

    final runtimeQueryJson = const CockpitRuntimeQuery().toJson();
    expect(runtimeQueryJson.containsKey('messageContains'), isFalse);

    final networkEntryJson = CockpitNetworkEntry(
      requestId: 'request-1',
      method: 'GET',
      uri: 'https://example.com/items',
      startedAt: DateTime.utc(2026, 4, 5),
      durationMs: 80,
    ).toJson();
    expect(networkEntryJson.containsKey('statusCode'), isFalse);
    expect(networkEntryJson.containsKey('requestBodyPreview'), isFalse);
    expect(networkEntryJson.containsKey('responseBodyPreview'), isFalse);
    expect(networkEntryJson.containsKey('error'), isFalse);

    final endpointSummaryJson = const CockpitNetworkEndpointSummary(
      method: 'GET',
      uriPattern: '/items',
      requestCount: 2,
      failureCount: 0,
      averageDurationMs: 80,
    ).toJson();
    expect(endpointSummaryJson.containsKey('lastStatusCode'), isFalse);
    expect(endpointSummaryJson.containsKey('latestUri'), isFalse);

    final runtimeEventJson = CockpitRuntimeEvent(
      eventId: 'event-1',
      kind: CockpitRuntimeEventKind.debugLog,
      severity: CockpitRuntimeEventSeverity.info,
      message: 'ready',
      recordedAt: DateTime.utc(2026, 4, 5),
    ).toJson();
    expect(runtimeEventJson.containsKey('routeName'), isFalse);
    expect(runtimeEventJson.containsKey('source'), isFalse);
    expect(runtimeEventJson.containsKey('stackTracePreview'), isFalse);

    final rebuildEntryJson = const CockpitRebuildEntry(
      signature: 'entry-1',
      routeName: '/inbox',
      typeName: 'InboxPage',
      rebuildCount: 3,
      builtOnceCount: 1,
    ).toJson();
    expect(rebuildEntryJson.containsKey('keyValue'), isFalse);
    expect(rebuildEntryJson.containsKey('semanticId'), isFalse);
    expect(rebuildEntryJson.containsKey('textPreview'), isFalse);

    final accessibilityEntryJson = const CockpitAccessibilityEntry(
      nodeId: 1,
    ).toJson();
    expect(accessibilityEntryJson.containsKey('label'), isFalse);
    expect(accessibilityEntryJson.containsKey('identifier'), isFalse);
    expect(accessibilityEntryJson.containsKey('value'), isFalse);
    expect(accessibilityEntryJson.containsKey('hint'), isFalse);
    expect(accessibilityEntryJson.containsKey('tooltip'), isFalse);
  });
}
