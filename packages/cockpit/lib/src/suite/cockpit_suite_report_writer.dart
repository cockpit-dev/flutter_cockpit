import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:path/path.dart' as p;

import 'cockpit_suite_report_renderer.dart';

final class CockpitSuiteReportFiles {
  CockpitSuiteReportFiles(Map<CockpitTestReportFormat, String> paths)
    : paths = Map<CockpitTestReportFormat, String>.unmodifiable(paths);

  final Map<CockpitTestReportFormat, String> paths;
}

final class CockpitSuiteReportWriter {
  const CockpitSuiteReportWriter({
    CockpitSuiteReportRenderer renderer = const CockpitSuiteReportRenderer(),
  }) : _renderer = renderer;

  final CockpitSuiteReportRenderer _renderer;

  Future<CockpitSuiteReportFiles> write({
    required CockpitTestSuiteReport report,
    required String runRoot,
  }) async {
    final normalizedRoot = p.normalize(runRoot);
    if (!p.isAbsolute(runRoot) || normalizedRoot != runRoot) {
      throw const FormatException(
        'Suite report root must be absolute and normalized.',
      );
    }
    final directory = Directory(runRoot);
    final type = await FileSystemEntity.type(runRoot, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Suite report root is not a directory.',
        runRoot,
      );
    }
    await directory.create(recursive: true);
    final outputs = <CockpitTestReportFormat, String>{};
    for (final format in report.reportPolicy.formats) {
      final name = switch (format) {
        CockpitTestReportFormat.json => 'report.json',
        CockpitTestReportFormat.junit => 'junit.xml',
        CockpitTestReportFormat.html => 'report.html',
        CockpitTestReportFormat.aiSummary => 'ai-summary.md',
      };
      final content = switch (format) {
        CockpitTestReportFormat.json => '${_renderer.json(report)}\n',
        CockpitTestReportFormat.junit => _renderer.junit(report),
        CockpitTestReportFormat.html => _renderer.html(report),
        CockpitTestReportFormat.aiSummary => _renderer.aiSummary(report),
      };
      final target = p.join(runRoot, name);
      await _writeImmutable(target, content);
      outputs[format] = target;
    }
    return CockpitSuiteReportFiles(outputs);
  }

  Future<void> _writeImmutable(String path, String content) async {
    final target = File(path);
    if (await target.exists()) {
      if (await target.readAsString() != content) {
        throw FileSystemException('Finalized suite report is immutable.', path);
      }
      return;
    }
    final temporary = File(
      '$path.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    final sink = temporary.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(content);
      await sink.flush();
      await sink.close();
      await temporary.rename(path);
    } on Object {
      await sink.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
