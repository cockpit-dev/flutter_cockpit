import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Windows native recorder bounds slow Media Foundation startup', () {
    final source = _windowsPluginSource().readAsStringSync();

    expect(
      source,
      contains(
        'constexpr auto kRecordingStartupTimeout = '
        'std::chrono::seconds(20);',
      ),
    );
    expect(
      source,
      contains('Native Windows recorder startup timed out after '),
    );
    expect(
      source,
      contains('initializing Media Foundation and the sink writer'),
    );
    expect(
      source,
      contains(
        'constexpr auto kRecordingStartupCancelTimeout = '
        'std::chrono::seconds(2);',
      ),
    );
    expect(source, contains('std::thread('));
    expect(source, contains('DetachRecordingThread();'));
    expect(source, isNot(contains('std::async')));
  });

  test(
    'Windows native recorder keeps conversion, path, and lifecycle contracts',
    () {
      final source = _windowsPluginSource().readAsStringSync();
      final header = File(
        'packages/flutter_cockpit/windows/flutter_cockpit_plugin.h',
      ).readAsStringSync();
      final combined = '$source\n$header';

      expect(combined, contains('MB_ERR_INVALID_CHARS'));
      expect(combined, contains('WC_ERR_INVALID_CHARS'));
      expect(combined, contains('const int source_length'));
      expect(combined, contains('recordingInvalidPath'));
      expect(combined, contains('weakly_canonical'));
      expect(combined, contains('enum class RecordingState'));
      expect(combined, contains('Starting'));
      expect(combined, contains('Recording'));
      expect(combined, contains('Stopping'));
      expect(combined, contains('session_token_'));
    },
  );
}

File _windowsPluginSource() {
  final candidates = <File>[
    File('windows/flutter_cockpit_plugin.cpp'),
    File('packages/flutter_cockpit/windows/flutter_cockpit_plugin.cpp'),
  ];
  for (final candidate in candidates) {
    if (candidate.existsSync()) {
      return candidate;
    }
  }
  fail(
    'Unable to locate windows/flutter_cockpit_plugin.cpp from '
    '${Directory.current.path}',
  );
}
