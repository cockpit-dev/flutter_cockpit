import 'package:cockpit/src/cli/cockpit_cli_config_file.dart';
import 'package:test/test.dart';

void main() {
  test('decodes JSON config objects', () {
    final config = cockpitConfigMapFromText(
      '{"runTask":{"outputRoot":"/tmp/out"}}',
      label: 'Config',
    );

    expect(config, <String, Object?>{
      'runTask': <String, Object?>{'outputRoot': '/tmp/out'},
    });
  });

  test('decodes YAML config objects and nested lists', () {
    final config = cockpitConfigMapFromText('''
runTask:
  script:
    steps:
      - stepType: command
        command:
          commandId: assert-ready
          commandType: assertText
''', label: 'Config');

    final runTask = config['runTask'] as Map<String, Object?>;
    final script = runTask['script'] as Map<String, Object?>;
    final steps = script['steps'] as List<Object?>;
    expect((steps.single as Map<String, Object?>)['stepType'], 'command');
  });

  test('rejects non-object config payloads', () {
    expect(
      () => cockpitConfigMapFromText('[]', label: 'Config'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Config must decode to an object.',
        ),
      ),
    );
  });

  test('rejects non-string object keys', () {
    expect(
      () => cockpitConfigMapFromText('1: value', label: 'Config'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'Object keys at Config must be non-empty strings.',
        ),
      ),
    );
  });
}
