import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;
  final aiProtocolFile = File(
    '$root/docs/contracts/ai-development-protocol.md',
  );
  final protocolFile = File(
    '$root/docs/contracts/control-workflow-protocol.md',
  );
  final schemaFile = File('$root/docs/contracts/control-workflow.schema.json');

  test('AI development protocol links the executable workflow contracts', () {
    expect(aiProtocolFile.existsSync(), isTrue);

    final protocol = aiProtocolFile.readAsStringSync();

    expect(protocol, contains('cockpit://workspace/ai-development-protocol'));
    expect(protocol, contains('control-workflow-protocol.md'));
    expect(protocol, contains('task-run-bundle.md'));
    expect(protocol, contains('run-task --config'));
    expect(protocol, contains('validate-task --config'));
    expect(protocol, contains('trace.json'));
    expect(protocol, contains('validation.json'));
  });

  test('control workflow protocol has a linked machine-readable schema', () {
    expect(protocolFile.existsSync(), isTrue);
    expect(schemaFile.existsSync(), isTrue);

    final protocol = protocolFile.readAsStringSync();
    final schema =
        jsonDecode(schemaFile.readAsStringSync()) as Map<String, Object?>;

    expect(protocol, contains('schemaVersion: 1'));
    expect(protocol, contains('control-workflow.schema.json'));
    expect(protocol, contains('cockpit://workspace/control-workflow-schema'));
    expect(protocol, contains('run-task --config'));
    expect(protocol, contains('validate-task --config'));
    expect(schema[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
    expect(schema['title'], 'Flutter Cockpit Control Workflow Script');
    expect(
      schema['required'],
      containsAll(<String>['sessionId', 'taskId', 'platform']),
    );
  });
}
