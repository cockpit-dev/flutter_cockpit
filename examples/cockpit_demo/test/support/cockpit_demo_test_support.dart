import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/cockpit_demo_app.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';
import 'package:cockpit_demo/src/ui/screens/todo_collection_screen.dart';
import 'package:path/path.dart' as p;

bool _cockpitDemoTestRuntimeConfigured = false;

void _ensureCockpitDemoTestRuntimeConfigured() {
  if (_cockpitDemoTestRuntimeConfigured) {
    return;
  }
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _cockpitDemoTestRuntimeConfigured = true;
}

void addCockpitDemoDatabaseTearDown(
  WidgetTester tester,
  CockpitDemoDatabase database,
) {
  _ensureCockpitDemoTestRuntimeConfigured();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> pumpTodoApp(
  WidgetTester tester, {
  required CockpitSessionController controller,
  required CockpitDemoDatabase database,
  FlutterCockpitConfiguration? configuration,
  TodoSyncGatewayClient? syncGateway,
}) async {
  _ensureCockpitDemoTestRuntimeConfigured();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  final effectiveConfiguration = (configuration ??
          const FlutterCockpitConfiguration(initialRouteName: '/inbox'))
      .copyWith(sessionController: controller);
  await tester.pumpWidget(
    CockpitDemoApp(
      configuration: effectiveConfiguration,
      database: database,
      syncGateway: syncGateway,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle();
}

HttpClient createRealHttpClient() =>
    _RealHttpOverrides().createHttpClient(null);

CockpitHttpNetworkObserver createObservedRealNetworkObserver({
  int maxRetainedEntries = 80,
}) {
  final observer = CockpitHttpNetworkObserver(
    maxRetainedEntries: maxRetainedEntries,
  );
  observer.attachParentOverrides(_RealHttpOverrides());
  return observer;
}

Future<void> createTaskThroughUi(
  WidgetTester tester, {
  required String title,
  String notes = '',
  String? priorityKey,
  String? dueKey,
}) async {
  await tester.tap(find.byKey(const ValueKey<String>('fab-add-task')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey<String>('task-title-input')),
    title,
  );
  if (notes.isNotEmpty) {
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-notes-input')),
      notes,
    );
  }
  if (priorityKey != null) {
    await _scrollUntilVisible(tester, ValueKey<String>(priorityKey));
    await tester.tap(find.byKey(ValueKey<String>(priorityKey)));
    await tester.pumpAndSettle();
  }
  if (dueKey != null) {
    await _scrollUntilVisible(tester, ValueKey<String>(dueKey));
    await tester.tap(find.byKey(ValueKey<String>(dueKey)));
    await tester.pumpAndSettle();
  }
  await _scrollUntilVisible(tester, const ValueKey<String>('task-save-button'));
  await tester.tap(find.byKey(const ValueKey<String>('task-save-button')));
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 12; attempt += 1) {
    final routeSettled =
        FlutterCockpit.binding.currentRouteName.value != '/editor';
    final spinnerSettled =
        find.byType(CircularProgressIndicator).evaluate().isEmpty;
    final collectionFinder = find.byType(TodoCollectionScreen);
    final collectionSettled = collectionFinder.evaluate().isEmpty ||
        !tester
            .state<State<TodoCollectionScreen>>(collectionFinder)
            .widget
            .service
            .listState
            .isLoading;
    if (routeSettled && spinnerSettled && collectionSettled) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  final finder = find.byKey(key);
  await tester
      .scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      )
      .timeout(const Duration(seconds: 10));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> settleSingleTapGesture(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 32));
  await tester.pumpAndSettle();
}

Future<void> scrollTodoCollectionUntilVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = 220,
}) async {
  final collectionScrollable = find.byKey(
    const ValueKey<String>('todo-collection-scroll'),
  );
  final scrollable = collectionScrollable.evaluate().isNotEmpty
      ? find
          .descendant(
            of: collectionScrollable,
            matching: find.byType(Scrollable),
          )
          .first
      : find.byType(Scrollable).first;
  await tester
      .scrollUntilVisible(
        finder,
        delta,
        scrollable: scrollable,
      )
      .timeout(const Duration(seconds: 10));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void recordCapture({
  required CockpitSessionController controller,
  required String actionType,
  required CockpitCaptureResult capture,
  required Map<String, List<int>> artifactPayloads,
}) {
  artifactPayloads[capture.screenshot.artifact.relativePath] =
      capture.screenshot.bytes;
  controller.recordStep(
    actionType: actionType,
    actionArgs: const <String, Object?>{'target': 'root'},
    observation: CockpitObservation(
      routeName: capture.screenshot.snapshot?.routeName,
      interactiveElements: capture.screenshot.snapshot?.visibleTargets
              .map((target) => target.displayLabel)
              .whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      phase: CockpitObservationPhase.afterAction,
    ),
    artifactRefs: <CockpitArtifactRef>[capture.screenshot.artifact],
    captureRefs: <CockpitArtifactRef>[capture.screenshot.artifact],
    commandType: CockpitCommandType.captureScreenshot,
    status: CockpitCommandStatus.succeeded,
    requestedCaptureProfile: capture.requestedProfile,
    resolvedCaptureKind: capture.resolvedCaptureKind,
    usedCaptureFallback: capture.usedFallback,
    degradationReason: capture.degradationReason,
  );
}

Future<Map<String, Object?>> readJson(Uri uri) async {
  return HttpOverrides.runZoned(() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      return Map<String, Object?>.from(payload as Map<Object?, Object?>);
    } finally {
      client.close(force: true);
    }
  }, createHttpClient: _RealHttpOverrides().createHttpClient);
}

Future<Map<String, Object?>> postJson(
  Uri uri,
  Map<String, Object?> payload,
) async {
  return HttpOverrides.runZoned(() async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      return Map<String, Object?>.from(
        jsonDecode(body) as Map<Object?, Object?>,
      );
    } finally {
      client.close(force: true);
    }
  }, createHttpClient: _RealHttpOverrides().createHttpClient);
}

Future<void> deleteDirectory(Directory directory) async {
  if (directory.existsSync()) {
    await directory.delete(recursive: true);
  }
}

CockpitSessionController buildTestController({
  required String sessionId,
  required String taskId,
  required String platform,
  DateTime Function()? now,
}) {
  return CockpitSessionController(
    sessionId: sessionId,
    taskId: taskId,
    platform: platform,
    now: now,
  );
}

TaskRunBundleWriter buildTestBundleWriter() {
  return TaskRunBundleWriter(
    keyframeExtractor: _StaticRecordingKeyframeExtractor(),
  );
}

final List<int> validMp4Bytes = base64Decode(
  'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAAAuVtZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTEgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTI1IHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj0yMy4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAAAD2WIhAAz//727L4FNhTIwQAAAAhBmiJsQr/+wAAAAAgBnkF5Cv/EgQAAA1xtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAAPoAAAAeAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACh3RyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAAeAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAEAAAABAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAAHgAAAQAAAEAAAAAAf9tZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAADIAAAAIAFXEAAAAAAAtaGRscgAAAAAAAAAAdmlkZQAAAAAAAAAAAAAAAFZpZGVvSGFuZGxlcgAAAAGqbWluZgAAABR2bWhkAAAAAQAAAAAAAAAAAAAAJGRpbmYAAAAcZHJlZgAAAAAAAAABAAAADHVybCAAAAABAAABanN0YmwAAAC+c3RzZAAAAAAAAAABAAAArmF2YzEAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAEAAQAEgAAABIAAAAAAAAAAEVTGF2YzYyLjExLjEwMCBsaWJ4MjY0AAAAAAAAAAAAAAAY//8AAAA0YXZjQwFkAAr/4QAXZ2QACqzZXsBEAAADAAQAAAMAyDxIllgBAAZo6+PLIsD9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAvuIAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAMAAAIAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAAAoY3R0cwAAAAAAAAADAAAAAQAABAAAAAABAAAGAAAAAAEAAAIAAAAAHHN0c2MAAAAAAAAAAQAAAAEAAAADAAAAAQAAACBzdHN6AAAAAAAAAAAAAAADAAACxQAAAAwAAAAMAAAAFHN0Y28AAAAAAAAAAQAAADAAAABhdWR0YQAAAFltZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAACxpbHN0AAAAJKl0b28AAAAcZGF0YQAAAAEAAAAATGF2ZjYyLjMuMTAw',
);

final List<int> _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAACXBIWXMAAAABAAAAAQBPJcTWAAAADklEQVR4nGNkAAMWCAUAADgABkRoBWYAAAAASUVORK5CYII=',
);

final class FakeCockpitNativeRecording extends CockpitNativeRecording {
  FakeCockpitNativeRecording({required this.sourceFilePath});

  final String sourceFilePath;

  @override
  Future<CockpitRecordingCapabilities> queryCapabilities() async {
    return CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
    );
  }

  @override
  Future<CockpitRecordingSession> startRecording({
    required CockpitRecordingRequest request,
  }) async {
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording({
    required CockpitRecordingSession session,
  }) async {
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: session.request.purpose,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: CockpitArtifactRef(
        role: 'recording',
        relativePath: cockpitRecordingRelativePathFor(session.request),
      ),
      durationMs: 2600,
      sourceFilePath: sourceFilePath,
    );
  }
}

final class _RealHttpOverrides extends HttpOverrides {}

final class _StaticRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    final baseName = p.basenameWithoutExtension(recordingRelativePath);
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: <CockpitRecordingKeyframe>[
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/${baseName}_baseline.png',
          label: 'baseline',
          offsetMs: 600,
          source: CockpitRecordingKeyframeSource.stepCapture,
        ),
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/${baseName}_midpoint.png',
          label: 'midpoint',
          offsetMs: 3600,
          source: CockpitRecordingKeyframeSource.syntheticCoverage,
        ),
        CockpitRecordingKeyframe(
          relativePath: 'keyframes/${baseName}_tail.png',
          label: 'tail_consistency',
          offsetMs: 7600,
          source: CockpitRecordingKeyframeSource.tailConsistency,
        ),
      ],
      artifactPayloads: <String, List<int>>{
        'keyframes/${baseName}_baseline.png': _validPngBytes,
        'keyframes/${baseName}_midpoint.png': _validPngBytes,
        'keyframes/${baseName}_tail.png': _validPngBytes,
      },
      coverage: const CockpitRecordingCoverage(
        durationMs: 8000,
        hasEarlyCoverage: true,
        hasMidCoverage: true,
        hasLateCoverage: true,
      ),
    );
  }
}
