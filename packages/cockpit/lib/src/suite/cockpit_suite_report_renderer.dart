import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

final class CockpitSuiteReportRenderer {
  const CockpitSuiteReportRenderer();

  String json(CockpitTestSuiteReport report) =>
      const JsonEncoder.withIndent('  ').convert(report.toJson());

  String junit(CockpitTestSuiteReport report) {
    final counts = report.counts;
    final failures = counts.failed + counts.blocked;
    final suiteErrors = report.failure == null ? 0 : 1;
    final errors =
        counts.cancelled +
        counts.interrupted +
        counts.internalError +
        suiteErrors;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..write(
        '<testsuite name="${_xml(report.suiteId)}" '
        'tests="${counts.total + suiteErrors}" failures="$failures" errors="$errors" '
        'skipped="${counts.skipped}" '
        'time="${_seconds(report.durationMs)}">',
      )
      ..writeln()
      ..writeln(
        '  <properties><property name="cockpit.runId" '
        'value="${_xml(report.runId)}"/></properties>',
      );
    for (final testCase in report.cases) {
      final duration = testCase.attempts.fold<int>(
        0,
        (total, attempt) => total + attempt.durationMs,
      );
      buffer.write(
        '  <testcase classname="${_xml(report.suiteId)}" '
        'name="${_xml(_caseName(testCase))}" '
        'time="${_seconds(duration)}">',
      );
      switch (testCase.outcome) {
        case CockpitRunOutcome.passed:
          break;
        case CockpitRunOutcome.skipped:
          buffer.write('<skipped/>');
        case CockpitRunOutcome.failed || CockpitRunOutcome.blocked:
          buffer.write(
            '<failure type="${testCase.outcome.name}" '
            'message="${_xml(_failureMessage(testCase))}"/>',
          );
        case CockpitRunOutcome.cancelled ||
            CockpitRunOutcome.interrupted ||
            CockpitRunOutcome.internalError:
          buffer.write(
            '<error type="${testCase.outcome.name}" '
            'message="${_xml(_failureMessage(testCase))}"/>',
          );
      }
      buffer.writeln('</testcase>');
    }
    if (report.failure case final failure?) {
      buffer
        ..write(
          '  <testcase classname="${_xml(report.suiteId)}" '
          'name="[suite cleanup]" time="0.000">',
        )
        ..write(
          '<error type="suiteCleanup" '
          'message="${_xml(failure.primary.message)}"/>',
        )
        ..writeln('</testcase>');
    }
    buffer.writeln('</testsuite>');
    return buffer.toString();
  }

  String aiSummary(CockpitTestSuiteReport report) {
    final counts = report.counts;
    final buffer = StringBuffer()
      ..writeln('# Cockpit regression summary')
      ..writeln()
      ..writeln('- Run: `${report.runId}`')
      ..writeln('- Suite: `${report.suiteId}`')
      ..writeln('- Outcome: `${report.outcome.name}`')
      ..writeln('- Stability: `${report.stability.name}`')
      ..writeln('- Duration: `${report.durationMs} ms`')
      ..writeln(
        '- Counts: ${counts.passed} passed, ${counts.failed} failed, '
        '${counts.blocked} blocked, ${counts.skipped} skipped, '
        '${counts.flaky} flaky',
      );
    if (report.failure case final failure?) {
      buffer
        ..writeln()
        ..writeln('## Suite failure')
        ..writeln()
        ..writeln('- `${failure.primary.code}`: ${failure.primary.message}');
    }
    final actionable = report.cases.where(
      (item) =>
          item.outcome != CockpitRunOutcome.passed &&
          item.outcome != CockpitRunOutcome.skipped,
    );
    if (actionable.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Failures');
      for (final item in actionable) {
        buffer.writeln(
          '- `${item.entryId}` on `${item.targetId}`: '
          '`${item.outcome.name}`. ${_failureMessage(item)}',
        );
      }
    }
    return buffer.toString();
  }

  String html(CockpitTestSuiteReport report) => _htmlReport(report);
}

String _caseName(CockpitTestCaseReport report) {
  final matrix = report.matrix.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(', ');
  return <String>[
    report.entryId,
    if (matrix.isNotEmpty) '[$matrix]',
    '@ ${report.targetId}',
  ].join(' ');
}

String _failureMessage(CockpitTestCaseReport report) {
  for (final attempt in report.attempts.reversed) {
    final message = attempt.failure?.primary.message;
    if (message != null) return message;
  }
  return 'The case did not produce a successful attempt.';
}

String _seconds(int milliseconds) => (milliseconds / 1000).toStringAsFixed(3);

String _xml(Object? value) => value
    .toString()
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _htmlReport(CockpitTestSuiteReport report) {
  final counts = report.counts;
  final suiteFailure = report.failure == null
      ? ''
      : '''<section class="suite-failure">
  <h2>Suite cleanup failure</h2>
  <p><code>${_html(report.failure!.primary.code)}</code>: ${_html(report.failure!.primary.message)}</p>
</section>''';
  final rows = StringBuffer();
  for (final testCase in report.cases) {
    final duration = testCase.attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.durationMs,
    );
    final matrix = testCase.matrix.isEmpty
        ? 'None'
        : testCase.matrix.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(', ');
    rows
      ..write('<tr>')
      ..write('<td><strong>${_html(testCase.entryId)}</strong>')
      ..write('<span class="case-id">${_html(testCase.caseId)}</span></td>')
      ..write(
        '<td><span class="status status-${testCase.outcome.name}">'
        '${_html(testCase.outcome.name)}</span>',
      );
    if (testCase.stability == CockpitRunStability.flaky) {
      rows.write('<span class="stability">flaky</span>');
    }
    rows
      ..write('</td>')
      ..write('<td>${_html(testCase.targetId)}</td>')
      ..write('<td>${_html(matrix)}</td>')
      ..write('<td>${testCase.attempts.length}</td>')
      ..write('<td>${_seconds(duration)} s</td>')
      ..write('<td>${_attemptDetails(testCase)}</td>')
      ..writeln('</tr>');
  }
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_html(report.suiteId)} regression report</title>
<style>
:root { color-scheme: light; --bg:#f5f7f8; --surface:#fff; --ink:#172024; --muted:#526068; --line:#d7dde0; --accent:#176b55; --pass:#176b55; --fail:#b42318; --warn:#8a5700; --info:#315e91; }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--ink); font:14px/1.5 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
header { background:var(--surface); border-bottom:1px solid var(--line); }
.shell { width:min(1440px,100%); margin:0 auto; padding:24px; }
h1 { margin:0; font-size:24px; line-height:1.2; letter-spacing:0; text-wrap:balance; }
.meta { margin:8px 0 0; color:var(--muted); overflow-wrap:anywhere; }
.summary { display:flex; flex-wrap:wrap; gap:20px 32px; margin:24px 0 0; padding:16px 0 0; border-top:1px solid var(--line); }
.summary div { min-width:92px; }
.summary dt { color:var(--muted); font-size:12px; }
.summary dd { margin:2px 0 0; font-size:18px; font-weight:650; }
main.shell { padding-top:28px; }
h2 { margin:0 0 12px; font-size:18px; letter-spacing:0; }
.suite-failure { margin:0 0 24px; padding:14px 16px; background:#fff; border-left:4px solid var(--fail); }
.suite-failure p { margin:4px 0 0; color:var(--muted); }
.table-wrap { overflow:auto; background:var(--surface); border:1px solid var(--line); border-radius:8px; }
table { width:100%; border-collapse:collapse; min-width:980px; }
th,td { padding:11px 12px; border-bottom:1px solid var(--line); text-align:left; vertical-align:top; }
th { position:sticky; top:0; background:#edf1f2; color:#344148; font-size:12px; font-weight:650; }
tbody tr:last-child td { border-bottom:0; }
.case-id { display:block; margin-top:2px; color:var(--muted); font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; }
.status,.stability { display:inline-block; padding:2px 7px; border-radius:999px; font-size:12px; font-weight:650; }
.status-passed { background:#e2f3ec; color:#0f5c47; }
.status-failed,.status-internalError { background:#fce8e6; color:var(--fail); }
.status-blocked,.status-interrupted { background:#fff0d5; color:var(--warn); }
.status-cancelled,.status-skipped { background:#e8edf2; color:#3f4d55; }
.stability { margin-left:6px; background:#e6eef8; color:var(--info); }
details { max-width:420px; }
summary { cursor:pointer; color:var(--accent); font-weight:600; }
.attempt { margin:8px 0 0; padding-top:8px; border-top:1px solid var(--line); }
.attempt p { margin:3px 0; color:var(--muted); overflow-wrap:anywhere; }
code { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; }
footer { color:var(--muted); font-size:12px; }
@media (max-width:640px) { .shell { padding:18px 14px; } h1 { font-size:20px; } .summary { gap:14px 24px; } }
@media print { body { background:#fff; } .shell { width:100%; padding:12px 0; } .table-wrap { overflow:visible; border:0; } table { min-width:0; font-size:10px; } th { position:static; } details > * { display:block; } }
</style>
</head>
<body>
<header><div class="shell">
  <h1>${_html(report.suiteId)} regression report</h1>
  <p class="meta">Run <code>${_html(report.runId)}</code> | ${_html(report.startedAt.toIso8601String())}</p>
  <dl class="summary">
    <div><dt>Outcome</dt><dd>${_html(report.outcome.name)}</dd></div>
    <div><dt>Passed</dt><dd>${counts.passed}</dd></div>
    <div><dt>Failed</dt><dd>${counts.failed}</dd></div>
    <div><dt>Blocked</dt><dd>${counts.blocked}</dd></div>
    <div><dt>Skipped</dt><dd>${counts.skipped}</dd></div>
    <div><dt>Flaky</dt><dd>${counts.flaky}</dd></div>
    <div><dt>Duration</dt><dd>${_seconds(report.durationMs)} s</dd></div>
  </dl>
</div></header>
<main class="shell">
  $suiteFailure
  <h2>Case results</h2>
  <div class="table-wrap"><table>
    <thead><tr><th>Case</th><th>Result</th><th>Target</th><th>Matrix</th><th>Attempts</th><th>Duration</th><th>Details</th></tr></thead>
    <tbody>$rows</tbody>
  </table></div>
</main>
<footer class="shell">Cockpit ${_html(report.schemaVersion)} | Source ${_html(report.sourceSha256)}</footer>
</body>
</html>
''';
}

String _attemptDetails(CockpitTestCaseReport report) {
  if (report.attempts.isEmpty) return _html(_failureMessage(report));
  final body = StringBuffer();
  for (final attempt in report.attempts) {
    body
      ..write('<div class="attempt"><strong>Attempt ${attempt.number}: ')
      ..write('${_html(attempt.outcome.name)}</strong>')
      ..write('<p>${_seconds(attempt.durationMs)} s on ')
      ..write('<code>${_html(attempt.targetId)}</code></p>');
    final failure = attempt.failure?.primary;
    if (failure != null) {
      body
        ..write('<p><code>${_html(failure.code)}</code>: ')
        ..write('${_html(failure.message)}</p>');
    }
    body.write('</div>');
  }
  return '<details><summary>View attempts</summary>$body</details>';
}

String _html(Object? value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value.toString());
