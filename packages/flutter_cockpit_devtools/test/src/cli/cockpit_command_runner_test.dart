import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('runner registers workspace intelligence commands', () {
    final commands = CockpitCommandRunner().commands.keys.toSet();

    expect(
      commands,
      containsAll(<String>[
        'pub-dev-search',
        'pub',
        'read-package-uris',
        'grep-package-uris',
        'lsp',
        'analyze-files',
        'create-project',
        'analyze-workspace',
        'format-workspace',
        'run-tests',
        'apply-fixes',
      ]),
    );
  });

  test('runner registers public remote and development workflow commands', () {
    final commands = CockpitCommandRunner().commands.keys.toSet();

    expect(
      commands,
      containsAll(<String>[
        'launch-remote-session',
        'query-remote-session',
        'read-remote-status',
        'read-remote-snapshot',
        'collect-remote-snapshot',
        'execute-remote-command',
        'execute-remote-command-batch',
        'wait-remote-ui-idle',
        'start-remote-recording',
        'stop-remote-recording',
        'read-task-bundle-summary',
        'launch-development-session',
        'query-development-session',
        'reload-development-session',
        'collect-development-probe',
        'compare-development-probe',
        'stop-development-session',
        'run-remote-control-script',
        'capture-screenshot',
      ]),
    );
  });

  test('usage errors are written to stderr', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(
      stderrSink: stderrBuffer,
    ).run(<String>['launch-app', '--platform', 'android']);

    expect(exitCode, cockpitUsageExitCode);
    expect(
      stderrBuffer.toString(),
      contains('--device-id is required for android.'),
    );
    expect(
      stderrBuffer.toString(),
      contains('Usage: flutter_cockpit_devtools launch-app'),
    );
  });

  test('usage errors include machine-readable errorJson on stderr', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(
      stderrSink: stderrBuffer,
    ).run(<String>['launch-app', '--platform', 'android']);

    expect(exitCode, cockpitUsageExitCode);
    final stderr = stderrBuffer.toString();
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'usage');
    expect(
      payload['message'],
      contains('--device-id is required for android.'),
    );
  });

  test('data errors are written to stderr', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_runner_stderr',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final configFile = File(p.join(tempDir.path, 'invalid.json'));
    await configFile.writeAsString('[]');

    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(
      stderrSink: stderrBuffer,
    ).run(<String>['run-task', '--config-json', configFile.path]);

    expect(exitCode, cockpitDataExitCode);
    expect(
      stderrBuffer.toString(),
      contains('Run task config JSON must decode to an object.'),
    );
  });

  test('format errors include machine-readable errorJson on stderr', () async {
    final stderrBuffer = StringBuffer();
    final runner = CockpitCommandRunner(
      stderrSink: stderrBuffer,
      commands: <Command<int>>[
        _FailingCommand(
          const FormatException('Command JSON must decode to an object.'),
        ),
      ],
    );

    final exitCode = await runner.run(<String>['fail']);

    expect(exitCode, cockpitDataExitCode);
    final stderr = stderrBuffer.toString();
    expect(stderr, contains('Command JSON must decode to an object.'));
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'invalidInput');
    expect(payload['message'], 'Command JSON must decode to an object.');
  });

  test('state errors include machine-readable errorJson on stderr', () async {
    final stderrBuffer = StringBuffer();
    final runner = CockpitCommandRunner(
      stderrSink: stderrBuffer,
      commands: <Command<int>>[
        _FailingCommand(StateError('Recording is not active.')),
      ],
    );

    final exitCode = await runner.run(<String>['fail']);

    expect(exitCode, cockpitDataExitCode);
    final stderr = stderrBuffer.toString();
    expect(stderr, contains('Recording is not active.'));
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'invalidState');
    expect(payload['message'], 'Recording is not active.');
  });

  test(
    'argument errors include machine-readable errorJson on stderr',
    () async {
      final stderrBuffer = StringBuffer();
      final runner = CockpitCommandRunner(
        stderrSink: stderrBuffer,
        commands: <Command<int>>[
          _FailingCommand(ArgumentError('Invalid output path.')),
        ],
      );

      final exitCode = await runner.run(<String>['fail']);

      expect(exitCode, cockpitDataExitCode);
      final stderr = stderrBuffer.toString();
      expect(stderr, contains('Invalid output path.'));
      final jsonLine = stderr
          .split('\n')
          .firstWhere((line) => line.startsWith('errorJson: '));
      final payload = Map<String, Object?>.from(
        jsonDecode(jsonLine.substring('errorJson: '.length))
            as Map<Object?, Object?>,
      );
      expect(payload['code'], 'invalidArgument');
      expect(payload['message'], 'Invalid output path.');
    },
  );

  test(
    'unexpected errors include bounded machine-readable errorJson on stderr',
    () async {
      final stderrBuffer = StringBuffer();
      final runner = CockpitCommandRunner(
        stderrSink: stderrBuffer,
        commands: <Command<int>>[
          _FailingCommand(Exception('Socket closed while reading status.')),
        ],
      );

      final exitCode = await runner.run(<String>['fail']);

      expect(exitCode, cockpitDataExitCode);
      final stderr = stderrBuffer.toString();
      expect(stderr, contains('Socket closed while reading status.'));
      final jsonLine = stderr
          .split('\n')
          .firstWhere((line) => line.startsWith('errorJson: '));
      final payload = Map<String, Object?>.from(
        jsonDecode(jsonLine.substring('errorJson: '.length))
            as Map<Object?, Object?>,
      );
      expect(payload['code'], 'internalError');
      expect(
        payload['message'],
        'Exception: Socket closed while reading status.',
      );
      expect(stderr, isNot(contains('packages/flutter_cockpit_devtools/test')));
    },
  );

  test(
    'service errors include machine-readable code and details on stderr',
    () async {
      final stderrBuffer = StringBuffer();
      final runner = CockpitCommandRunner(
        stderrSink: stderrBuffer,
        commands: <Command<int>>[
          _FailingCommand(
            const CockpitApplicationServiceException(
              code: 'remoteUnavailable',
              message: 'Remote session is temporarily unavailable.',
              details: <String, Object?>{
                'baseUrl': 'http://127.0.0.1:47331',
                'method': 'GET',
                'path': '/health',
              },
            ),
          ),
        ],
      );

      final exitCode = await runner.run(<String>['fail']);

      expect(exitCode, cockpitDataExitCode);
      final stderr = stderrBuffer.toString();
      expect(stderr, contains('Remote session is temporarily unavailable.'));
      final jsonLine = stderr
          .split('\n')
          .firstWhere((line) => line.startsWith('errorJson: '));
      final payload = Map<String, Object?>.from(
        jsonDecode(jsonLine.substring('errorJson: '.length))
            as Map<Object?, Object?>,
      );
      expect(payload['code'], 'remoteUnavailable');
      expect((payload['details'] as Map<Object?, Object?>)['path'], '/health');
    },
  );

  test('usage errorJson is emitted for invalid numeric CLI options', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(stderrSink: stderrBuffer).run(
      <String>[
        'read-logs',
        '--base-url',
        'http://127.0.0.1:47331',
        '--max-lines',
        '0',
      ],
    );

    expect(exitCode, cockpitUsageExitCode);
    final stderr = stderrBuffer.toString();
    expect(stderr, contains('--max-lines must be a positive integer.'));
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'usage');
    expect(payload['message'], contains('--max-lines'));
  });

  test('usage errorJson is emitted for non-integer CLI options', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(stderrSink: stderrBuffer).run(
      <String>[
        'read-logs',
        '--base-url',
        'http://127.0.0.1:47331',
        '--max-lines',
        'many',
      ],
    );

    expect(exitCode, cockpitUsageExitCode);
    final stderr = stderrBuffer.toString();
    expect(stderr, contains('--max-lines must be an integer.'));
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'usage');
    expect(payload['message'], contains('--max-lines'));
  });

  test('workspace numeric CLI options report usage for non-integers', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(stderrSink: stderrBuffer).run(
      <String>[
        'analyze-files',
        '--path',
        'lib/main.dart',
        '--timeout-seconds',
        'fast',
      ],
    );

    expect(exitCode, cockpitUsageExitCode);
    final stderr = stderrBuffer.toString();
    expect(stderr, contains('--timeout-seconds must be an integer.'));
    final jsonLine = stderr
        .split('\n')
        .firstWhere((line) => line.startsWith('errorJson: '));
    final payload = Map<String, Object?>.from(
      jsonDecode(jsonLine.substring('errorJson: '.length))
          as Map<Object?, Object?>,
    );
    expect(payload['code'], 'usage');
    expect(payload['message'], contains('--timeout-seconds'));
  });
}

final class _FailingCommand extends Command<int> {
  _FailingCommand(this.error);

  final Object error;

  @override
  String get name => 'fail';

  @override
  String get description => 'Fail for runner tests.';

  @override
  Future<int> run() async {
    throw error;
  }
}
