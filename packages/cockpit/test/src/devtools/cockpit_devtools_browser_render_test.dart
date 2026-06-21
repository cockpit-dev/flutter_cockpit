import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cockpit/cockpit.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Cockpit Devtools browser rendering', () {
    test(
      'renders scoped runs, timeline, media, and live updates in Chrome',
      () async {
        final chrome = _findChromeExecutable();
        if (chrome == null) {
          markTestSkipped('Chrome/Chromium executable was not found.');
          return;
        }

        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_browser_render_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final fixtureStores = await _writeBrowserFixture(tempDir);

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final browser = await _ChromeCdpBrowser.start(chrome);
        addTearDown(browser.close);
        final tab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{
              'token': 'secret',
              'scope': 'current',
            },
          ),
        );
        await tab.setViewport(width: 1280, height: 900);
        await tab.reload();

        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 1 && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('change-settings')",
        );
        final initial = await tab.evaluateMap('''
(() => {
  const text = (selector) => document.querySelector(selector)?.textContent || '';
  const attr = (selector, name) => document.querySelector(selector)?.getAttribute(name) || '';
  const allText = (selector) => Array.from(document.querySelectorAll(selector)).map((node) => node.textContent || '');
  const media = Array.from(document.querySelectorAll('.artifact-media img, .artifact-media video')).map((node) => ({
    tag: node.tagName,
    src: node.currentSrc || node.src || '',
    complete: node.tagName === 'IMG' ? node.complete : undefined,
    naturalWidth: node.naturalWidth || undefined,
    readyState: node.tagName === 'VIDEO' ? node.readyState : undefined,
    videoWidth: node.videoWidth || undefined,
    duration: Number.isFinite(node.duration) ? node.duration : null
  }));
  return {
    url: location.href,
    status: text('#status'),
    selectedStatus: text('#selectedStatus'),
    runCount: text('#runCount'),
    eventCount: text('#eventCount'),
    artifactCount: text('#artifactCount'),
    scopeValue: document.querySelector('[data-testid="scope-select"]').value,
    scopeOptions: allText('[data-testid="scope-select"] option'),
    runs: allText('.run'),
    timeline: text('[data-testid="timeline-list"]'),
    timelineSummary: text('#timelineSummary'),
    timelineContext: text('[data-testid="timeline-context"]'),
    facts: text('#runFacts'),
    artifactSummary: text('#artifactSummary'),
    artifacts: allText('.artifact'),
    media,
    timelineScrollClientHeight: document.querySelector('[data-testid="timeline-scroll"]').clientHeight,
    timelineScrollHeight: document.querySelector('[data-testid="timeline-scroll"]').scrollHeight,
    renderedEvents: document.querySelectorAll('[data-testid="timeline-list"] .event').length,
    firstEvent: document.querySelector('[data-testid="timeline-list"] .event')?.textContent || '',
    lastEvent: Array.from(document.querySelectorAll('[data-testid="timeline-list"] .event')).at(-1)?.textContent || '',
    inspector: text('#inspector'),
    payloadPreviewDetails: document.querySelectorAll('#payloadPreview details').length,
    launcherOpen: document.querySelector('[data-testid="launcher-panel"]').open,
    runDetailOpen: document.querySelector('[data-testid="run-detail"]').open,
    timelineOpen: document.querySelector('[data-testid="timeline-panel"]').open,
    evidenceOpen: document.querySelector('[data-testid="evidence-panel"]').open
  };
})()
''');

        expect(initial['url'], contains('scope=settings-flow'));
        expect(initial['selectedStatus'], 'running');
        expect(initial['runCount'], '1');
        expect(initial['eventCount'], '170');
        expect(
          int.parse(initial['artifactCount']! as String),
          greaterThanOrEqualTo(3),
        );
        expect(initial['scopeValue'], 'settings-flow');
        expect(
          initial['scopeOptions'] as List<Object?>,
          containsAll(<String>[
            'all runs (3)',
            'Settings flow (1)',
            'Checkout proof (2)',
          ]),
        );
        expect(
          (initial['runs']! as List<Object?>).single,
          contains('Settings proof'),
        );
        expect(initial['timelineContext'], contains('scope: Settings flow'));
        expect(initial['timelineContext'], contains('mode: pinned scope'));
        expect(initial['timelineContext'], contains('isolation: session'));
        expect(
          initial['timelineSummary'],
          contains('showing latest 120 of 170 event(s)'),
        );
        expect(initial['timelineSummary'], contains('oldest to newest'));
        expect(initial['timelineSummary'], contains('selected Settings proof'));
        expect(initial['timeline'], contains('change-settings'));
        expect(initial['timeline'], contains('loop 2/3'));
        expect(initial['timeline'], contains('try 2/3'));
        expect(initial['timeline'], contains('settings-run-final.webm'));
        expect(initial['timeline'], isNot(contains('checkout-run-')));
        expect(initial['facts'], contains('settings-flow'));
        expect(initial['facts'], contains('Settings flow'));
        expect(initial['artifactSummary'], contains('linked artifact'));
        expect(initial['artifacts'], isNotEmpty);
        expect(initial['renderedEvents'], 120);
        expect(initial['firstEvent'], contains('#51'));
        expect(initial['lastEvent'], contains('#170'));
        expect(initial['timelineScrollClientHeight'], greaterThan(0));
        expect(
          initial['timelineScrollHeight'],
          greaterThanOrEqualTo(initial['timelineScrollClientHeight'] as int),
        );
        expect(initial['payloadPreviewDetails'], 0);
        expect(initial['launcherOpen'], isFalse);
        expect(initial['runDetailOpen'], isFalse);
        expect(initial['timelineOpen'], isTrue);
        expect(initial['evidenceOpen'], isTrue);
        final desktopScreenshot = img.decodePng(
          await tab.captureScreenshotPng(),
        );
        expect(desktopScreenshot, isNotNull);
        expect(desktopScreenshot!.width, greaterThanOrEqualTo(800));
        expect(desktopScreenshot.height, greaterThanOrEqualTo(500));

        await tab.waitForExpression('''
Array.from(document.querySelectorAll('.artifact-media img')).some((img) => img.complete && img.naturalWidth > 0) &&
Array.from(document.querySelectorAll('.artifact-media video')).some((video) => video.readyState >= 1 && video.videoWidth > 0)
''');
        final media = await tab.evaluateList('''
(() => Array.from(document.querySelectorAll('.artifact-media img, .artifact-media video')).map((node) => ({
  tag: node.tagName,
  src: node.currentSrc || node.src || '',
  complete: node.tagName === 'IMG' ? node.complete : undefined,
  naturalWidth: node.naturalWidth || undefined,
  readyState: node.tagName === 'VIDEO' ? node.readyState : undefined,
  videoWidth: node.videoWidth || undefined,
  duration: Number.isFinite(node.duration) ? node.duration : null
})))()
''');
        expect(
          media.cast<Map<String, Object?>>(),
          contains(
            allOf(
              containsPair('tag', 'IMG'),
              containsPair('complete', true),
              containsPair('naturalWidth', 160),
            ),
          ),
        );
        expect(
          media.cast<Map<String, Object?>>(),
          contains(
            allOf(
              containsPair('tag', 'VIDEO'),
              containsPair('readyState', greaterThanOrEqualTo(1)),
              containsPair('videoWidth', 96),
            ),
          ),
        );

        await tab.click("document.querySelector('.artifact-media.clickable')");
        await tab.waitForExpression(
          '!document.querySelector("[data-testid=\\"media-viewer\\"]").hidden && '
          'document.querySelector("#mediaViewerStage img, #mediaViewerStage video") && '
          'Array.from(document.querySelectorAll("#mediaViewerStage img, #mediaViewerStage video")).some((node) => '
          'node.tagName === "IMG" ? node.complete && node.naturalWidth > 0 : node.readyState >= 1 && node.videoWidth > 0'
          ')',
        );
        final viewer = await tab.evaluateMap('''
(() => ({
  hidden: document.querySelector('[data-testid="media-viewer"]').hidden,
  title: document.querySelector('#mediaViewerTitle').textContent,
  path: document.querySelector('#mediaViewerPath').textContent,
  download: document.querySelector('#mediaViewerDownload').getAttribute('download'),
  href: document.querySelector('#mediaViewerDownload').href,
  stageTag: document.querySelector('#mediaViewerStage img, #mediaViewerStage video').tagName,
  mediaReady: (() => {
    const node = document.querySelector('#mediaViewerStage img, #mediaViewerStage video');
    if (!node) return false;
    return node.tagName === 'IMG'
      ? node.complete && node.naturalWidth > 0
      : node.readyState >= 1 && node.videoWidth > 0;
  })(),
  mediaWidth: (() => {
    const node = document.querySelector('#mediaViewerStage img, #mediaViewerStage video');
    return node ? (node.naturalWidth || node.videoWidth || 0) : 0;
  })(),
  renderedWidth: (() => {
    const node = document.querySelector('#mediaViewerStage img, #mediaViewerStage video');
    return node ? Math.round(node.getBoundingClientRect().width) : 0;
  })(),
  renderedHeight: (() => {
    const node = document.querySelector('#mediaViewerStage img, #mediaViewerStage video');
    return node ? Math.round(node.getBoundingClientRect().height) : 0;
  })(),
  bodyLocked: document.body.classList.contains('media-viewer-open')
}))()
''');
        expect(viewer['hidden'], isFalse);
        expect(viewer['path'], contains('settings-run'));
        expect(viewer['href'], contains('/api/runs/settings-run/bundle/'));
        expect(viewer['download'], isNotEmpty);
        expect(viewer['stageTag'], isIn(<String>['IMG', 'VIDEO']));
        expect(viewer['mediaReady'], isTrue);
        expect(viewer['mediaWidth'], greaterThan(0));
        expect(viewer['renderedWidth'], greaterThan(0));
        expect(viewer['renderedHeight'], greaterThan(0));
        expect(viewer['bodyLocked'], isTrue);

        await tab.click("document.querySelector('#mediaViewerSize')");
        final actualSize = await tab.evaluateMap('''
(() => ({
  actual: document.querySelector('#mediaViewerStage').classList.contains('actual'),
  button: document.querySelector('#mediaViewerSize').textContent
}))()
''');
        expect(actualSize['actual'], isTrue);
        expect(actualSize['button'], 'fit screen');

        await tab.click("document.querySelector('#mediaViewerClose')");
        await tab.waitForExpression(
          'document.querySelector("[data-testid=\\"media-viewer\\"]").hidden',
        );

        await tab.click(
          "Array.from(document.querySelectorAll('.artifact-media.clickable')).find((node) => node.querySelector('video'))",
        );
        await tab.waitForExpression(
          '!document.querySelector("[data-testid=\\"media-viewer\\"]").hidden && '
          'document.querySelector("#mediaViewerStage video") && '
          'document.querySelector("#mediaViewerStage video").readyState >= 1 && '
          'document.querySelector("#mediaViewerStage video").videoWidth > 0',
        );
        final videoViewer = await tab.evaluateMap('''
(() => {
  const video = document.querySelector('#mediaViewerStage video');
  return {
    path: document.querySelector('#mediaViewerPath').textContent,
    download: document.querySelector('#mediaViewerDownload').getAttribute('download'),
    href: document.querySelector('#mediaViewerDownload').href,
    controls: video.controls,
    readyState: video.readyState,
    videoWidth: video.videoWidth,
    renderedWidth: Math.round(video.getBoundingClientRect().width),
    renderedHeight: Math.round(video.getBoundingClientRect().height)
  };
})()
''');
        expect(videoViewer['path'], contains('recordings/settings-run'));
        expect(videoViewer['download'], endsWith('.webm'));
        expect(videoViewer['href'], contains('/recordings/settings-run'));
        expect(videoViewer['controls'], isTrue);
        expect(videoViewer['readyState'], greaterThanOrEqualTo(1));
        expect(videoViewer['videoWidth'], greaterThan(0));
        expect(videoViewer['renderedWidth'], greaterThan(0));
        expect(videoViewer['renderedHeight'], greaterThan(0));
        await tab.click("document.querySelector('#mediaViewerClose')");
        await tab.waitForExpression(
          'document.querySelector("[data-testid=\\"media-viewer\\"]").hidden',
        );

        await tab.click(
          "document.querySelector('[data-testid=\"launcher-panel\"] > summary')",
        );
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"launcher-panel\"]').open && "
          "document.querySelectorAll('#payloadPreview details').length >= 2",
        );
        final launcher = await tab.evaluateMap('''
(() => ({
  payloadDetails: document.querySelectorAll('#payloadPreview details').length,
  payloadText: document.querySelector('#payloadPreview').textContent,
  resultText: document.querySelector('#launchResult').textContent
}))()
''');
        expect(launcher['payloadDetails'], greaterThanOrEqualTo(2));
        expect(launcher['payloadText'], contains('schemaVersion'));
        expect(launcher['payloadText'], contains('assert-ready'));

        await tab.click("document.querySelector('#parseWorkflow')");
        await tab.waitForExpression(
          "document.querySelector('#launchResult').textContent.includes('requestsRecording') && "
          "document.querySelector('#launchResult').textContent.includes('dashboard-session') && "
          "document.querySelectorAll('#launchResult details').length >= 4",
        );
        final parsedWorkflow = await tab.evaluateMap('''
(() => ({
  text: document.querySelector('#launchResult').textContent,
  details: document.querySelectorAll('#launchResult details').length,
  rootOpen: document.querySelector('#launchResult details.root')?.open,
  hasYamlClass: document.querySelector('#launchResult').classList.contains('yaml-tree')
}))()
''');
        expect(parsedWorkflow['text'], contains('requestsRecording'));
        expect(parsedWorkflow['text'], contains('dashboard-session'));
        expect(parsedWorkflow['text'], contains('assert-ready'));
        expect(parsedWorkflow['details'], greaterThanOrEqualTo(4));
        expect(parsedWorkflow['rootOpen'], isTrue);
        expect(parsedWorkflow['hasYamlClass'], isFalse);

        await tab.click("document.querySelector('#formatJson')");
        await tab.waitForExpression(
          "document.querySelector('#launchPayload').value.trim().startsWith('{') && "
          "document.querySelectorAll('#payloadPreview details').length >= 1",
        );
        final jsonPayload = await tab.evaluateMap('''
(() => ({
  payload: document.querySelector('#launchPayload').value,
  previewText: document.querySelector('#payloadPreview').textContent,
  rootOpen: document.querySelector('#payloadPreview details.root')?.open,
  nestedDetails: document.querySelectorAll('#payloadPreview details').length
}))()
''');
        expect(jsonPayload['payload'], contains('"kind"'));
        expect(jsonPayload['payload'], contains('"scriptText"'));
        expect(jsonPayload['payload'], contains('schemaVersion: 1'));
        expect(jsonPayload['previewText'], contains('root'));
        expect(jsonPayload['previewText'], contains('scriptText'));
        expect(jsonPayload['rootOpen'], isTrue);
        expect(jsonPayload['nestedDetails'], greaterThanOrEqualTo(1));

        await tab.click("document.querySelector('#formatYaml')");
        await tab.waitForExpression(
          "!document.querySelector('#launchPayload').value.trim().startsWith('{') && "
          "document.querySelectorAll('#payloadPreview details').length >= 2",
        );
        await tab.click("document.querySelector('#tabYaml')");
        await tab.waitForExpression(
          "document.querySelector('#tabYaml').getAttribute('aria-selected') === 'true' && "
          "document.querySelector('#inspector').textContent.includes('schemaVersion')",
        );
        final yamlInspector = await tab.evaluateMap('''
(() => ({
  selected: document.querySelector('#tabYaml').getAttribute('aria-selected'),
  text: document.querySelector('#inspector').textContent,
  treeCount: document.querySelectorAll('#inspector details').length,
  hasYamlClass: document.querySelector('#inspector').classList.contains('yaml-tree')
}))()
''');
        expect(yamlInspector['selected'], 'true');
        expect(yamlInspector['text'], contains('schemaVersion'));
        expect(yamlInspector['text'], contains('assert-ready'));
        expect(yamlInspector['treeCount'], greaterThanOrEqualTo(2));
        expect(yamlInspector['hasYamlClass'], isTrue);

        await tab.click("document.querySelector('#tabState')");
        await tab.waitForExpression(
          "document.querySelector('#tabState').getAttribute('aria-selected') === 'true' && "
          "document.querySelector('#inspector').textContent.includes('bundleSummary')",
        );
        final stateInspector = await tab.evaluateMap('''
(() => ({
  selected: document.querySelector('#tabState').getAttribute('aria-selected'),
  text: document.querySelector('#inspector').textContent,
  details: document.querySelectorAll('#inspector details').length,
  hasYamlClass: document.querySelector('#inspector').classList.contains('yaml-tree')
}))()
''');
        expect(stateInspector['selected'], 'true');
        expect(stateInspector['text'], contains('liveState'));
        expect(stateInspector['text'], contains('bundleSummary'));
        expect(stateInspector['details'], greaterThanOrEqualTo(4));
        expect(stateInspector['hasYamlClass'], isFalse);

        await tab.click("document.querySelector('#tabEvent')");
        await tab.waitForExpression(
          "document.querySelector('#tabEvent').getAttribute('aria-selected') === 'true'",
        );

        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#launchPayload');
  input.value = JSON.stringify({
    kind: 'runScript',
    schemaVersion: 1,
    sessionId: 'json-dashboard-session',
    taskId: 'json-dashboard-task',
    platform: 'macos',
    steps: [
      {
        stepId: 'open-settings',
        stepType: 'command',
        command: {
          commandId: 'tap-settings',
          commandType: 'tap',
          locator: {text: 'Settings'},
          parameters: {expectedRouteName: '/settings'}
        }
      }
    ]
  }, null, 2);
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelectorAll('#payloadPreview details').length >= 5 && "
          "document.querySelector('#payloadPreview').textContent.includes('expectedRouteName')",
        );
        final nestedJsonPreview = await tab.evaluateMap('''
(() => ({
  details: document.querySelectorAll('#payloadPreview details').length,
  text: document.querySelector('#payloadPreview').textContent,
  rootOpen: document.querySelector('#payloadPreview details.root')?.open,
  nestedClosed: Array.from(document.querySelectorAll('#payloadPreview details')).some((node) => !node.open)
}))()
''');
        expect(nestedJsonPreview['details'], greaterThanOrEqualTo(5));
        expect(nestedJsonPreview['text'], contains('expectedRouteName'));
        expect(nestedJsonPreview['rootOpen'], isTrue);
        expect(nestedJsonPreview['nestedClosed'], isTrue);

        await tab.click("document.querySelector('[data-filter=\"artifact\"]')");
        await tab.waitForExpression(
          "document.querySelector('[data-filter=\"artifact\"]').getAttribute('aria-pressed') === 'true' && "
          "document.querySelector('#timelineSummary').textContent.includes('match artifact filter')",
        );
        final artifactFilter = await tab.evaluateMap('''
(() => ({
  summary: document.querySelector('#timelineSummary').textContent,
  eventCount: document.querySelectorAll('[data-testid="timeline-list"] .event').length,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent
}))()
''');
        expect(
          artifactFilter['summary'],
          contains('event(s) match artifact filter'),
        );
        expect(artifactFilter['eventCount'], greaterThan(0));
        expect(artifactFilter['eventCount'], lessThan(120));
        expect(artifactFilter['timeline'], contains('artifact'));

        await tab.click("document.querySelector('[data-filter=\"failed\"]')");
        await tab.waitForExpression(
          "document.querySelector('[data-filter=\"failed\"]').getAttribute('aria-pressed') === 'true' && "
          "document.querySelector('#timelineSummary').textContent.includes('match error filter')",
        );
        final noSettingsErrors = await tab.evaluateMap('''
(() => ({
  summary: document.querySelector('#timelineSummary').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent
}))()
''');
        expect(
          noSettingsErrors['summary'],
          contains('0/170 event(s) match error filter'),
        );
        expect(
          noSettingsErrors['timeline'],
          contains('no events match the active filter'),
        );

        await tab.click("document.querySelector('[data-filter=\"all\"]')");
        await tab.waitForExpression(
          "document.querySelector('[data-filter=\"all\"]').getAttribute('aria-pressed') === 'true'",
        );

        await tab.click("document.querySelector('#collapsePanels')");
        await tab.waitForExpression(
          '!document.querySelector("[data-testid=\\"timeline-panel\\"]").open && '
          '!document.querySelector("[data-testid=\\"evidence-panel\\"]").open',
        );
        await tab.reload();
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 1",
        );
        final persistedPanels = await tab.evaluateMap('''
(() => ({
  timelineOpen: document.querySelector('[data-testid="timeline-panel"]').open,
  evidenceOpen: document.querySelector('[data-testid="evidence-panel"]').open,
  runsOpen: document.querySelector('[data-testid="runs-panel"]').open
}))()
''');
        expect(persistedPanels['timelineOpen'], isFalse);
        expect(persistedPanels['evidenceOpen'], isFalse);
        expect(persistedPanels['runsOpen'], isFalse);
        await tab.click("document.querySelector('#expandPanels')");
        await tab.waitForExpression(
          'document.querySelector("[data-testid=\\"timeline-panel\\"]").open && '
          'document.querySelector("[data-testid=\\"evidence-panel\\"]").open',
        );

        await tab.select(
          "document.querySelector('[data-testid=\"scope-select\"]')",
          'all',
        );
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('mixed sessions') && "
          "document.querySelectorAll('.run').length === 3",
        );
        final allRuns = await tab.evaluateMap('''
(() => ({
  url: location.href,
  runCount: document.querySelector('#runCount').textContent,
  context: document.querySelector('[data-testid="timeline-context"]').textContent,
  summary: document.querySelector('#timelineSummary').textContent,
  runs: Array.from(document.querySelectorAll('.run')).map((node) => node.textContent),
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent
}))()
''');
        expect(allRuns['url'], contains('scope=all'));
        expect(allRuns['runCount'], '3');
        expect(allRuns['context'], contains('mixed sessions'));
        expect(allRuns['summary'], contains('showing latest 120 of'));
        expect(
          allRuns['runs'],
          contains(
            predicate<String>((text) => text.contains('Checkout retry')),
          ),
        );
        expect(allRuns['timeline'], contains('settings-run'));

        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#runSearch');
  input.value = 'checkout retry';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 1 && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('Checkout retry')",
        );
        final runSearch = await tab.evaluateMap('''
(() => ({
  runs: Array.from(document.querySelectorAll('.run')).map((node) => node.textContent),
  empty: document.querySelector('[data-testid="run-list"]').textContent
}))()
''');
        expect(
          (runSearch['runs']! as List<Object?>).single,
          contains('Checkout retry'),
        );
        expect(runSearch['empty'], isNot(contains('Settings proof')));
        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#runSearch');
  input.value = 'not-a-real-run';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('no runs match the filter')",
        );
        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#runSearch');
  input.value = '';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 3",
        );

        await tab.select(
          "document.querySelector('[data-testid=\"scope-select\"]')",
          'checkout-flow',
        );
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('Checkout proof') && "
          "document.querySelectorAll('.run').length === 2",
        );
        final checkout = await tab.evaluateMap('''
(() => ({
  url: location.href,
  runCount: document.querySelector('#runCount').textContent,
  context: document.querySelector('[data-testid="timeline-context"]').textContent,
  runs: Array.from(document.querySelectorAll('.run')).map((node) => node.textContent),
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent
}))()
''');
        expect(checkout['url'], contains('scope=checkout-flow'));
        expect(checkout['runCount'], '2');
        expect(checkout['context'], contains('Checkout proof'));
        expect(checkout['timeline'], contains('checkout-run-2'));
        expect(checkout['timeline'], isNot(contains('settings-run')));

        await tab.click("document.querySelector('[data-filter=\"failed\"]')");
        await tab.waitForExpression(
          "document.querySelector('#timelineSummary').textContent.includes('match error filter') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('Checkout confirmation text did not appear')",
        );
        await tab.click(
          "document.querySelector('[data-testid=\"timeline-list\"] .event summary')",
        );
        await tab.waitForExpression(
          "document.querySelector('#selectedStatus').textContent === 'failed' && "
          "document.querySelector('[data-testid=\"timeline-list\"] .event[aria-selected=\"true\"]')",
        );
        final checkoutFailure = await tab.evaluateMap('''
(() => ({
  summary: document.querySelector('#timelineSummary').textContent,
  selectedStatus: document.querySelector('#selectedStatus').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  inspector: document.querySelector('#inspector').textContent,
  selectedEventCount: document.querySelectorAll('[data-testid="timeline-list"] .event[aria-selected="true"]').length
}))()
''');
        expect(
          checkoutFailure['summary'],
          contains('event(s) match error filter'),
        );
        expect(checkoutFailure['selectedStatus'], 'failed');
        expect(
          checkoutFailure['timeline'],
          contains('Checkout confirmation text did not appear'),
        );
        expect(checkoutFailure['inspector'], contains('assertTextFailed'));
        expect(checkoutFailure['selectedEventCount'], 1);

        await tab.click("document.querySelector('[data-filter=\"artifact\"]')");
        await tab.waitForExpression(
          "document.querySelector('#timelineSummary').textContent.includes('match artifact filter') && "
          "document.querySelectorAll('[data-testid=\"timeline-list\"] .event').length > 0",
        );
        await tab.click(
          "document.querySelector('[data-testid=\"timeline-list\"] .event summary')",
        );
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-list\"] .event[aria-selected=\"true\"]') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('diagnostics')",
        );
        final checkoutArtifacts = await tab.evaluateMap('''
(() => {
  const artifactCards = Array.from(document.querySelectorAll('.artifact'));
  return {
    summary: document.querySelector('#timelineSummary').textContent,
    timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
    gallery: document.querySelector('[data-testid="artifact-gallery"]').textContent,
    placeholderCount: document.querySelectorAll('.artifact-media .placeholder').length,
    clickableMediaCount: document.querySelectorAll('.artifact-media.clickable').length,
    artifactLinks: artifactCards.map((node) => node.textContent)
  };
})()
''');
        expect(
          checkoutArtifacts['summary'],
          contains('event(s) match artifact filter'),
        );
        expect(checkoutArtifacts['timeline'], contains('diagnostics'));
        expect(checkoutArtifacts['gallery'], contains('diagnostics'));
        expect(checkoutArtifacts['placeholderCount'], greaterThan(0));
        expect(checkoutArtifacts['clickableMediaCount'], greaterThan(0));
        expect(
          checkoutArtifacts['artifactLinks'],
          contains(predicate<String>((text) => text.contains('diagnostics'))),
        );

        await tab.click(
          "Array.from(document.querySelectorAll('.artifact summary')).find((node) => node.textContent.includes('diagnostics'))",
        );
        await tab.waitForExpression(
          "document.querySelector('#inspector').textContent.includes('diagnostics') && "
          "document.querySelector('[data-testid=\"timeline-list\"] .event[aria-selected=\"true\"]').textContent.includes('diagnostics')",
        );
        final artifactSelection = await tab.evaluateMap('''
(() => ({
  inspector: document.querySelector('#inspector').textContent,
  selectedEvent: document.querySelector('[data-testid="timeline-list"] .event[aria-selected="true"]').textContent,
  selectedRun: document.querySelector('.run[aria-current="true"]').textContent
}))()
''');
        expect(artifactSelection['inspector'], contains('diagnostics'));
        expect(artifactSelection['selectedEvent'], contains('diagnostics'));
        expect(
          artifactSelection['selectedRun'],
          contains('Checkout first attempt'),
        );

        await tab.click("document.querySelector('[data-filter=\"all\"]')");
        await tab.waitForExpression(
          "document.querySelector('[data-filter=\"all\"]').getAttribute('aria-pressed') === 'true'",
        );

        final settingsStore = fixtureStores['settings-run']!;
        await settingsStore.appendEvent(
          type: 'workflow_step_completed',
          status: 'completed',
          workflowStepId: 'live-refresh',
          workflowStepType: 'command',
          description:
              'Fresh live event appended after the dashboard was open.',
        );

        await tab.select(
          "document.querySelector('[data-testid=\"scope-select\"]')",
          'settings-flow',
        );
        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('live-refresh')",
          timeout: const Duration(seconds: 4),
        );
        final liveRefresh = await tab.evaluateMap('''
(() => ({
  eventCount: document.querySelector('#eventCount').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  summary: document.querySelector('#timelineSummary').textContent
}))()
''');
        expect(liveRefresh['eventCount'], '171');
        expect(liveRefresh['timeline'], contains('live-refresh'));
        expect(liveRefresh['summary'], contains('171 event(s)'));

        await tab.setViewport(width: 390, height: 740);
        await tab.reload();
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 1",
        );
        final mobile = await tab.evaluateMap('''
(() => {
  const mainStyle = getComputedStyle(document.querySelector('main'));
  const railStyle = getComputedStyle(document.querySelector('.rail'));
  const timelineScroll = document.querySelector('[data-testid="timeline-scroll"]');
  return {
    columns: mainStyle.gridTemplateColumns,
    railPosition: railStyle.position,
    timelineClientHeight: timelineScroll.clientHeight,
    timelineScrollHeight: timelineScroll.scrollHeight,
    bodyWidth: document.body.scrollWidth,
    viewportWidth: innerWidth
  };
})()
''');
        expect(mobile['columns'], isNot(contains('420px')));
        expect(mobile['railPosition'], 'static');
        expect(mobile['timelineClientHeight'], greaterThan(0));
        expect(
          mobile['timelineScrollHeight'],
          greaterThanOrEqualTo(mobile['timelineClientHeight'] as int),
        );
        expect(
          mobile['bodyWidth'],
          lessThanOrEqualTo((mobile['viewportWidth'] as int) + 2),
        );
        final mobileScreenshot = img.decodePng(
          await tab.captureScreenshotPng(),
        );
        expect(mobileScreenshot, isNotNull);
        expect(mobileScreenshot!.width, 390);
        expect(mobileScreenshot.height, 740);
        tab.expectNoPageErrors();
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'renders empty and unauthorized states without stale data',
      () async {
        final chrome = _findChromeExecutable();
        if (chrome == null) {
          markTestSkipped('Chrome/Chromium executable was not found.');
          return;
        }

        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_empty_browser_test',
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

        final browser = await _ChromeCdpBrowser.start(chrome);
        addTearDown(browser.close);

        final emptyTab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{'token': 'secret'},
          ),
        );
        await emptyTab.waitForExpression(
          "document.querySelector('#runCount').textContent === '0'",
        );
        final empty = await emptyTab.evaluateMap('''
(() => ({
  status: document.querySelector('#status').textContent,
  runCount: document.querySelector('#runCount').textContent,
  eventCount: document.querySelector('#eventCount').textContent,
  artifactCount: document.querySelector('#artifactCount').textContent,
  runs: document.querySelector('[data-testid="run-list"]').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  context: document.querySelector('[data-testid="timeline-context"]').textContent,
  artifacts: document.querySelector('[data-testid="artifact-gallery"]').textContent
}))()
''');
        expect(empty['runCount'], '0');
        expect(empty['eventCount'], '0');
        expect(empty['artifactCount'], '0');
        expect(empty['runs'], contains('no live runs yet'));
        expect(empty['timeline'], contains('no events recorded yet'));
        expect(empty['context'], contains('scope: no runs'));
        expect(
          empty['artifacts'],
          contains('Screenshots, keyframes, recordings'),
        );

        final unauthorizedTab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{'token': 'wrong'},
          ),
        );
        await unauthorizedTab.waitForExpression(
          "document.querySelector('#status').textContent.includes('401')",
        );
        final unauthorized = await unauthorizedTab.evaluateMap('''
(() => ({
  status: document.querySelector('#status').textContent,
  runs: document.querySelector('[data-testid="run-list"]').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent
}))()
''');
        expect(unauthorized['status'], contains('401'));
        expect(unauthorized['runs'], contains('loading run history'));
        expect(unauthorized['timeline'], contains('loading events'));
        emptyTab.expectNoPageErrors();
        unauthorizedTab.expectNoPageErrors();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'renders direct scopes, latest follow, broken media, and submitted jobs',
      () async {
        final chrome = _findChromeExecutable();
        if (chrome == null) {
          markTestSkipped('Chrome/Chromium executable was not found.');
          return;
        }

        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_real_modes_browser_test',
        );
        final releaseSubmittedRun = Completer<void>();
        addTearDown(() async {
          if (!releaseSubmittedRun.isCompleted) {
            releaseSubmittedRun.complete();
          }
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        await _writeBrowserFixture(tempDir);
        final submittedRequest =
            Completer<CockpitRunRemoteControlScriptRequest>();

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
          runScript: (request) async {
            if (!submittedRequest.isCompleted) {
              submittedRequest.complete(request);
            }
            await releaseSubmittedRun.future;
            final bundleDir = Directory(
              p.join(request.outputRoot, 'runs', 'submitted-job', 'bundle'),
            )..createSync(recursive: true);
            Directory(
              p.join(bundleDir.path, 'screenshots'),
            ).createSync(recursive: true);
            _writePng(
              p.join(bundleDir.path, 'screenshots', 'submitted-final.png'),
              labelHash: request.script.taskId.hashCode,
            );
            File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
              jsonEncode(<String, Object?>{
                'sessionId': request.script.sessionId,
                'taskId': request.script.taskId,
                'platform': request.script.platform,
                'status': 'completed',
                'screenshotCount': 1,
                'artifactRefs': <Object?>[
                  <String, Object?>{
                    'role': 'screenshot',
                    'relativePath': 'screenshots/submitted-final.png',
                  },
                ],
              }),
            );
            File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
              jsonEncode(<String, Object?>{
                'summary': 'Submitted dashboard job completed.',
                'primaryScreenshotRef': 'screenshots/submitted-final.png',
              }),
            );
            File(p.join(bundleDir.path, 'trace.json')).writeAsStringSync(
              jsonEncode(<String, Object?>{'entries': <Object?>[]}),
            );
            return CockpitRunRemoteControlScriptResult(
              sessionHandle: request.sessionHandle,
              bundleDir: bundleDir,
              manifest: CockpitRunManifest(
                sessionId: request.script.sessionId,
                taskId: request.script.taskId,
                platform: request.script.platform,
                status: CockpitTaskStatus.completed,
                startedAt: DateTime.utc(2026, 6, 19, 14),
                finishedAt: DateTime.utc(2026, 6, 19, 14, 0, 1),
              ),
              handoff: const <String, Object?>{},
              delivery: const <String, Object?>{},
              artifactPaths: CockpitBundleArtifactPaths(),
            );
          },
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final browser = await _ChromeCdpBrowser.start(chrome);
        addTearDown(browser.close);

        final checkoutTab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{
              'token': 'secret',
              'scope': 'checkout-flow',
            },
          ),
        );
        await checkoutTab.setViewport(width: 1180, height: 820);
        await checkoutTab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('Checkout proof') && "
          "document.querySelectorAll('.run').length === 2",
        );
        final directScope = await checkoutTab.evaluateMap('''
(() => ({
  url: location.href,
  scopeValue: document.querySelector('[data-testid="scope-select"]').value,
  runCount: document.querySelector('#runCount').textContent,
  context: document.querySelector('[data-testid="timeline-context"]').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  selectedStatus: document.querySelector('#selectedStatus').textContent
}))()
''');
        expect(directScope['url'], contains('scope=checkout-flow'));
        expect(directScope['scopeValue'], 'checkout-flow');
        expect(directScope['runCount'], '2');
        expect(directScope['context'], contains('pinned scope'));
        expect(directScope['context'], contains('Checkout proof'));
        expect(directScope['timeline'], contains('checkout-run-2'));
        expect(directScope['timeline'], isNot(contains('settings-run')));

        final latestTab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{
              'token': 'secret',
              'scope': 'latest',
            },
          ),
        );
        await latestTab.setViewport(width: 1280, height: 900);
        await latestTab.waitForExpression(
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('Settings flow') && "
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('following latest')",
        );

        await _writeWorkflowRun(
          root: tempDir,
          runId: 'profile-run',
          displayName: 'Profile proof',
          sessionId: 'profile-flow',
          taskId: 'profile-proof',
          scopeLabel: 'Profile flow',
          platform: 'ios',
          startedAt: DateTime.utc(2026, 6, 19, 13),
          status: 'completed',
          eventCount: 6,
          artifactEvery: 3,
          finalBundle: true,
          includeMissingMedia: true,
        );

        await latestTab.waitForExpression(
          "location.href.includes('scope=latest') && "
          "document.querySelector('[data-testid=\"timeline-context\"]').textContent.includes('Profile flow') && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('Profile proof')",
          timeout: const Duration(seconds: 5),
        );
        await latestTab.waitForExpression(
          "Array.from(document.querySelectorAll('.media-status.error')).some((node) => node.textContent.includes('image failed'))",
          timeout: const Duration(seconds: 5),
        );
        final latestFollow = await latestTab.evaluateMap('''
(() => ({
  url: location.href,
  scopeValue: document.querySelector('[data-testid="scope-select"]').value,
  selectedStatus: document.querySelector('#selectedStatus').textContent,
  runCount: document.querySelector('#runCount').textContent,
  context: document.querySelector('[data-testid="timeline-context"]').textContent,
  runs: document.querySelector('[data-testid="run-list"]').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  gallery: document.querySelector('[data-testid="artifact-gallery"]').textContent,
  failedMediaCount: document.querySelectorAll('.media-status.error').length,
  bodyWidth: document.body.scrollWidth,
  viewportWidth: innerWidth
}))()
''');
        expect(latestFollow['url'], contains('scope=latest'));
        expect(latestFollow['scopeValue'], '');
        expect(latestFollow['selectedStatus'], 'completed');
        expect(latestFollow['runCount'], '1');
        expect(latestFollow['context'], contains('Profile flow'));
        expect(latestFollow['context'], contains('following latest'));
        expect(latestFollow['context'], contains('profile-run'));
        expect(latestFollow['runs'], contains('Profile proof'));
        expect(latestFollow['gallery'], contains('profile-run-missing.png'));
        expect(latestFollow['failedMediaCount'], greaterThanOrEqualTo(1));
        expect(
          latestFollow['bodyWidth'],
          lessThanOrEqualTo((latestFollow['viewportWidth'] as int) + 2),
        );

        await latestTab.click(
          "document.querySelector('[data-testid=\"launcher-panel\"] > summary')",
        );
        await latestTab.click("document.querySelector('#submitRun')");
        final submitted = await submittedRequest.future.timeout(
          const Duration(seconds: 4),
        );
        expect(submitted.script.sessionId, 'dashboard-session');
        expect(submitted.script.taskId, 'dashboard-task');
        expect(submitted.liveRunId, isNotNull);

        await latestTab.waitForExpression(
          "document.querySelector('#launchResult').textContent.includes('dashboard-session') && "
          "document.querySelector('#selectedStatus').textContent === 'running' && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('dashboard-task') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('no events recorded yet')",
          timeout: const Duration(seconds: 5),
        );
        await latestTab.click("document.querySelector('#tabState')");
        await latestTab.waitForExpression(
          "document.querySelector('#inspector').textContent.includes('job') && "
          "document.querySelector('#inspector').textContent.includes('running')",
        );

        releaseSubmittedRun.complete();
        await latestTab.click("document.querySelector('#refreshNow')");
        await latestTab.waitForExpression(
          "document.querySelector('#selectedStatus').textContent === 'completed' && "
          "document.querySelector('#inspector').textContent.includes('completed') && "
          "document.querySelector('[data-testid=\"artifact-gallery\"]').textContent.includes('submitted-final.png') && "
          "Array.from(document.querySelectorAll('.artifact-media img')).some((img) => img.complete && img.naturalWidth > 0)",
          timeout: const Duration(seconds: 5),
        );
        final submittedEvidence = await latestTab.evaluateMap('''
(() => ({
  selectedStatus: document.querySelector('#selectedStatus').textContent,
  facts: document.querySelector('#runFacts').textContent,
  gallery: document.querySelector('[data-testid="artifact-gallery"]').textContent,
  imageCount: Array.from(document.querySelectorAll('.artifact-media img')).filter((img) => img.complete && img.naturalWidth > 0).length,
  artifactHref: Array.from(document.querySelectorAll('.artifact-open')).find((node) => node.textContent.includes('open artifact'))?.href || ''
}))()
''');
        expect(submittedEvidence['selectedStatus'], 'completed');
        expect(
          submittedEvidence['facts'],
          contains('runs/submitted-job/bundle'),
        );
        expect(submittedEvidence['gallery'], contains('submitted-final.png'));
        expect(submittedEvidence['imageCount'], greaterThanOrEqualTo(1));
        expect(
          submittedEvidence['artifactHref'],
          contains(
            '/api/runs/${submitted.liveRunId}/bundle/screenshots/submitted-final.png',
          ),
        );

        checkoutTab.expectNoPageErrors();
        latestTab.expectNoPageErrors();
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'renders paged histories, validate-task jobs, and invalid launcher input',
      () async {
        final chrome = _findChromeExecutable();
        if (chrome == null) {
          markTestSkipped('Chrome/Chromium executable was not found.');
          return;
        }

        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_real_dashboard_modes_test',
        );
        final releaseValidation = Completer<void>();
        addTearDown(() async {
          if (!releaseValidation.isCompleted) {
            releaseValidation.complete();
          }
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        await _writePagedHistoryFixture(tempDir, count: 205);
        final submittedValidation = Completer<CockpitValidateTaskRequest>();

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
          validateTask: (request) async {
            if (!submittedValidation.isCompleted) {
              submittedValidation.complete(request);
            }
            await releaseValidation.future;
            return const CockpitValidateTaskResult(
              classification: CockpitValidationClassification.completed,
              recommendedNextStep: 'delivery_ready',
            );
          },
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final browser = await _ChromeCdpBrowser.start(chrome);
        addTearDown(browser.close);
        final tab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{
              'token': 'secret',
              'scope': 'bulk-flow',
            },
          ),
        );
        await tab.setViewport(width: 1280, height: 860);

        await tab.waitForExpression(
          "document.querySelector('#runCount').textContent === '200/205' && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('showing latest 200 of 205 run(s)') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('Bulk proof 205')",
        );
        final paged = await tab.evaluateMap('''
(() => ({
  runCount: document.querySelector('#runCount').textContent,
  eventCount: document.querySelector('#eventCount').textContent,
  visibleRunButtons: document.querySelectorAll('.run').length,
  runList: document.querySelector('[data-testid="run-list"]').textContent,
  timelineSummary: document.querySelector('#timelineSummary').textContent,
  timelineContext: document.querySelector('[data-testid="timeline-context"]').textContent,
  firstRun: document.querySelector('.run')?.textContent || '',
  bodyWidth: document.body.scrollWidth,
  viewportWidth: innerWidth
}))()
''');
        expect(paged['runCount'], '200/205');
        expect(paged['eventCount'], '400');
        expect(paged['visibleRunButtons'], 150);
        expect(paged['runList'], contains('showing latest 200 of 205 run(s)'));
        expect(paged['firstRun'], contains('Bulk proof 205'));
        expect(paged['timelineSummary'], contains('showing latest 120'));
        expect(paged['timelineContext'], contains('Bulk flow'));
        expect(
          paged['bodyWidth'],
          lessThanOrEqualTo((paged['viewportWidth'] as int) + 2),
        );

        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#runSearch');
  input.value = 'bulk proof 204';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 1 && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('Bulk proof 204')",
        );
        final search = await tab.evaluateMap('''
(() => ({
  runCount: document.querySelectorAll('.run').length,
  runText: document.querySelector('[data-testid="run-list"]').textContent
}))()
''');
        expect(search['runCount'], 1);
        expect(search['runText'], contains('Bulk proof 204'));
        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#runSearch');
  input.value = '';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelectorAll('.run').length === 150",
        );

        await tab.click(
          "document.querySelector('[data-testid=\"launcher-panel\"] > summary')",
        );
        await tab.select(
          "document.querySelector('#launchKind')",
          'validateTask',
        );
        final validatePayload = <String, Object?>{
          'request': <String, Object?>{
            'runTask': <String, Object?>{
              'sessionHandle': _sessionHandleJson(),
              'script': <String, Object?>{
                'schemaVersion': 1,
                'sessionId': 'validate-dashboard-session',
                'taskId': 'validate-dashboard-task',
                'platform': 'android',
                'steps': <Object?>[
                  <String, Object?>{
                    'stepId': 'assert-ready',
                    'stepType': 'command',
                    'command': <String, Object?>{
                      'commandId': 'assert-ready',
                      'commandType': 'assertText',
                      'parameters': <String, Object?>{'text': 'Ready'},
                    },
                  },
                ],
              },
            },
            'validation': <String, Object?>{
              'requireArtifactFiles': false,
              'requirePrimaryScreenshot': false,
            },
          },
        };
        await tab.evaluate('''
(() => {
  const input = document.querySelector('#launchPayload');
  input.value = ${jsonEncode(const JsonEncoder.withIndent('  ').convert(validatePayload))};
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.waitForExpression(
          "document.querySelector('#payloadPreview').textContent.includes('validate-dashboard-task') && "
          "document.querySelectorAll('#payloadPreview details').length >= 6",
        );
        await tab.click("document.querySelector('#submitRun')");
        final capturedValidation = await submittedValidation.future.timeout(
          const Duration(seconds: 4),
        );
        final validateRunId = capturedValidation.runTask.liveRunId;
        expect(validateRunId, isNotNull);
        expect(
          capturedValidation.runTask.liveRunDisplayName,
          'validate-dashboard-task',
        );
        expect(capturedValidation.runTask.outputRoot, tempDir.path);

        await tab.waitForExpression(
          "document.querySelector('#selectedStatus').textContent === 'running' && "
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('validate-dashboard-task') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('no events recorded yet')",
          timeout: const Duration(seconds: 5),
        );
        await tab.click("document.querySelector('#tabState')");
        await tab.waitForExpression(
          "document.querySelector('#inspector').textContent.includes('validateTask') && "
          "document.querySelector('#inspector').textContent.includes('running')",
        );

        releaseValidation.complete();
        await tab.click("document.querySelector('#refreshNow')");
        await tab.waitForExpression(
          "document.querySelector('#selectedStatus').textContent === 'completed' && "
          "document.querySelector('#inspector').textContent.includes('classification') && "
          "document.querySelector('#inspector').textContent.includes('delivery_ready')",
          timeout: const Duration(seconds: 5),
        );
        final completedValidation = await tab.evaluateMap('''
(() => ({
  status: document.querySelector('#selectedStatus').textContent,
  facts: document.querySelector('#runFacts').textContent,
  inspector: document.querySelector('#inspector').textContent,
  timeline: document.querySelector('[data-testid="timeline-list"]').textContent,
  scope: document.querySelector('[data-testid="timeline-context"]').textContent
}))()
''');
        expect(completedValidation['status'], 'completed');
        expect(
          completedValidation['facts'],
          contains('validate-dashboard-task'),
        );
        expect(completedValidation['inspector'], contains('completed'));
        expect(completedValidation['inspector'], contains('delivery_ready'));
        expect(
          completedValidation['timeline'],
          contains('no events recorded yet'),
        );
        expect(
          completedValidation['scope'],
          contains('validate-dashboard-task'),
        );

        await tab.evaluate(r'''
(() => {
  const input = document.querySelector('#launchPayload');
  input.value = 'schemaVersion: 1\nsessionId: missing-run-task\n';
  input.dispatchEvent(new Event('input', {bubbles: true}));
})()
''');
        await tab.click("document.querySelector('#submitRun')");
        await tab.waitForExpression(
          "document.querySelector('#launchResult').textContent.includes('validateTask requests must include a runTask object')",
        );
        final invalid = await tab.evaluateMap('''
(() => ({
  launchResult: document.querySelector('#launchResult').textContent,
  selectedStatus: document.querySelector('#selectedStatus').textContent,
  runList: document.querySelector('[data-testid="run-list"]').textContent
}))()
''');
        expect(
          invalid['launchResult'],
          contains('validateTask requests must include a runTask object'),
        );
        expect(invalid['selectedStatus'], 'completed');
        expect(invalid['runList'], contains('validate-dashboard-task'));
        tab.expectNoPageErrors();
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'treats hostile history text and unusual artifact paths as inert content',
      () async {
        final chrome = _findChromeExecutable();
        if (chrome == null) {
          markTestSkipped('Chrome/Chromium executable was not found.');
          return;
        }

        final tempDir = await Directory.systemTemp.createTemp(
          'cockpit_devtools_hostile_content_test',
        );
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        await _writeHostileHistoryFixture(tempDir);

        final server = CockpitDevtoolsServer(
          historyRoot: tempDir.path,
          token: 'secret',
        );
        final handle = await server.start();
        addTearDown(handle.close);

        final browser = await _ChromeCdpBrowser.start(chrome);
        addTearDown(browser.close);
        final tab = await browser.openTab(
          handle.uri.replace(
            queryParameters: <String, String>{
              'token': 'secret',
              'scope': 'hostile-flow',
            },
          ),
        );
        await tab.setViewport(width: 1240, height: 820);

        await tab.waitForExpression(
          "document.querySelector('[data-testid=\"run-list\"]').textContent.includes('<img src=x onerror=') && "
          "document.querySelector('[data-testid=\"timeline-list\"]').textContent.includes('<script>window.__cockpitXss') && "
          "Array.from(document.querySelectorAll('.artifact-media img')).some((img) => img.complete && img.naturalWidth > 0)",
        );
        final rendered = await tab.evaluateMap('''
(() => ({
  runText: document.querySelector('[data-testid="run-list"]').textContent,
  timelineText: document.querySelector('[data-testid="timeline-list"]').textContent,
  galleryText: document.querySelector('[data-testid="artifact-gallery"]').textContent,
  hasInjectedImage: Boolean(document.querySelector('[data-testid="run-list"] img[src="x"]')),
  hasInjectedScript: Boolean(document.querySelector('[data-testid="timeline-list"] script')),
  xssValue: window.__cockpitXss || null,
  artifactHref: document.querySelector('.artifact-open')?.href || '',
  artifactImgSrc: document.querySelector('.artifact-media img')?.currentSrc || '',
  artifactAlt: document.querySelector('.artifact-media img')?.alt || '',
  mediaReadyCount: Array.from(document.querySelectorAll('.artifact-media img')).filter((img) => img.complete && img.naturalWidth > 0).length,
  bodyWidth: document.body.scrollWidth,
  viewportWidth: innerWidth
}))()
''');
        expect(rendered['runText'], contains('<img src=x onerror='));
        expect(
          rendered['timelineText'],
          contains('<script>window.__cockpitXss'),
        );
        expect(rendered['galleryText'], contains('weird name #1.png'));
        expect(rendered['hasInjectedImage'], isFalse);
        expect(rendered['hasInjectedScript'], isFalse);
        expect(rendered['xssValue'], isNull);
        expect(rendered['artifactHref'], contains('weird%20name%20%231.png'));
        expect(rendered['artifactImgSrc'], contains('weird%20name%20%231.png'));
        expect(rendered['artifactAlt'], contains('weird name #1.png'));
        expect(rendered['mediaReadyCount'], greaterThanOrEqualTo(1));
        expect(
          rendered['bodyWidth'],
          lessThanOrEqualTo((rendered['viewportWidth'] as int) + 2),
        );
        tab.expectNoPageErrors();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

Future<Map<String, CockpitLiveRunStore>> _writeBrowserFixture(
  Directory root,
) async {
  final stores = <String, CockpitLiveRunStore>{};
  stores['checkout-run-1'] = await _writeWorkflowRun(
    root: root,
    runId: 'checkout-run-1',
    displayName: 'Checkout first attempt',
    sessionId: 'checkout-flow',
    taskId: 'checkout-proof',
    scopeLabel: 'Checkout proof',
    platform: 'android',
    startedAt: DateTime.utc(2026, 6, 19, 11),
    status: 'failed',
    eventCount: 4,
    artifactEvery: 0,
    finalBundle: true,
    includeFailure: true,
  );
  stores['checkout-run-2'] = await _writeWorkflowRun(
    root: root,
    runId: 'checkout-run-2',
    displayName: 'Checkout retry',
    sessionId: 'checkout-flow',
    taskId: 'checkout-proof',
    scopeLabel: 'Checkout proof',
    platform: 'android',
    startedAt: DateTime.utc(2026, 6, 19, 11, 1),
    status: 'completed',
    eventCount: 7,
    artifactEvery: 3,
    finalBundle: true,
  );
  stores['settings-run'] = await _writeWorkflowRun(
    root: root,
    runId: 'settings-run',
    displayName: 'Settings proof',
    sessionId: 'settings-flow',
    taskId: 'settings-proof',
    scopeLabel: 'Settings flow',
    platform: 'macos',
    startedAt: DateTime.utc(2026, 6, 19, 12),
    status: 'running',
    eventCount: 170,
    artifactEvery: 40,
    finalBundle: true,
    includeVideo: true,
  );
  return stores;
}

Future<void> _writePagedHistoryFixture(
  Directory root, {
  required int count,
}) async {
  for (var index = 1; index <= count; index += 1) {
    final padded = index.toString().padLeft(3, '0');
    await _writeWorkflowRun(
      root: root,
      runId: 'bulk-run-$padded',
      displayName: 'Bulk proof $index',
      sessionId: 'bulk-flow',
      taskId: 'bulk-proof',
      scopeLabel: 'Bulk flow',
      platform: index.isEven ? 'android' : 'macos',
      startedAt: DateTime.utc(2026, 6, 19, 10).add(Duration(minutes: index)),
      status: 'completed',
      eventCount: 1,
      artifactEvery: 0,
      finalBundle: false,
    );
  }
}

Map<String, Object?> _sessionHandleJson() {
  return <String, Object?>{
    'platform': 'android',
    'deviceId': 'emulator-5554',
    'projectDir': '/workspace/app',
    'target': 'lib/main.dart',
    'appId': 'dev.cockpit.demo',
    'host': '127.0.0.1',
    'hostPort': 12345,
    'devicePort': 12345,
    'baseUrl': 'http://127.0.0.1:12345',
    'launchedAt': DateTime.utc(2026, 6, 19).toIso8601String(),
  };
}

Future<void> _writeHostileHistoryFixture(Directory root) async {
  final runId = 'hostile-run';
  final store = CockpitLiveRunStore(
    historyRoot: root.path,
    runId: runId,
    displayName: '<img src=x onerror=window.__cockpitXss=1>',
    runDirectoryName: runId,
    clock: _TickingClock(DateTime.utc(2026, 6, 19, 9), () => 0),
  );
  await store.initialize(
    scopeId: 'hostile-flow',
    scopeKind: 'session',
    scopeLabel: 'Hostile flow',
    sessionId: 'hostile-flow',
    taskId: 'hostile-task',
    platform: 'web',
  );
  final bundleDir = Directory(p.join(store.runDirectory.path, 'bundle'))
    ..createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'screenshots')).createSync(recursive: true);
  const screenshotPath = 'screenshots/weird name #1.png';
  _writePng(p.join(bundleDir.path, screenshotPath), labelHash: runId.hashCode);
  File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'sessionId': 'hostile-flow',
      'taskId': 'hostile-task',
      'platform': 'web',
      'status': 'failed',
      'screenshotCount': 1,
      'artifactRefs': <Object?>[
        <String, Object?>{
          'role': '<b>primary screenshot</b>',
          'relativePath': screenshotPath,
        },
      ],
    }),
  );
  File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'summary': '<script>window.__cockpitXss=2</script>',
      'primaryScreenshotRef': screenshotPath,
    }),
  );
  File(
    p.join(bundleDir.path, 'trace.json'),
  ).writeAsStringSync(jsonEncode(<String, Object?>{'entries': <Object?>[]}));
  await store.updateState(
    (state) => state.copyWith(
      bundleDir: bundleDir.path,
      status: 'failed',
      recommendedNextStep: '<svg onload=window.__cockpitXss=3>',
    ),
  );
  await store.appendEvent(
    type: 'workflow_step_completed',
    status: 'failed',
    stage: 'control',
    workflowStepId: '<script>window.__cockpitXss=4</script>',
    workflowStepType: 'command',
    description: '<script>window.__cockpitXss=5</script>',
    commandId: 'hostile-command',
    commandType: 'tap',
    bundleDir: bundleDir.path,
    artifactRefs: const <Map<String, Object?>>[
      <String, Object?>{
        'role': '<b>event screenshot</b>',
        'relativePath': screenshotPath,
      },
    ],
    error: const <String, Object?>{
      'message': '<img src=x onerror=window.__cockpitXss=6>',
      'code': 'hostileError',
    },
  );
  await store.appendEvent(
    type: 'run_finished',
    status: 'failed',
    bundleDir: bundleDir.path,
    description: '<script>window.__cockpitXss=7</script>',
  );
}

Future<CockpitLiveRunStore> _writeWorkflowRun({
  required Directory root,
  required String runId,
  required String displayName,
  required String sessionId,
  required String taskId,
  required String scopeLabel,
  required String platform,
  required DateTime startedAt,
  required String status,
  required int eventCount,
  required int artifactEvery,
  required bool finalBundle,
  bool includeFailure = false,
  bool includeVideo = false,
  bool includeMissingMedia = false,
}) async {
  var ticks = 0;
  final store = CockpitLiveRunStore(
    historyRoot: root.path,
    runId: runId,
    displayName: displayName,
    runDirectoryName: runId,
    clock: _TickingClock(startedAt, () => ticks++),
  );
  await store.initialize(
    scopeId: sessionId,
    scopeKind: 'session',
    scopeLabel: scopeLabel,
    sessionId: sessionId,
    taskId: taskId,
    platform: platform,
  );
  final bundleDir = Directory(p.join(store.runDirectory.path, 'bundle'))
    ..createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'screenshots')).createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'keyframes')).createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'recordings')).createSync(recursive: true);
  Directory(p.join(bundleDir.path, 'diagnostics')).createSync(recursive: true);
  _writePng(
    p.join(bundleDir.path, 'screenshots', '$runId-final.png'),
    labelHash: runId.hashCode,
  );
  _writePng(
    p.join(bundleDir.path, 'keyframes', '$runId-keyframe.png'),
    labelHash: runId.hashCode ^ 0x33,
  );
  if (includeVideo) {
    File(
      p.join(bundleDir.path, 'recordings', '$runId-final.webm'),
    ).writeAsBytesSync(base64Decode(_tinyWebmBase64));
  }
  File(
    p.join(bundleDir.path, 'diagnostics', '$runId-trace.json'),
  ).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'runId': runId,
      'note': 'diagnostic payload for browser rendering',
    }),
  );
  File(p.join(bundleDir.path, 'manifest.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'sessionId': sessionId,
      'taskId': taskId,
      'platform': platform,
      'status': status == 'running' ? 'completed' : status,
      'screenshotCount': 1,
      'recordingCount': includeVideo ? 1 : 0,
      'deliveryVideoReady': includeVideo,
      'artifactRefs': <Object?>[
        <String, Object?>{
          'role': 'screenshot',
          'relativePath': 'screenshots/$runId-final.png',
        },
        if (includeVideo)
          <String, Object?>{
            'role': 'recording',
            'relativePath': 'recordings/$runId-final.webm',
          },
        if (includeMissingMedia) ...<Object?>[
          <String, Object?>{
            'role': 'screenshot',
            'relativePath': 'screenshots/$runId-missing.png',
          },
          <String, Object?>{
            'role': 'recording',
            'relativePath': 'recordings/$runId-missing.webm',
          },
        ],
      ],
    }),
  );
  File(p.join(bundleDir.path, 'delivery.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'summary': '$displayName browser dashboard delivery',
      'primaryScreenshotRef': 'screenshots/$runId-final.png',
      if (includeVideo) ...<String, Object?>{
        'primaryRecordingRef': 'recordings/$runId-final.webm',
        'deliveryVideoSynthesized': false,
        'deliveryVideoSource': 'nativeRecording',
        'deliveryVideoDurationMs': 600,
      },
      if (includeMissingMedia) ...<String, Object?>{
        'attachmentRefs': <Object?>['screenshots/$runId-missing.png'],
        'videoAttachmentRefs': <Object?>['recordings/$runId-missing.webm'],
      },
      'keyframes': <Object?>[
        <String, Object?>{
          'ref': 'keyframes/$runId-keyframe.png',
          'label': 'final visual',
          'offsetMs': 600,
        },
      ],
    }),
  );
  File(p.join(bundleDir.path, 'trace.json')).writeAsStringSync(
    jsonEncode(<String, Object?>{
      'entries': List<Object?>.generate(
        8,
        (index) => <String, Object?>{
          'stepIndex': index,
          'workflowStepId': index == 6 ? 'change-settings' : 'step-$index',
          'actionType': 'command',
          'status': includeFailure && index == 6 ? 'failed' : 'completed',
          if (index == 7)
            'artifactRefs': <Object?>[
              <String, Object?>{
                'role': 'diagnostics',
                'relativePath': 'diagnostics/$runId-trace.json',
              },
            ],
        },
      ),
    }),
  );

  await store.updateState(
    (state) => state.copyWith(
      bundleDir: bundleDir.path,
      recommendedNextStep: 'inspect evidence in the dashboard timeline',
    ),
  );
  for (var index = 1; index <= eventCount; index += 1) {
    final hasArtifact =
        artifactEvery > 0 && index % artifactEvery == 0 ||
        includeVideo && index == eventCount;
    final isLast = index == eventCount;
    final isFailed = includeFailure && isLast;
    final hasFailureDiagnostics = isFailed;
    await store.appendEvent(
      type: isLast ? 'workflow_step_completed' : 'workflow_step_started',
      status: isFailed
          ? 'failed'
          : status == 'running'
          ? 'running'
          : 'completed',
      stage: 'control',
      workflowStepId: index == eventCount - 1
          ? 'change-settings'
          : 'step-$index',
      workflowStepType: 'command',
      description: index == eventCount - 1
          ? 'Change settings after reading the latest UI state.'
          : 'Execute workflow step $index for $displayName.',
      commandId: 'command-$index',
      commandType: index.isEven ? 'tap' : 'assertText',
      bundleDir: finalBundle && isLast ? bundleDir.path : null,
      artifactRefs: hasArtifact || hasFailureDiagnostics
          ? <Map<String, Object?>>[
              if (hasArtifact)
                <String, Object?>{
                  'role': 'screenshot',
                  'relativePath': 'screenshots/$runId-final.png',
                },
              if (includeVideo && isLast)
                <String, Object?>{
                  'role': 'recording',
                  'relativePath': 'recordings/$runId-final.webm',
                },
              if (hasFailureDiagnostics)
                <String, Object?>{
                  'role': 'diagnostics',
                  'relativePath': 'diagnostics/$runId-trace.json',
                },
            ]
          : const <Map<String, Object?>>[],
      error: isFailed
          ? const <String, Object?>{
              'message': 'Checkout confirmation text did not appear.',
              'code': 'assertTextFailed',
            }
          : null,
      recommendedNextStep: isFailed ? 'inspect failure artifacts' : null,
      details: <String, Object?>{
        'rootWorkflowStepId': 'root',
        if (index == eventCount - 1) ...<String, Object?>{
          'parentWorkflowStepId': 'settings-loop',
          'relation': 'loop',
          'iteration': 2,
          'maxIterations': 3,
        },
        if (index == eventCount - 2) ...<String, Object?>{
          'parentWorkflowStepId': 'retry-readiness',
          'relation': 'retry',
          'attempt': 2,
          'maxAttempts': 3,
        },
      },
    );
  }
  if (status != 'running') {
    await store.appendEvent(
      type: 'run_finished',
      status: status,
      bundleDir: bundleDir.path,
      description: '$displayName finished with $status.',
    );
  }
  return store;
}

void _writePng(String path, {required int labelHash}) {
  final image = img.Image(width: 160, height: 96);
  final bg = img.ColorRgb8(10, 17, 16);
  final accent = img.ColorRgb8(114, 228, 181);
  final warn = img.ColorRgb8(224, 192, 103);
  img.fill(image, color: bg);
  img.fillRect(
    image,
    x1: 12,
    y1: 12,
    x2: 148,
    y2: 84,
    color: labelHash.isEven ? accent : warn,
  );
  img.fillRect(
    image,
    x1: 24,
    y1: 24,
    x2: 136,
    y2: 72,
    color: img.ColorRgb8(22, 33, 30),
  );
  File(path).writeAsBytesSync(img.encodePng(image));
}

String? _findChromeExecutable() {
  final env = Platform.environment['CHROME_EXECUTABLE'];
  if (env != null && env.trim().isNotEmpty && File(env).existsSync()) {
    return env.trim();
  }
  final candidates = <String>[
    if (Platform.isMacOS)
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    if (Platform.isMacOS) '/Applications/Chromium.app/Contents/MacOS/Chromium',
    if (Platform.isLinux) '/usr/bin/google-chrome',
    if (Platform.isLinux) '/usr/bin/google-chrome-stable',
    if (Platform.isLinux) '/usr/bin/chromium',
    if (Platform.isLinux) '/usr/bin/chromium-browser',
    if (Platform.isWindows)
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    if (Platform.isWindows)
      r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    if (Platform.isWindows)
      r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    if (Platform.isWindows)
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  for (final command in <String>[
    if (!Platform.isWindows) 'google-chrome',
    if (!Platform.isWindows) 'google-chrome-stable',
    if (!Platform.isWindows) 'chromium',
    if (!Platform.isWindows) 'chromium-browser',
  ]) {
    final result = Process.runSync('which', <String>[command]);
    if (result.exitCode == 0) {
      final path = (result.stdout as String).trim();
      if (path.isNotEmpty) {
        return path;
      }
    }
  }
  return null;
}

final class _ChromeCdpBrowser {
  _ChromeCdpBrowser._({
    required this.process,
    required this.port,
    required this.userDataDir,
  });

  final Process process;
  final int port;
  final Directory userDataDir;

  static Future<_ChromeCdpBrowser> start(String executable) async {
    final userDataDir = await Directory.systemTemp.createTemp(
      'cockpit_chrome_profile',
    );
    final port = await _freePort();
    final process = await Process.start(executable, <String>[
      '--headless=new',
      '--disable-gpu',
      '--disable-dev-shm-usage',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-background-networking',
      '--disable-extensions',
      '--autoplay-policy=no-user-gesture-required',
      '--remote-debugging-address=127.0.0.1',
      '--remote-debugging-port=$port',
      '--user-data-dir=${userDataDir.path}',
      'about:blank',
    ]);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final browser = _ChromeCdpBrowser._(
      process: process,
      port: port,
      userDataDir: userDataDir,
    );
    await browser._waitUntilReady();
    return browser;
  }

  Future<_ChromeCdpTab> openTab(Uri uri) async {
    final response = await _httpGetJson(
      Uri.parse(
        'http://127.0.0.1:$port/json/new?${Uri.encodeQueryComponent(uri.toString())}',
      ),
      method: 'PUT',
    );
    final wsUrl = response['webSocketDebuggerUrl'] as String?;
    if (wsUrl == null || wsUrl.isEmpty) {
      throw StateError('Chrome did not return a tab WebSocket URL.');
    }
    final socket = await WebSocket.connect(wsUrl);
    final tab = _ChromeCdpTab(socket);
    await tab.enable();
    await tab.waitForExpression('document.readyState === "complete"');
    return tab;
  }

  Future<void> close() async {
    process.kill();
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );
    if (userDataDir.existsSync()) {
      await userDataDir.delete(recursive: true);
    }
  }

  Future<void> _waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        await _httpGetJson(Uri.parse('http://127.0.0.1:$port/json/version'));
        return;
      } catch (error) {
        lastError = error;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    throw StateError(
      'Chrome remote debugging did not become ready: $lastError',
    );
  }
}

final class _ChromeCdpTab {
  _ChromeCdpTab(this._socket) {
    _socket.listen(_handleMessage, onDone: _handleDone, onError: _handleError);
  }

  final WebSocket _socket;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final _pageErrors = <String>[];
  var _nextId = 0;
  Object? _terminalError;

  Future<void> enable() async {
    await send('Runtime.enable');
    await send('Page.enable');
  }

  Future<Map<String, Object?>> send(
    String method, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    final id = ++_nextId;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _socket.add(
      jsonEncode(<String, Object?>{
        'id': id,
        'method': method,
        if (params.isNotEmpty) 'params': params,
      }),
    );
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Chrome CDP command timed out: $method');
      },
    );
  }

  Future<Object?> evaluate(String expression) async {
    final response = await send('Runtime.evaluate', <String, Object?>{
      'expression': expression,
      'awaitPromise': true,
      'returnByValue': true,
      'userGesture': true,
    });
    final result = response['result'] as Map<String, Object?>;
    if (result['exceptionDetails'] != null) {
      throw StateError(
        'JavaScript evaluation failed: ${result['exceptionDetails']}',
      );
    }
    final remoteObject = result['result'] as Map<String, Object?>;
    return remoteObject['value'];
  }

  Future<Object?> evaluateJson(String expression) => evaluate(expression);

  Future<Map<String, Object?>> evaluateMap(String expression) async {
    final value = await evaluate(expression);
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry<String, Object?>(key.toString(), value),
      );
    }
    throw StateError('Expected JavaScript object, got ${value.runtimeType}.');
  }

  Future<List<Object?>> evaluateList(String expression) async {
    final value = await evaluate(expression);
    if (value is List) {
      return value.cast<Object?>();
    }
    throw StateError('Expected JavaScript array, got ${value.runtimeType}.');
  }

  Future<void> waitForExpression(
    String expression, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastResult;
    while (DateTime.now().isBefore(deadline)) {
      if (_terminalError != null) {
        throw StateError(
          'Chrome tab closed before condition matched: $_terminalError',
        );
      }
      lastResult = await evaluate('Boolean($expression)');
      if (lastResult == true) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    throw TimeoutException(
      'Timed out waiting for browser condition: $expression, last=$lastResult',
    );
  }

  Future<void> click(String expression) async {
    await evaluate('''
(() => {
  const node = $expression;
  if (!node) throw new Error('click target not found');
  node.click();
})()
''');
  }

  Future<void> select(String expression, String value) async {
    await evaluate('''
(() => {
  const node = $expression;
  if (!node) throw new Error('select target not found');
  node.value = ${jsonEncode(value)};
  node.dispatchEvent(new Event('change', {bubbles: true}));
})()
''');
  }

  Future<void> reload() async {
    await send('Page.reload', const <String, Object?>{'ignoreCache': true});
    await waitForExpression('document.readyState === "complete"');
  }

  Future<void> setViewport({required int width, required int height}) async {
    await send('Emulation.setDeviceMetricsOverride', <String, Object?>{
      'width': width,
      'height': height,
      'deviceScaleFactor': 1,
      'mobile': width < 760,
    });
  }

  Future<Uint8List> captureScreenshotPng() async {
    final response = await send(
      'Page.captureScreenshot',
      const <String, Object?>{'format': 'png', 'fromSurface': true},
    );
    final result = response['result'] as Map<String, Object?>;
    final data = result['data'] as String?;
    if (data == null || data.isEmpty) {
      throw StateError('Chrome did not return screenshot data.');
    }
    return base64Decode(data);
  }

  void expectNoPageErrors() {
    expect(_pageErrors, isEmpty, reason: _pageErrors.join('\n'));
  }

  void _handleMessage(Object? message) {
    if (message is! String) {
      return;
    }
    final decoded = jsonDecode(message);
    if (decoded is! Map) {
      return;
    }
    _capturePageError(decoded);
    final id = decoded['id'];
    if (id is! int) {
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    final payload = decoded.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    );
    if (payload['error'] != null) {
      completer.completeError(
        StateError('Chrome CDP error: ${payload['error']}'),
      );
      return;
    }
    completer.complete(payload);
  }

  void _capturePageError(Map<Object?, Object?> decoded) {
    final method = decoded['method'];
    final params = decoded['params'];
    if (method == 'Runtime.exceptionThrown' && params is Map) {
      final details = params['exceptionDetails'];
      _pageErrors.add('exception: ${jsonEncode(details)}');
      return;
    }
    if (method == 'Runtime.consoleAPICalled' && params is Map) {
      final type = params['type'];
      if (type != 'error' && type != 'assert') {
        return;
      }
      final args = params['args'];
      if (args is List) {
        final message = args
            .whereType<Map<Object?, Object?>>()
            .map((arg) => arg['value'] ?? arg['description'] ?? arg['type'])
            .join(' ');
        _pageErrors.add('console.$type: $message');
      } else {
        _pageErrors.add('console.$type: ${jsonEncode(params)}');
      }
    }
  }

  void _handleDone() {
    _terminalError = StateError('closed');
    for (final completer in _pending.values) {
      completer.completeError(_terminalError!);
    }
    _pending.clear();
  }

  void _handleError(Object error) {
    _terminalError = error;
    for (final completer in _pending.values) {
      completer.completeError(error);
    }
    _pending.clear();
  }
}

Future<Map<String, Object?>> _httpGetJson(
  Uri uri, {
  String method = 'GET',
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw FormatException('Expected JSON object from $uri.');
    }
    return decoded.map(
      (key, value) => MapEntry<String, Object?>(key.toString(), value),
    );
  } finally {
    client.close(force: true);
  }
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

final class _TickingClock implements CockpitClock {
  const _TickingClock(this.start, this.nextTick);

  final DateTime start;
  final int Function() nextTick;

  @override
  DateTime now() => start.add(Duration(seconds: nextTick()));
}

const String _tinyWebmBase64 =
    'GkXfo59ChoEBQveBAULygQRC84EIQoKEd2VibUKHgQJChYECGFOAZwEAAAAAAAOJEU2bdLpNu4tTq4QVSalmU6yBoU27i1OrhBZUrmtTrIHWTbuMU6uEElTDZ1OsggEjTbuMU6uEHFO7a1OsggNz7AEAAAAAAABZAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAVSalmsCrXsYMPQkBNgIxMYXZmNjIuMy4xMDBXQYxMYXZmNjIuMy4xMDBEiYhAgsAAAAAAABZUrmvIrgEAAAAAAAA/14EBc8WIgtDQT0cY1qycgQAitZyDdW5kiIEAhoVWX1ZQOIOBASPjg4QCYloA4JCwgWC6gUCagQJVsIRVuYEBElTDZ/tzc59jwIBnyJlFo4dFTkNPREVSRIeMTGF2ZjYyLjMuMTAwc3PWY8CLY8WIgtDQT0cY1qxnyKFFo4dFTkNPREVSRIeUTGF2YzYyLjExLjEwMCBsaWJ2cHhnyKFFo4hEVVJBVElPTkSHkzAwOjAwOjAwLjYwMDAwMDAwMAAfQ7Z1QcrngQCj4YEAAIBwBgCdASpgAEAAAEcIhYWIhYSIAgIC3AXF+A/jcBizrgCy+fAT16EH7GGByiXudUN8lNSqP4cCeowTDE5A/v/+XhcP//dWJcxhwd/3+/7/f+mLCVjj8GplTQrgSuCjloEAKADRAQAFEKwAGAAYWC/0AAiFKACjl4EAUADxAQAFEKwAGAAYWC736AiExEAAo5aBAHgA0QEABRCsABgAGFgv9AAIhSgAo5aBAKAA0QEABRCsABgAGFgv9AAIhSgAo5aBAMgA0QEABRCsABgAGFgv9AAIhSgAo5aBAPAA0QEABRCsABgAGFgv9AAIhSgAo6iBARgAkQIABRAQFGAVH6lQV5/4AhM/JL5gMAAGEAtivCxtRfyyOIAAo5eBAUAA8QEABRCsABgAGFgu4BgIhMSAAKOWgQFoANEBAAUQrAAYABhYL/QACIUoAKOWgQGQANEBAAUQrAAYABhYL/QACIUoAKOWgQG4ANEBAAUQrAAYABhYL/QACIUoAKOWgQHgANEBAAUQrAAYABhYL/QACIUoAKOWgQIIANEBAAUQrAAYABhYL/QACIUoAKOWgQIwANEBAAUQrAAYABhYL/QACIUoABxTu2uRu4+zgQC3iveBAfGCAaPwgQM=';
