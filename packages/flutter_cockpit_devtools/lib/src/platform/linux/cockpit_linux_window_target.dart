import 'dart:async';

import '../../capture/cockpit_host_capture_adapter.dart';

typedef CockpitLinuxWindowTargetResolver =
    Future<CockpitLinuxWindowTarget> Function({
      required String appId,
      required int? processId,
      required CockpitCaptureProcessRunner processRunner,
      required Duration timeout,
    });

final class CockpitLinuxWindowTarget {
  const CockpitLinuxWindowTarget({
    required this.windowId,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String windowId;
  final int left;
  final int top;
  final int width;
  final int height;
}

Future<CockpitLinuxWindowTarget> cockpitResolveLinuxWindowTarget({
  required String appId,
  required int? processId,
  required CockpitCaptureProcessRunner processRunner,
  required Duration timeout,
}) async {
  final candidatePids = processId == null
      ? await _readCandidatePids(
          appId: appId,
          processRunner: processRunner,
          timeout: timeout,
        )
      : <int>{processId};
  final wmctrlResult = await processRunner('wmctrl', <String>[
    '-lpGx',
  ]).timeout(timeout);
  if (wmctrlResult.exitCode != 0) {
    throw StateError(
      'wmctrl -lpGx failed for $appId: ${wmctrlResult.stderr ?? wmctrlResult.stdout}',
    );
  }

  final normalizedAppId = appId.trim().toLowerCase();
  final candidates = <_CockpitLinuxWindowRow>[];
  for (final rawLine in '${wmctrlResult.stdout}'.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty) {
      continue;
    }
    final parsed = _parseWindowRow(line);
    if (parsed == null || parsed.width <= 0 || parsed.height <= 0) {
      continue;
    }
    final matchesPid =
        candidatePids.isNotEmpty && candidatePids.contains(parsed.pid);
    final matchesMetadata =
        parsed.windowId.toLowerCase().contains(normalizedAppId) ||
        parsed.wmClass.toLowerCase().contains(normalizedAppId) ||
        parsed.title.toLowerCase().contains(normalizedAppId);
    if (matchesPid || (candidatePids.isEmpty && matchesMetadata)) {
      candidates.add(parsed);
    }
  }

  if (candidates.isEmpty) {
    throw StateError('No visible Linux window was found for $appId.');
  }

  final selected = candidates.first;
  return CockpitLinuxWindowTarget(
    windowId: selected.windowId,
    left: selected.left,
    top: selected.top,
    width: selected.width,
    height: selected.height,
  );
}

Future<Set<int>> _readCandidatePids({
  required String appId,
  required CockpitCaptureProcessRunner processRunner,
  required Duration timeout,
}) async {
  try {
    final result = await processRunner('pgrep', <String>[
      '-x',
      appId,
    ]).timeout(timeout);
    if (result.exitCode != 0) {
      return const <int>{};
    }
    return '${result.stdout}'
        .split('\n')
        .map((line) => int.tryParse(line.trim()))
        .whereType<int>()
        .toSet();
  } on Object {
    return const <int>{};
  }
}

_CockpitLinuxWindowRow? _parseWindowRow(String line) {
  final match = _windowRowPattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  final pid = int.tryParse(match.group(2)!);
  final left = int.tryParse(match.group(3)!);
  final top = int.tryParse(match.group(4)!);
  final width = int.tryParse(match.group(5)!);
  final height = int.tryParse(match.group(6)!);
  if (pid == null ||
      left == null ||
      top == null ||
      width == null ||
      height == null) {
    return null;
  }
  return _CockpitLinuxWindowRow(
    windowId: match.group(1)!,
    pid: pid,
    left: left,
    top: top,
    width: width,
    height: height,
    wmClass: match.group(7)!,
    title: (match.group(8) ?? '').trim(),
  );
}

final RegExp _windowRowPattern = RegExp(
  r'^(\S+)\s+\S+\s+(\d+)\s+(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+\S+\s*(.*)$',
);

final class _CockpitLinuxWindowRow {
  const _CockpitLinuxWindowRow({
    required this.windowId,
    required this.pid,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.wmClass,
    required this.title,
  });

  final String windowId;
  final int pid;
  final int left;
  final int top;
  final int width;
  final int height;
  final String wmClass;
  final String title;
}
