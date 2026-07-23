import 'dart:io';

import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('published V2 case and suite examples compile coherently', () {
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
    final home = compiler.compile(
      _example('flutter_home_smoke.yaml').readAsStringSync(),
    );
    final suite = compiler.compile(
      _suiteExample('regression.yaml').readAsStringSync(),
    );
    expect(home.isSuccess, isTrue, reason: _diagnostics(home));
    expect(suite.isSuccess, isTrue, reason: _diagnostics(suite));
    expect(
      suite.requireSuite().suite.cases.map((entry) => entry.source.caseId),
      <String>['flutterLogin', 'flutterHomeSmoke'],
    );
  });
}

File _example(String name) {
  final packageLocal = File('example/cases/$name');
  return packageLocal.existsSync()
      ? packageLocal
      : File('packages/cockpit/example/cases/$name');
}

File _suiteExample(String name) {
  final packageLocal = File('example/suites/$name');
  return packageLocal.existsSync()
      ? packageLocal
      : File('packages/cockpit/example/suites/$name');
}

String _diagnostics(CockpitTestCompilationResult result) => result.diagnostics
    .map((diagnostic) => '${diagnostic.code}: ${diagnostic.message}')
    .join('\n');
