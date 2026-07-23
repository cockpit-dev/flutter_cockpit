import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('published YAML and JSON V2 examples compile equivalently', () {
    const compiler = CockpitTestDocumentCompiler();
    final yaml = compiler.compile(
      _example('flutter_login.yaml').readAsStringSync(),
    );
    final json = compiler.compile(
      _example('flutter_login.json').readAsStringSync(),
    );

    expect(yaml.isSuccess, isTrue, reason: _diagnostics(yaml));
    expect(json.isSuccess, isTrue, reason: _diagnostics(json));
    expect(
      yaml.requireCase().testCase.toJson(),
      json.requireCase().testCase.toJson(),
    );
  });
}

File _example(String name) {
  final packageLocal = File('example/cases/$name');
  return packageLocal.existsSync()
      ? packageLocal
      : File('packages/cockpit/example/cases/$name');
}

String _diagnostics(CockpitTestCompilationResult result) => result.diagnostics
    .map((diagnostic) => '${diagnostic.code}: ${diagnostic.message}')
    .join('\n');
