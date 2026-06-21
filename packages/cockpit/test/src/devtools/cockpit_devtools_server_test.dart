import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/devtools/cockpit_devtools_index_html.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CockpitDevtoolsServer', () {
    test('dashboard exposes every panel as a collapsible details surface', () {
      final htmlTags = RegExp(r'<([a-z]+)\s+[^>]*class="([^"]+)"[^>]*>')
          .allMatches(cockpitDevtoolsIndexHtml)
          .where((match) {
            final classes = match.group(2)!.split(RegExp(r'\s+'));
            return classes.contains('panel') ||
                classes.contains('subpanel') ||
                classes.contains('media-viewer-panel');
          })
          .toList();
      final panelMatches = htmlTags
          .where((match) => match.group(1) == 'details')
          .toList();
      final nonCollapsiblePanels = htmlTags
          .where((match) => match.group(1) != 'details')
          .map((match) => match.group(0))
          .toList();
      final panelIds = <String>{};
      expect(panelMatches, hasLength(greaterThanOrEqualTo(8)));
      expect(nonCollapsiblePanels, isEmpty);

      for (final panel in panelMatches) {
        final tag = panel.group(0)!;
        final idMatch = RegExp(r'data-panel-id="([^"]+)"').firstMatch(tag);
        final start = panel.start;
        final nextPanel = panelMatches
            .where((candidate) => candidate.start > start)
            .firstOrNull;
        final panelHtml = cockpitDevtoolsIndexHtml.substring(
          start,
          nextPanel?.start ?? cockpitDevtoolsIndexHtml.length,
        );
        expect(idMatch, isNotNull, reason: tag);
        expect(panelIds.add(idMatch!.group(1)!), isTrue, reason: tag);
        expect(panelHtml, contains('<summary '));
        expect(panelHtml, contains('panel-summary'));
      }

      expect(
        panelIds,
        containsAll(<String>{
          'runs',
          'run-detail',
          'timeline',
          'evidence',
          'launcher',
          'launch-result',
          'payload-preview',
          'inspector',
          'media-viewer',
        }),
      );

      expect(cockpitDevtoolsIndexHtml, contains('PANEL_STATE_STORAGE_KEY'));
      expect(
        cockpitDevtoolsIndexHtml,
        contains('function restorePanelState()'),
      );
      expect(cockpitDevtoolsIndexHtml, contains('function setPanelGroupOpen('));
      expect(
        cockpitDevtoolsIndexHtml,
        contains(
          "document.querySelectorAll('details.collapsible-panel[data-panel-persist=\"true\"]')",
        ),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('.collapsible-panel:not([open]) > .panel-summary'),
      );
      expect(cockpitDevtoolsIndexHtml, contains('id="collapsePanels"'));
      expect(cockpitDevtoolsIndexHtml, contains('id="expandPanels"'));
    });

    test('dashboard dynamic review surfaces are native collapsible panels', () {
      expect(
        cockpitDevtoolsIndexHtml,
        contains("item.className = `event collapsible-panel"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("const item = document.createElement('details');"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("card.className = 'artifact collapsible-panel';"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("const card = document.createElement('details');"),
      );
      expect(cockpitDevtoolsIndexHtml, contains('function createInlinePanel('));
      expect(cockpitDevtoolsIndexHtml, contains('event-meta-panel'));
      expect(cockpitDevtoolsIndexHtml, contains('event-artifacts-panel'));
      expect(
        cockpitDevtoolsIndexHtml,
        contains('panel.dataset.dynamicPanelKind'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains(
          "setDynamicPanelOpen('event', eventKey(event), state.expandAll)",
        ),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("setDynamicPanelOpen('artifact', artifactPanelId, card.open)"),
      );
    });

    test('dashboard global panel controls also govern future dynamic panels', () {
      expect(cockpitDevtoolsIndexHtml, contains('panelGroupOpenOverride'));
      expect(cockpitDevtoolsIndexHtml, contains('timelineEventsOpenOverride'));
      expect(
        cockpitDevtoolsIndexHtml,
        contains('state.panelGroupOpenOverride = open'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('state.timelineEventsOpenOverride = open'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('Object.keys(state.dynamicPanelOpen).length > 0'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('state.dynamicPanelOpen[key] = open'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('state.timelineEventsOpenOverride = state.expandAll'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("typeof state.panelGroupOpenOverride === 'boolean'"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('function defaultDynamicPanelOpen(defaultOpen)'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('function defaultEventPanelOpen(defaultOpen)'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('defaultDynamicPanelOpen(options.defaultOpen !== false)'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('defaultEventPanelOpen(state.expandAll || selected)'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains(
          'defaultDynamicPanelOpen(eager || artifactPriority(displayArtifact) <= 2)',
        ),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('panel.dataset.dynamicPanelKind = options.dynamicPanelKind'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains('panel.dataset.dynamicPanelId = options.dynamicPanelId'),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains("dynamicPanelKind: 'event-inline'"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains(r"dynamicPanelId: `${eventKey(event)}:metadata`"),
      );
      expect(
        cockpitDevtoolsIndexHtml,
        contains(r"dynamicPanelId: `${eventKey(event)}:artifacts`"),
      );
    });

    test('parses workflow YAML through the token-protected API', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_parse_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final response = await _postJson(
        handle.uri.resolve('/api/workflows/parse?token=secret'),
        <String, Object?>{
          'source': '''
schemaVersion: 1
sessionId: parse-session
taskId: parse-task
platform: android
steps:
  - stepId: wait-ready
    stepType: retry
    description: Wait until the ready label appears.
    maxAttempts: 2
    step:
      stepType: command
      command:
        commandId: assert-ready
        commandType: assertText
        parameters:
          text: Ready
''',
        },
      );

      expect(response.statusCode, HttpStatus.ok);
      final body = jsonDecode(response.body) as Map<String, Object?>;
      expect(body['ok'], isTrue);
      expect(body['sessionId'], 'parse-session');
      expect(body['stepCount'], 1);
      expect(body['commandCount'], 0);
      expect(body['requestsRecording'], isFalse);
      final script = body['script']! as Map<String, Object?>;
      final steps = script['steps']! as List<Object?>;
      expect(
        (steps.single as Map<String, Object?>)['description'],
        'Wait until the ready label appears.',
      );
    });

    test(
      'submits run-script jobs asynchronously and confines output to history root',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_submit_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final submittedRequests = <CockpitRunRemoteControlScriptRequest>[];
        final releaseRun = Completer<void>();
        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
          runScript: (request) async {
            submittedRequests.add(request);
            await releaseRun.future;
            final bundleDir = Directory(
              p.join(request.outputRoot, 'runs', 'submitted-bundle'),
            )..createSync(recursive: true);
            return CockpitRunRemoteControlScriptResult(
              sessionHandle: request.sessionHandle,
              bundleDir: bundleDir,
              manifest: CockpitRunManifest(
                sessionId: request.script.sessionId,
                taskId: request.script.taskId,
                platform: request.script.platform,
                status: CockpitTaskStatus.completed,
                startedAt: DateTime.utc(2026, 6, 19, 12),
                finishedAt: DateTime.utc(2026, 6, 19, 12, 0, 1),
              ),
              handoff: const <String, Object?>{},
              delivery: const <String, Object?>{},
              artifactPaths: CockpitBundleArtifactPaths(),
            );
          },
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final response = await _postJson(
          handle.uri.resolve('/api/runs?token=secret'),
          <String, Object?>{
            'kind': 'runScript',
            'scriptText': '''
schemaVersion: 1
sessionId: submitted-session
taskId: submitted-task
platform: android
commands:
  - commandId: assert-ready
    commandType: assertText
    parameters:
      text: Ready
''',
            'sessionHandle': _sessionHandle().toJson(),
          },
        );

        expect(response.statusCode, HttpStatus.accepted);
        final body = jsonDecode(response.body) as Map<String, Object?>;
        final runId = body['runId']! as String;
        expect(runId, contains('submitted-session'));
        expect(body['status'], 'running');

        final jobWhileRunning = await _get(
          handle.uri.resolve('/api/runs/$runId/job?token=secret'),
        );
        expect(jobWhileRunning.statusCode, HttpStatus.ok);
        expect(
          jsonDecode(jobWhileRunning.body),
          containsPair('status', 'running'),
        );

        expect(submittedRequests, hasLength(1));
        expect(submittedRequests.single.liveRunId, runId);
        expect(submittedRequests.single.outputRoot, tempDir.path);

        final cancel = await _postJson(
          handle.uri.resolve('/api/runs/$runId/cancel?token=secret'),
          const <String, Object?>{},
        );
        expect(cancel.statusCode, HttpStatus.conflict);
        expect(
          jsonDecode(cancel.body),
          containsPair('error', 'cancelUnsupported'),
        );

        releaseRun.complete();
        await _eventually(() async {
          final job = await _get(
            handle.uri.resolve('/api/runs/$runId/job?token=secret'),
          );
          final decoded = jsonDecode(job.body) as Map<String, Object?>;
          expect(decoded['status'], 'completed');
        });

        final rejected = await _postJson(
          handle.uri.resolve('/api/runs?token=secret'),
          <String, Object?>{
            'kind': 'runScript',
            'outputRoot': p.dirname(tempDir.path),
            'script': submittedRequests.single.script.toJson(),
            'sessionHandle': _sessionHandle().toJson(),
          },
        );
        expect(rejected.statusCode, HttpStatus.forbidden);
      },
    );

    test('submits validate-task jobs with the same live run id', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_validate_submit_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      CockpitValidateTaskRequest? capturedRequest;
      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
        validateTask: (request) async {
          capturedRequest = request;
          return const CockpitValidateTaskResult(
            classification: CockpitValidationClassification.completed,
            recommendedNextStep: 'delivery_ready',
          );
        },
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final response = await _postJson(
        handle.uri.resolve('/api/runs?token=secret'),
        <String, Object?>{
          'kind': 'validateTask',
          'request': <String, Object?>{
            'runTask': <String, Object?>{
              'sessionHandle': _sessionHandle().toJson(),
              'script': <String, Object?>{
                'sessionId': 'validate-session',
                'taskId': 'validate-task',
                'platform': 'android',
                'commands': <Object?>[
                  <String, Object?>{
                    'commandId': 'assert-ready',
                    'commandType': 'assertText',
                    'parameters': <String, Object?>{'text': 'Ready'},
                  },
                ],
              },
            },
          },
        },
      );

      expect(response.statusCode, HttpStatus.accepted);
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final runId = body['runId']! as String;
      await _eventually(() async {
        expect(capturedRequest, isNotNull);
      });
      expect(capturedRequest!.runTask.liveRunId, runId);
      expect(capturedRequest!.runTask.outputRoot, tempDir.path);
      expect(capturedRequest!.runTask.liveRunDisplayName, 'validate-task');
    });

    test('serves dashboard and token-protected run APIs', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_server_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeRunFixture(tempDir);

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final dashboard = await _get(handle.uri);
      expect(dashboard.statusCode, HttpStatus.ok);
      expect(
        dashboard.headers.value(HttpHeaders.cacheControlHeader),
        contains('no-store'),
      );
      _expectSecurityHeaders(dashboard.headers);
      expect(dashboard.body, contains('Flutter Cockpit Devtools'));
      expect(dashboard.body, contains('data-density="compact"'));
      expect(dashboard.body, contains('/api/workflows/parse'));
      expect(dashboard.body, contains('/api/runs'));
      expect(dashboard.body, contains('/api/events'));
      expect(dashboard.body, contains('bundle-summary'));
      expect(dashboard.body, contains('Submit run'));
      expect(dashboard.body, contains('data-testid="run-detail"'));
      expect(dashboard.body, contains('run-detail-heading'));
      expect(dashboard.body, contains('compact-summary'));
      expect(dashboard.body, contains('run-facts-scroll'));
      expect(dashboard.body, contains('hasLoadedRuns'));
      expect(dashboard.body, contains('loading run history...'));
      expect(dashboard.body, contains("els.runCount.textContent = '...'"));
      expect(
        dashboard.body,
        contains(
          "fact('scopeId', live.scopeId || run.scopeId || state.activeScopeId)",
        ),
      );
      expect(
        dashboard.body,
        contains(
          "fact('scopeLabel', live.scopeLabel || run.scopeLabel || activeScopeLabel())",
        ),
      );
      expect(
        dashboard.body,
        contains(
          "fact('scopeKind', live.scopeKind || run.scopeKind || state.activeScopeKind)",
        ),
      );
      expect(dashboard.body, contains('data-testid="runs-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel runs-panel" data-testid="runs-panel" data-panel-id="runs"',
        ),
      );
      expect(dashboard.body, contains('compact-runs-summary'));
      expect(dashboard.body, contains('data-testid="run-detail"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel run-detail-panel" data-testid="run-detail" data-panel-id="run-detail"',
        ),
      );
      expect(dashboard.body, contains('data-testid="launcher-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel launcher-panel" data-testid="launcher-panel" data-panel-id="launcher"',
        ),
      );
      expect(dashboard.body, contains('Workflow Launcher'));
      expect(dashboard.body, contains('compact-launcher-summary'));
      expect(dashboard.body, contains('data-testid="launch-result-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="subpanel collapsible-panel" data-testid="launch-result-panel" data-panel-id="launch-result" open>',
        ),
      );
      expect(dashboard.body, contains('data-testid="payload-preview-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="subpanel collapsible-panel" data-testid="payload-preview-panel" data-panel-id="payload-preview" open>',
        ),
      );
      expect(dashboard.body, contains('subpanel-summary'));
      expect(dashboard.body, contains('subpanel-body'));
      expect(dashboard.body, contains('justify-content: flex-start'));
      expect(dashboard.body, contains('panel-heading-row'));
      expect(dashboard.body, contains('collapsible-panel'));
      expect(dashboard.body, contains('panel-summary'));
      expect(dashboard.body, contains('data-testid="timeline-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel timeline-panel" data-testid="timeline-panel" data-panel-id="timeline"',
        ),
      );
      expect(dashboard.body, contains('data-testid="timeline-list"'));
      expect(dashboard.body, contains('data-testid="timeline-context"'));
      expect(dashboard.body, contains('function renderTimelineContext()'));
      expect(dashboard.body, contains('function eventFilterLabel()'));
      expect(dashboard.body, contains('function syncEventFilterButtons()'));
      expect(dashboard.body, contains('aria-pressed="true">all</button>'));
      expect(dashboard.body, contains('context-pill'));
      expect(dashboard.body, contains('activeScopeId'));
      expect(dashboard.body, contains('function activeScopeLabel()'));
      expect(dashboard.body, contains('isolation'));
      expect(dashboard.body, contains('mixed sessions'));
      expect(dashboard.body, contains('data-testid="evidence-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel evidence-panel" data-testid="evidence-panel" data-panel-id="evidence"',
        ),
      );
      expect(dashboard.body, contains('data-testid="artifact-gallery"'));
      expect(dashboard.body, contains('data-testid="inspector-panel"'));
      expect(
        dashboard.body,
        contains(
          '<details class="panel collapsible-panel inspector-panel" data-testid="inspector-panel" data-panel-id="inspector"',
        ),
      );
      expect(dashboard.body, contains('id="collapsePanels"'));
      expect(dashboard.body, contains('id="expandPanels"'));
      expect(dashboard.body, contains('PANEL_STATE_STORAGE_KEY'));
      expect(dashboard.body, contains('localStorage.setItem'));
      expect(dashboard.body, contains('function restorePanelState()'));
      expect(dashboard.body, contains('function setPanelGroupOpen(open)'));
      expect(dashboard.body, contains('renderJsonTree'));
      expect(dashboard.body, contains('renderYamlTree'));
      expect(dashboard.body, contains('renderArtifactPreview'));
      expect(dashboard.body, contains('scopeSelect'));
      expect(dashboard.body, contains('resetSelectedRunCaches'));
      expect(dashboard.body, contains('selectionRevision'));
      expect(dashboard.body, contains('selectedEventKey'));
      expect(dashboard.body, contains('function eventKey(event)'));
      expect(dashboard.body, contains('function eventForArtifact(artifact)'));
      expect(dashboard.body, contains('function refreshScopeEvents()'));
      expect(dashboard.body, contains('artifactRunId'));
      expect(dashboard.body, contains('const initialScope'));
      expect(dashboard.body, contains('pinnedScopeId'));
      expect(dashboard.body, contains('scopeMode'));
      expect(dashboard.body, contains('requestedScope'));
      expect(dashboard.body, contains('function scopeModeLabel()'));
      expect(dashboard.body, contains('following latest'));
      expect(dashboard.body, contains('pinned scope'));
      expect(dashboard.body, contains('follow latest:'));
      expect(dashboard.body, contains('hasResolvedInitialScope'));
      expect(dashboard.body, contains('function replaceUrlScope(scopeId)'));
      expect(dashboard.body, contains('function replaceUrlWithLatestScope()'));
      expect(dashboard.body, contains('history.replaceState'));
      expect(dashboard.body, contains('function selectRun(runId)'));
      expect(dashboard.body, contains('function selectScope(scopeId)'));
      expect(dashboard.body, contains('function requestedScopeKey()'));
      expect(dashboard.body, contains('function isCurrentSelection'));
      expect(dashboard.body, contains("runParams.set('scope'"));
      expect(dashboard.body, contains('fetchJson(runPath)'));
      expect(dashboard.body, contains('selectScope(els.scopeSelect.value)'));
      expect(dashboard.body, contains('button.dataset.runId'));
      expect(dashboard.body, contains('button.dataset.scopeId'));
      expect(
        dashboard.body,
        contains("current.textContent = state.currentScopeId"),
      );
      expect(dashboard.body, contains(r'latest: ${scopeLabelFor'));
      expect(dashboard.body, contains("initialScope === 'latest'"));
      expect(dashboard.body, contains('replaceUrlScope(index.scopeId)'));
      expect(dashboard.body, contains('scopeKey !== requestedScopeKey()'));
      expect(dashboard.body, contains("params.set('runLimit'"));
      expect(
        dashboard.body,
        contains('if (!isCurrentSelection(revision, runId)) return'),
      );
      expect(
        dashboard.body,
        contains('event.runId && event.runId !== options.runId'),
      );
      expect(dashboard.body, contains('activeScopeLabel()'));
      expect(dashboard.body, contains('state.runs = []'));
      expect(dashboard.body, contains('media-status'));
      expect(dashboard.body, contains('open artifact'));
      expect(dashboard.body, contains('video.currentTime'));
      expect(dashboard.body, contains('artifactPriority'));
      expect(dashboard.body, contains('EAGER_ARTIFACT_COUNT'));
      expect(dashboard.body, contains('renderArtifactCard(artifact, event,'));
      expect(
        dashboard.body,
        isNot(contains('candidate.seq === artifact.eventSeq')),
      );
      expect(dashboard.body, contains('data-testid="media-viewer"'));
      expect(dashboard.body, contains('media-viewer-dialog'));
      expect(
        dashboard.body,
        contains(
          '<details class="media-viewer-dialog media-viewer-panel collapsible-panel" data-panel-id="media-viewer" data-panel-persist="true" open',
        ),
      );
      expect(dashboard.body, contains('media-viewer-toolbar panel-summary'));
      expect(dashboard.body, contains('openMediaViewer'));
      expect(dashboard.body, contains('video.controls = false'));
      expect(dashboard.body, contains('video.tabIndex = -1'));
      expect(dashboard.body, contains('.artifact-media video'));
      expect(dashboard.body, contains('pointer-events: none'));
      expect(dashboard.body, contains('openMediaViewer(artifact, media)'));
      expect(dashboard.body, contains('download</a>'));
      expect(dashboard.body, contains('copy link'));
      expect(dashboard.body, contains('actual size'));
      expect(dashboard.body, contains('.media-viewer-actions'));
      expect(dashboard.body, contains('mediaViewerReturnFocus'));
      expect(dashboard.body, contains('TIMELINE_RENDER_LIMIT'));
      expect(dashboard.body, contains('timeline-scroll'));
      expect(dashboard.body, contains('timelineScroll'));
      expect(dashboard.body, contains('timelineSummary'));
      expect(dashboard.body, contains('event(s) match'));
      expect(dashboard.body, contains('oldest to newest'));
      expect(
        dashboard.body,
        contains(
          'const events = matchingEvents.slice(-TIMELINE_RENDER_LIMIT);',
        ),
      );
      expect(
        dashboard.body,
        isNot(
          contains('matchingEvents.slice(-TIMELINE_RENDER_LIMIT).reverse()'),
        ),
      );
      expect(dashboard.body, contains('loading events'));
      expect(
        dashboard.body,
        contains("els.timelineSummary.textContent = 'loading events'"),
      );
      expect(dashboard.body, contains("selectScope('');"));
      expect(
        dashboard.body,
        contains('const totalEventCount = Number(state.scopeEventCount'),
      );
      expect(
        dashboard.body,
        contains(r'`${state.events.length}/${totalEventCount} loaded, `'),
      );
      expect(
        dashboard.body,
        contains(
          'els.eventCount.textContent = String(state.scopeEventCount || counts.eventCount || state.events.length || 0)',
        ),
      );
      expect(dashboard.body, contains('function renderSignature()'));
      expect(dashboard.body, contains('countArtifactRefs(state.events)'));
      expect(dashboard.body, contains('eventKey(firstEvent)'));
      expect(dashboard.body, contains('eventKey(lastEvent)'));
      expect(dashboard.body, contains('parentWorkflowStepId'));
      expect(dashboard.body, contains('rootWorkflowStepId'));
      expect(dashboard.body, contains("details.relation === 'retry'"));
      expect(dashboard.body, contains("details.relation === 'loop'"));
      expect(dashboard.body, contains('.event:not([open]) .event-description'));
      expect(
        dashboard.body,
        contains("const item = document.createElement('details');"),
      );
      expect(dashboard.body, contains('event-summary panel-summary'));
      expect(dashboard.body, contains('item.open = expanded'));
      expect(dashboard.body, contains('ensureEventDetailsRendered'));
      expect(dashboard.body, contains('payloadPreviewDirty'));
      expect(dashboard.body, contains("!els.launcherPanel.open"));
      expect(
        dashboard.body,
        contains("els.launcherPanel.addEventListener('toggle'"),
      );
      expect(dashboard.body, contains('INITIAL_EVENT_TAIL_BYTES'));
      expect(dashboard.body, contains('fetchEventsIncremental'));
      expect(dashboard.body, contains('initialTailWholeLines'));
      expect(dashboard.body, contains('panel-heading-actions'));
      expect(dashboard.body, contains('.timeline-panel > .panel-summary'));
      expect(
        dashboard.body,
        contains(r'headers.range = `bytes=${state.eventsByteOffset}-`'),
      );
      expect(dashboard.body, isNot(contains('lastEventsText')));
      expect(
        dashboard.body,
        isNot(contains('JSON.stringify({\n        runId: state.selectedRunId')),
      );
      expect(
        dashboard.body.indexOf('data-testid="timeline-list"'),
        lessThan(dashboard.body.indexOf('data-testid="artifact-gallery"')),
      );
      expect(dashboard.body, isNot(contains('https://')));

      final unauthorized = await _get(handle.uri.resolve('/api/runs'));
      expect(unauthorized.statusCode, HttpStatus.unauthorized);

      final runs = await _get(handle.uri.resolve('/api/runs?token=secret'));
      expect(runs.statusCode, HttpStatus.ok);
      final runsJson = jsonDecode(runs.body) as Map<String, Object?>;
      expect(runsJson['runCount'], 1);

      final state = await _get(
        handle.uri.resolve('/api/runs/run-1/state?token=secret'),
      );
      expect(state.statusCode, HttpStatus.ok);
      expect(jsonDecode(state.body), containsPair('runId', 'run-1'));

      final events = await _get(
        handle.uri.resolve('/api/runs/run-1/events.ndjson?token=secret'),
      );
      expect(events.statusCode, HttpStatus.ok);
      expect(events.body.trim(), contains('"type":"run_started"'));

      final scopeEvents = await _get(
        handle.uri.resolve('/api/events?token=secret&scope=default'),
      );
      expect(scopeEvents.statusCode, HttpStatus.ok);
      final scopeEventsJson =
          jsonDecode(scopeEvents.body) as Map<String, Object?>;
      expect(scopeEventsJson['scopeId'], 'default');
      expect(scopeEventsJson['returnedEventCount'], 1);
      expect(
        (scopeEventsJson['events']! as List<Object?>).single,
        allOf(
          containsPair('runId', 'run-1'),
          containsPair('eventKey', 'run-1#1'),
        ),
      );

      final sse = await _getSsePrefix(
        handle.uri.resolve('/api/runs/run-1/events?token=secret'),
      );
      expect(sse.statusCode, HttpStatus.ok);
      _expectSecurityHeaders(sse.headers);
      expect(sse.headers.contentType?.mimeType, 'text/event-stream');
      expect(sse.body, contains('event: run_started'));

      final bundleSummary = await _get(
        handle.uri.resolve('/api/runs/run-1/bundle-summary?token=secret'),
      );
      expect(bundleSummary.statusCode, HttpStatus.ok);
      final bundleSummaryJson =
          jsonDecode(bundleSummary.body) as Map<String, Object?>;
      expect(bundleSummaryJson['schemaVersion'], 1);
      expect(bundleSummaryJson['status'], 'failed');
      expect(
        bundleSummaryJson['artifactRefs'],
        contains(containsPair('relativePath', 'recordings/fallback.mp4')),
      );
      expect(
        bundleSummaryJson['primaryRecordingRef'],
        'recordings/fallback.mp4',
      );
      expect(bundleSummaryJson, isNot(contains('trace')));
      expect(bundleSummaryJson['traceSummary'], containsPair('entryCount', 1));
      expect(
        bundleSummaryJson['artifactRefs'],
        contains(containsPair('relativePath', 'diagnostics/trace.json')),
      );

      final screenshot = await _getBytes(
        handle.uri.resolve(
          '/api/runs/run-1/artifacts/screenshots/first.png?token=secret',
        ),
      );
      expect(screenshot.statusCode, HttpStatus.ok);
      _expectSecurityHeaders(screenshot.headers);
      expect(screenshot.body, <int>[1, 2, 3]);

      final traversal = await _get(
        handle.uri.resolve(
          '/api/runs/run-1/artifacts/%252E%252E/x?token=secret',
        ),
      );
      expect(traversal.statusCode, HttpStatus.forbidden);
    });

    test(
      'serves empty history as current scope without mixing future runs',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_empty_history_scope_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final response = await _get(
          handle.uri.resolve('/api/runs?token=secret'),
        );

        expect(response.statusCode, HttpStatus.ok);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['runCount'], 0);
        expect(decoded['filteredRunCount'], 0);
        expect(decoded['scopeMode'], 'current');
        expect(decoded['scopeId'], 'all');
        expect(decoded['scopes'], isEmpty);
        expect(decoded['runs'], isEmpty);
      },
    );

    test('filters run history by scope and exposes scope metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_scoped_runs_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final older = CockpitLiveRunStore(
        historyRoot: tempDir.path,
        runId: 'old-run',
        clock: _FixedClock(DateTime.utc(2026, 6, 19, 10)),
      );
      await older.initialize(
        sessionId: 'old-session',
        taskId: 'old-task',
        platform: 'macos',
      );
      final newer = CockpitLiveRunStore(
        historyRoot: tempDir.path,
        runId: 'new-run',
        clock: _FixedClock(DateTime.utc(2026, 6, 19, 11)),
      );
      await newer.initialize(
        sessionId: 'new-session',
        taskId: 'new-task',
        platform: 'android',
      );

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final defaultRuns = await _get(
        handle.uri.resolve('/api/runs?token=secret'),
      );
      expect(defaultRuns.statusCode, HttpStatus.ok);
      final defaultJson = jsonDecode(defaultRuns.body) as Map<String, Object?>;
      expect(defaultJson['scopeId'], 'new-session');
      expect(defaultJson['scopeMode'], 'current');
      expect(defaultJson['scopeKind'], 'session');
      expect(defaultJson['scopeLabel'], 'new-task');
      expect(defaultJson['filteredRunCount'], 1);
      expect(
        (defaultJson['runs']! as List<Object?>).single,
        containsPair('runId', 'new-run'),
      );
      expect(
        (defaultJson['scopes']! as List<Object?>).cast<Map<String, Object?>>(),
        hasLength(2),
      );

      final allRuns = await _get(
        handle.uri.resolve('/api/runs?token=secret&scope=all'),
      );
      final allJson = jsonDecode(allRuns.body) as Map<String, Object?>;
      expect(allJson['scopeId'], 'all');
      expect(allJson['scopeMode'], 'all');
      expect(allJson.containsKey('scopeLabel'), isFalse);
      expect(allJson['filteredRunCount'], 2);
      expect(
        (allJson['runs']! as List<Object?>).cast<Map<String, Object?>>().map(
          (run) => run['runId'],
        ),
        <String>['new-run', 'old-run'],
      );

      for (final alias in <String>['current', 'latest']) {
        final aliasedRuns = await _get(
          handle.uri.resolve('/api/runs?token=secret&scope=$alias'),
        );
        expect(aliasedRuns.statusCode, HttpStatus.ok);
        final aliasedJson =
            jsonDecode(aliasedRuns.body) as Map<String, Object?>;
        expect(aliasedJson['scopeId'], 'new-session');
        expect(aliasedJson['scopeMode'], alias);
        expect(aliasedJson['requestedScope'], alias);
        expect(aliasedJson['scopeKind'], 'session');
        expect(aliasedJson['scopeLabel'], 'new-task');
        expect(aliasedJson['filteredRunCount'], 1);
        expect(
          (aliasedJson['runs']! as List<Object?>).single,
          containsPair('runId', 'new-run'),
        );
      }

      final oldSession = await _get(
        handle.uri.resolve('/api/runs?token=secret&sessionId=old-session'),
      );
      final oldJson = jsonDecode(oldSession.body) as Map<String, Object?>;
      expect(oldJson['scopeId'], 'old-session');
      expect(oldJson['scopeKind'], 'session');
      expect(oldJson['scopeLabel'], 'old-task');
      expect(oldJson['filteredRunCount'], 1);
      expect(
        (oldJson['runs']! as List<Object?>).single,
        containsPair('runId', 'old-run'),
      );
    });

    test(
      'keeps repeated workflow runs isolated by session scope until all runs are requested',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_session_scope_history_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final runSpecs =
            <({String runId, String sessionId, String taskId, int minute})>[
              (
                runId: 'checkout-run-1',
                sessionId: 'checkout-flow',
                taskId: 'checkout-proof-v1',
                minute: 0,
              ),
              (
                runId: 'checkout-run-2',
                sessionId: 'checkout-flow',
                taskId: 'checkout-proof-v2',
                minute: 1,
              ),
              (
                runId: 'settings-run-1',
                sessionId: 'settings-flow',
                taskId: 'settings-proof',
                minute: 2,
              ),
            ];
        for (final spec in runSpecs) {
          final store = CockpitLiveRunStore(
            historyRoot: tempDir.path,
            runId: spec.runId,
            displayName: spec.taskId,
            clock: _FixedClock(DateTime.utc(2026, 6, 19, 12, spec.minute)),
          );
          await store.initialize(
            sessionId: spec.sessionId,
            taskId: spec.taskId,
            platform: 'macos',
          );
        }

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final latestResponse = await _get(
          handle.uri.resolve('/api/runs?token=secret'),
        );
        expect(latestResponse.statusCode, HttpStatus.ok);
        final latestJson =
            jsonDecode(latestResponse.body) as Map<String, Object?>;
        expect(latestJson['scopeId'], 'settings-flow');
        expect(latestJson['scopeMode'], 'current');
        expect(latestJson['filteredRunCount'], 1);
        expect(
          (latestJson['runs']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map((run) => run['runId']),
          <String>['settings-run-1'],
        );

        final checkoutResponse = await _get(
          handle.uri.resolve('/api/runs?token=secret&scope=checkout-flow'),
        );
        expect(checkoutResponse.statusCode, HttpStatus.ok);
        final checkoutJson =
            jsonDecode(checkoutResponse.body) as Map<String, Object?>;
        expect(checkoutJson['scopeId'], 'checkout-flow');
        expect(checkoutJson['scopeKind'], 'session');
        expect(checkoutJson['filteredRunCount'], 2);
        expect(
          (checkoutJson['runs']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .map((run) => run['runId']),
          <String>['checkout-run-2', 'checkout-run-1'],
        );

        final allResponse = await _get(
          handle.uri.resolve('/api/runs?token=secret&scope=all'),
        );
        expect(allResponse.statusCode, HttpStatus.ok);
        final allJson = jsonDecode(allResponse.body) as Map<String, Object?>;
        expect(allJson['scopeId'], 'all');
        expect(allJson['filteredRunCount'], 3);
        expect(
          (allJson['runs']! as List<Object?>).cast<Map<String, Object?>>().map(
            (run) => run['runId'],
          ),
          <String>['settings-run-1', 'checkout-run-2', 'checkout-run-1'],
        );
      },
    );

    test(
      'serves session-scope timeline events across repeated runs in chronological order',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_scope_events_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final first = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout-run-1',
          displayName: 'checkout attempt 1',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 12)),
        );
        await first.initialize(
          sessionId: 'checkout-flow',
          taskId: 'checkout-proof',
          platform: 'macos',
        );
        await first.appendEvent(
          type: 'artifact_captured',
          status: 'running',
          artifactRefs: const <Map<String, Object?>>[
            <String, Object?>{
              'role': 'screenshot',
              'relativePath': 'screenshots/first.png',
            },
          ],
        );

        final second = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'checkout-run-2',
          displayName: 'checkout attempt 2',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 12, 1)),
        );
        await second.initialize(
          sessionId: 'checkout-flow',
          taskId: 'checkout-proof',
          platform: 'macos',
        );
        await second.appendEvent(
          type: 'workflow_step_completed',
          status: 'completed',
          workflowStepId: 'finish',
        );

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final response = await _get(
          handle.uri.resolve(
            '/api/events?token=secret&scope=checkout-flow&limit=10',
          ),
        );

        expect(response.statusCode, HttpStatus.ok);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['scopeId'], 'checkout-flow');
        expect(decoded['scopeKind'], 'session');
        expect(decoded['eventCount'], 2);
        expect(decoded['returnedEventCount'], 2);
        final events = (decoded['events']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(events.map((event) => event['eventKey']), <String>[
          'checkout-run-1#1',
          'checkout-run-2#1',
        ]);
        expect(events.map((event) => event['runId']), <String>[
          'checkout-run-1',
          'checkout-run-2',
        ]);
        expect(
          (events.first['artifactRefs']! as List<Object?>).single,
          containsPair('runId', 'checkout-run-1'),
        );

        final latest = await _get(
          handle.uri.resolve('/api/events?token=secret&limit=10'),
        );
        final latestJson = jsonDecode(latest.body) as Map<String, Object?>;
        expect(latestJson['scopeId'], 'checkout-flow');
        expect(latestJson['returnedEventCount'], 2);
      },
    );

    test('pages run history while keeping scope metadata', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_run_paging_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      for (var index = 0; index < 3; index += 1) {
        final store = CockpitLiveRunStore(
          historyRoot: tempDir.path,
          runId: 'run-$index',
          clock: _FixedClock(DateTime.utc(2026, 6, 19, 10, index)),
        );
        await store.initialize(
          sessionId: 'session',
          taskId: 'task-$index',
          platform: 'macos',
        );
      }

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final firstPage = await _get(
        handle.uri.resolve('/api/runs?token=secret&scope=all&limit=2'),
      );
      expect(firstPage.statusCode, HttpStatus.ok);
      final firstJson = jsonDecode(firstPage.body) as Map<String, Object?>;
      expect(firstJson['runCount'], 3);
      expect(firstJson['filteredRunCount'], 3);
      expect(firstJson['returnedRunCount'], 2);
      expect(firstJson['offset'], 0);
      expect(firstJson['limit'], 2);
      expect(firstJson['hasMoreRuns'], isTrue);
      expect(
        (firstJson['runs']! as List<Object?>).cast<Map<String, Object?>>().map(
          (run) => run['runId'],
        ),
        <String>['run-2', 'run-1'],
      );
      expect(firstJson['scopes'], isNotEmpty);

      final secondPage = await _get(
        handle.uri.resolve('/api/runs?token=secret&scope=all&limit=2&offset=2'),
      );
      final secondJson = jsonDecode(secondPage.body) as Map<String, Object?>;
      expect(secondJson['returnedRunCount'], 1);
      expect(secondJson['hasMoreRuns'], isFalse);
      expect(
        (secondJson['runs']! as List<Object?>).single,
        containsPair('runId', 'run-0'),
      );

      final allRuns = await _get(
        handle.uri.resolve('/api/runs?token=secret&scope=all&limit=0'),
      );
      final allJson = jsonDecode(allRuns.body) as Map<String, Object?>;
      expect(allJson['returnedRunCount'], 3);
      expect(allJson['limit'], 0);
      expect(allJson['hasMoreRuns'], isFalse);
    });

    test('derives a current scope for legacy run indexes', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_legacy_scope_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeLegacyScopedIndex(tempDir);

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final response = await _get(handle.uri.resolve('/api/runs?token=secret'));

      expect(response.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      expect(decoded['scopeId'], 'new-session');
      expect(decoded['scopeKind'], 'session');
      expect(decoded['scopeLabel'], 'new-task');
      expect(decoded['currentScopeId'], 'new-session');
      expect(decoded['filteredRunCount'], 1);
      expect(
        (decoded['runs']! as List<Object?>).single,
        allOf(
          containsPair('runId', 'new-run'),
          containsPair('scopeId', 'new-session'),
          containsPair('scopeKind', 'session'),
          containsPair('scopeLabel', 'new-task'),
        ),
      );
    });

    test(
      'streams byte ranges for recordings without loading whole files',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_range_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        await _writeRunFixture(tempDir);

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final response = await _getBytes(
          handle.uri.resolve(
            '/api/runs/run-1/bundle/recordings/flow.mp4?token=secret',
          ),
          headers: const <String, String>{'range': 'bytes=2-5'},
        );

        expect(response.statusCode, HttpStatus.partialContent);
        _expectSecurityHeaders(response.headers);
        expect(
          response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes 2-5/10',
        );
        expect(response.body, <int>[2, 3, 4, 5]);

        final mov = await _getBytes(
          handle.uri.resolve(
            '/api/runs/run-1/bundle/recordings/simulator.mov?token=secret',
          ),
        );
        expect(mov.statusCode, HttpStatus.ok);
        expect(mov.headers.contentType?.mimeType, 'video/quicktime');

        final eventsFile = File(
          p.join(tempDir.path, 'runs', 'run-1', 'live', 'events.ndjson'),
        );
        final eventsTail = eventsFile.readAsStringSync().substring(
          eventsFile.lengthSync() - 8,
        );
        final tail = await _getBytes(
          handle.uri.resolve('/api/runs/run-1/events.ndjson?token=secret'),
          headers: const <String, String>{'range': 'bytes=-8'},
        );
        expect(tail.statusCode, HttpStatus.partialContent);
        expect(
          tail.headers.value(HttpHeaders.contentRangeHeader),
          'bytes ${eventsFile.lengthSync() - 8}-${eventsFile.lengthSync() - 1}/${eventsFile.lengthSync()}',
        );
        expect(utf8.decode(tail.body), eventsTail);
      },
    );

    test('skips malformed SSE event lines', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_sse_malformed_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeRunFixture(tempDir);
      final eventsFile = File(
        p.join(tempDir.path, 'runs', 'run-1', 'live', 'events.ndjson'),
      );
      eventsFile.writeAsStringSync(
        'not-json\n${eventsFile.readAsStringSync()}',
      );

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final sse = await _getSsePrefix(
        handle.uri.resolve('/api/runs/run-1/events?token=secret'),
      );

      expect(sse.statusCode, HttpStatus.ok);
      expect(sse.body, contains('event: run_started'));
    });

    test(
      'summarizes recent trace entries instead of earliest entries',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_trace_recent_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        await _writeRunFixture(tempDir);
        File(
          p.join(tempDir.path, 'runs', 'run-1', 'bundle', 'trace.json'),
        ).writeAsStringSync(
          jsonEncode(<String, Object?>{
            'entries': List<Object?>.generate(
              8,
              (index) => <String, Object?>{
                'stepIndex': index,
                'workflowStepId': 'step-$index',
                'actionType': 'command',
              },
            ),
          }),
        );

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final bundleSummary = await _get(
          handle.uri.resolve('/api/runs/run-1/bundle-summary?token=secret'),
        );
        expect(bundleSummary.statusCode, HttpStatus.ok);
        final decoded = jsonDecode(bundleSummary.body) as Map<String, Object?>;
        final traceSummary = decoded['traceSummary']! as Map<String, Object?>;
        final recentEntries = traceSummary['recentEntries']! as List<Object?>;
        expect(traceSummary['entryCount'], 8);
        expect(
          recentEntries.cast<Map<String, Object?>>().map(
            (entry) => entry['stepIndex'],
          ),
          <int>[2, 3, 4, 5, 6, 7],
        );
      },
    );

    test('skips oversized trace JSON when serving bundle summary', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_trace_large_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeRunFixture(tempDir);
      final tracePath = p.join(
        tempDir.path,
        'runs',
        'run-1',
        'bundle',
        'trace.json',
      );
      File(tracePath).writeAsStringSync(
        '{"entries":[],"padding":"${List<String>.filled(5 * 1024 * 1024, "x").join()}"}',
      );

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final bundleSummary = await _get(
        handle.uri.resolve('/api/runs/run-1/bundle-summary?token=secret'),
      );
      expect(bundleSummary.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(bundleSummary.body) as Map<String, Object?>;
      final traceSummary = decoded['traceSummary']! as Map<String, Object?>;
      expect(traceSummary['skipped'], isTrue);
      expect(traceSummary['reason'], 'fileTooLarge');
      expect(traceSummary['relativePath'], 'trace.json');
      expect(traceSummary['fileSizeBytes'], greaterThan(4 * 1024 * 1024));
      expect(
        decoded['summaryFileIssues'],
        contains(
          allOf(
            containsPair('relativePath', 'trace.json'),
            containsPair('reason', 'fileTooLarge'),
          ),
        ),
      );
      expect(decoded['artifactRefs'], isNotEmpty);
    });

    test('reports invalid bundle JSON without failing the dashboard', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_invalid_bundle_json_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeRunFixture(tempDir);
      File(
        p.join(tempDir.path, 'runs', 'run-1', 'bundle', 'delivery.json'),
      ).writeAsStringSync('{"summary":');
      File(
        p.join(tempDir.path, 'runs', 'run-1', 'bundle', 'trace.json'),
      ).writeAsStringSync('[]');

      final server = CockpitDevtoolsServer(
        historyRoot: tempDir.path,
        token: 'secret',
      );
      final handle = await server.start();
      addTearDown(handle.close);

      final bundleSummary = await _get(
        handle.uri.resolve('/api/runs/run-1/bundle-summary?token=secret'),
      );

      expect(bundleSummary.statusCode, HttpStatus.ok);
      final decoded = jsonDecode(bundleSummary.body) as Map<String, Object?>;
      expect(decoded['status'], 'failed');
      expect(
        decoded['artifactRefs'],
        contains(containsPair('relativePath', 'screenshots/first.png')),
      );
      expect(
        decoded['summaryFileIssues'],
        contains(
          allOf(
            containsPair('relativePath', 'delivery.json'),
            containsPair('reason', 'invalidJson'),
          ),
        ),
      );
      expect(
        decoded['summaryFileIssues'],
        contains(
          allOf(
            containsPair('relativePath', 'trace.json'),
            containsPair('reason', 'invalidJson'),
          ),
        ),
      );
      expect(
        decoded['traceSummary'],
        allOf(
          containsPair('relativePath', 'trace.json'),
          containsPair('reason', 'invalidJson'),
        ),
      );
    });
  });
}

Future<void> _writeRunFixture(Directory root) async {
  final runDir = Directory(p.join(root.path, 'runs', 'run-1'));
  final liveDir = Directory(p.join(runDir.path, 'live'))
    ..createSync(recursive: true);
  final bundleDir = Directory(p.join(runDir.path, 'bundle'))
    ..createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'screenshots')).createSync();
  Directory(p.join(bundleDir.path, 'recordings')).createSync();
  Directory(p.join(bundleDir.path, 'keyframes')).createSync();
  File(
    p.join(bundleDir.path, 'screenshots', 'first.png'),
  ).writeAsBytesSync(<int>[1, 2, 3]);
  File(
    p.join(bundleDir.path, 'recordings', 'flow.mp4'),
  ).writeAsBytesSync(List<int>.generate(10, (index) => index));
  File(
    p.join(bundleDir.path, 'recordings', 'fallback.mp4'),
  ).writeAsBytesSync(List<int>.generate(8, (index) => index));
  File(
    p.join(bundleDir.path, 'keyframes', 'tail.png'),
  ).writeAsBytesSync(<int>[1, 2, 3, 4]);
  File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'sessionId': 'session-1',
      'taskId': 'task-1',
      'platform': 'macos',
      'status': 'failed',
      'artifactRefs': <Object?>[
        <String, Object?>{
          'role': 'screenshot',
          'relativePath': 'screenshots/first.png',
        },
        <String, Object?>{
          'role': 'recording',
          'relativePath': 'recordings/fallback.mp4',
        },
      ],
      'recordingCount': 1,
      'deliveryVideoReady': true,
    }),
  );
  File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'summary': 'Delivery blocked by task failure',
      'primaryScreenshotRef': 'screenshots/first.png',
      'primaryRecordingRef': 'recordings/fallback.mp4',
      'deliveryVideoSynthesized': true,
      'deliveryVideoSource': 'timelineFallback',
      'keyframes': <Object?>[
        <String, Object?>{
          'ref': 'keyframes/tail.png',
          'label': 'tail',
          'offsetMs': 1200,
          'source': 'tailConsistency',
        },
      ],
    }),
  );
  File(p.join(bundleDir.path, 'issue_evidence.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'recommendedNextStep': 'inspect_issue_evidence',
      'gateFailures': <Object?>[
        <String, Object?>{
          'gate': 'recordingReadyOrExplained',
          'failureCodes': <Object?>['recordingFailed'],
        },
      ],
    }),
  );
  Directory(p.join(bundleDir.path, 'diagnostics')).createSync();
  File(
    p.join(bundleDir.path, 'diagnostics', 'trace.json'),
  ).writeAsBytesSync(<int>[5, 6, 7]);
  File(p.join(bundleDir.path, 'trace.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'entries': <Object?>[
        <String, Object?>{
          'stepIndex': 1,
          'workflowStepId': 'trace-step',
          'actionType': 'command',
          'artifactRefs': <Object?>[
            <String, Object?>{
              'role': 'diagnostics',
              'relativePath': 'diagnostics/trace.json',
              'largePayload': 'this should not be copied into summary',
            },
          ],
        },
      ],
    }),
  );
  File(
    p.join(bundleDir.path, 'recordings', 'simulator.mov'),
  ).writeAsBytesSync(List<int>.generate(4, (index) => index));
  File(p.join(liveDir.path, 'live_state.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'runId': 'run-1',
      'status': 'running',
      'startedAt': '2026-06-19T10:00:00.000Z',
      'updatedAt': '2026-06-19T10:00:01.000Z',
      'counts': <String, Object?>{'eventCount': 1},
    }),
  );
  File(p.join(liveDir.path, 'events.ndjson')).writeAsStringSync(
    '${jsonEncode(<String, Object?>{'schemaVersion': 1, 'runId': 'run-1', 'seq': 1, 'timestamp': '2026-06-19T10:00:00.000Z', 'type': 'run_started', 'status': 'running'})}\n',
  );
  File(p.join(root.path, 'index.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'updatedAt': '2026-06-19T10:00:01.000Z',
      'runCount': 1,
      'runs': <Object?>[
        <String, Object?>{
          'runId': 'run-1',
          'status': 'running',
          'updatedAt': '2026-06-19T10:00:01.000Z',
          'runDir': p.join('runs', 'run-1'),
          'liveDir': p.join('runs', 'run-1', 'live'),
          'bundleDir': p.join('runs', 'run-1', 'bundle'),
        },
      ],
    }),
  );
}

Future<void> _writeLegacyScopedIndex(Directory root) async {
  File(p.join(root.path, 'index.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'updatedAt': '2026-06-19T11:00:00.000Z',
      'runCount': 2,
      'runs': <Object?>[
        <String, Object?>{
          'runId': 'new-run',
          'status': 'completed',
          'updatedAt': '2026-06-19T11:00:00.000Z',
          'runDir': p.join('runs', 'new-run'),
          'liveDir': p.join('runs', 'new-run', 'live'),
          'sessionId': 'new-session',
          'taskId': 'new-task',
          'platform': 'android',
        },
        <String, Object?>{
          'runId': 'old-run',
          'status': 'failed',
          'updatedAt': '2026-06-19T10:00:00.000Z',
          'runDir': p.join('runs', 'old-run'),
          'liveDir': p.join('runs', 'old-run', 'live'),
          'sessionId': 'old-session',
          'taskId': 'old-task',
          'platform': 'macos',
        },
      ],
    }),
  );
}

Future<_TextResponse> _get(Uri uri) async {
  final bytes = await _getBytes(uri);
  return _TextResponse(
    statusCode: bytes.statusCode,
    headers: bytes.headers,
    body: utf8.decode(bytes.body),
  );
}

void _expectSecurityHeaders(HttpHeaders headers) {
  expect(headers.value('x-content-type-options'), 'nosniff');
  expect(headers.value('x-frame-options'), 'SAMEORIGIN');
  expect(headers.value('x-xss-protection'), '1; mode=block');
}

Future<_TextResponse> _postJson(Uri uri, Map<String, Object?> body) async {
  final client = HttpClient();
  addTearDown(client.close);
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  final response = await request.close();
  final bytes = await response.fold<List<int>>(
    <int>[],
    (buffer, chunk) => buffer..addAll(chunk),
  );
  return _TextResponse(
    statusCode: response.statusCode,
    headers: response.headers,
    body: utf8.decode(bytes),
  );
}

Future<_TextResponse> _getSsePrefix(Uri uri) async {
  final client = HttpClient();
  final request = await client.getUrl(uri);
  final response = await request.close();
  final chunks = <int>[];
  final completer = Completer<void>();
  late final StreamSubscription<List<int>> subscription;
  try {
    subscription = response.listen(
      (chunk) {
        chunks.addAll(chunk);
        final text = utf8.decode(chunks, allowMalformed: true);
        if (!completer.isCompleted && text.contains('event: ')) {
          completer.complete();
        }
      },
      onError: completer.completeError,
      onDone: completer.complete,
    );
    await completer.future.timeout(const Duration(seconds: 3));
    return _TextResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: utf8.decode(chunks, allowMalformed: true),
    );
  } finally {
    await subscription.cancel();
    client.close(force: true);
  }
}

Future<_BytesResponse> _getBytes(
  Uri uri, {
  Map<String, String> headers = const <String, String>{},
}) async {
  final client = HttpClient();
  addTearDown(client.close);
  final request = await client.getUrl(uri);
  for (final entry in headers.entries) {
    request.headers.set(entry.key, entry.value);
  }
  final response = await request.close();
  final body = await response.fold<List<int>>(
    <int>[],
    (bytes, chunk) => bytes..addAll(chunk),
  );
  return _BytesResponse(
    statusCode: response.statusCode,
    headers: response.headers,
    body: body,
  );
}

final class _TextResponse {
  const _TextResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

final class _BytesResponse {
  const _BytesResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final HttpHeaders headers;
  final List<int> body;
}

final class _FixedClock implements CockpitClock {
  const _FixedClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/app',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 12345,
    devicePort: 12345,
    baseUrl: 'http://127.0.0.1:12345',
    launchedAt: DateTime.utc(2026, 6, 19),
  );
}

Future<void> _eventually(Future<void> Function() assertion) async {
  Object? lastError;
  StackTrace? lastStackTrace;
  for (var attempt = 0; attempt < 40; attempt += 1) {
    try {
      await assertion();
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}
