import 'cockpit_test_case.dart';
import 'cockpit_test_value_reader.dart';

sealed class CockpitTestSuiteCaseSource {
  const CockpitTestSuiteCaseSource();

  String get kind;

  String get caseId;

  Map<String, Object?> toJson();

  static CockpitTestSuiteCaseSource fromJson(
    Object? value, {
    required String path,
  }) {
    final json = CockpitTestValueReader.object(value, path);
    final kind = CockpitTestValueReader.string(json['kind'], '$path.kind');
    return switch (kind) {
      'inline' => CockpitTestSuiteInlineCaseSource.fromJson(value, path: path),
      'file' => CockpitTestSuiteFileCaseSource.fromJson(value, path: path),
      _ => throw FormatException(
        'Unsupported suite case source at $path.kind.',
      ),
    };
  }
}

final class CockpitTestSuiteInlineCaseSource
    extends CockpitTestSuiteCaseSource {
  CockpitTestSuiteInlineCaseSource({required this.testCase});

  final CockpitTestCase testCase;

  @override
  String get kind => 'inline';

  @override
  String get caseId => testCase.id;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'case': testCase.toJson(),
  };

  factory CockpitTestSuiteInlineCaseSource.fromJson(
    Object? value, {
    required String path,
  }) {
    final json = CockpitTestValueReader.object(value, path);
    CockpitTestValueReader.keys(
      json,
      const <String>{'kind', 'case'},
      path,
      required: const <String>{'kind', 'case'},
    );
    if (json['kind'] != 'inline') {
      throw FormatException('Expected inline source at $path.kind.');
    }
    return CockpitTestSuiteInlineCaseSource(
      testCase: CockpitTestCase.fromJson(json['case'], path: '$path.case'),
    );
  }
}

final class CockpitTestSuiteFileCaseSource extends CockpitTestSuiteCaseSource {
  CockpitTestSuiteFileCaseSource({
    required this.relativePath,
    required this.caseId,
  }) {
    _relativePath(relativePath, r'$.relativePath');
    CockpitTestValueReader.string(caseId, r'$.caseId', id: true);
  }

  @override
  String get kind => 'file';

  final String relativePath;
  @override
  final String caseId;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'relativePath': relativePath,
    'caseId': caseId,
  };

  factory CockpitTestSuiteFileCaseSource.fromJson(
    Object? value, {
    required String path,
  }) {
    final json = CockpitTestValueReader.object(value, path);
    CockpitTestValueReader.keys(
      json,
      const <String>{'kind', 'relativePath', 'caseId'},
      path,
      required: const <String>{'kind', 'relativePath', 'caseId'},
    );
    if (json['kind'] != 'file') {
      throw FormatException('Expected file source at $path.kind.');
    }
    return CockpitTestSuiteFileCaseSource(
      relativePath: _relativePath(json['relativePath'], '$path.relativePath'),
      caseId: CockpitTestValueReader.string(
        json['caseId'],
        '$path.caseId',
        id: true,
      ),
    );
  }
}

String _relativePath(Object? value, String path) {
  final source = CockpitTestValueReader.string(value, path, maximum: 4096);
  if (source.startsWith('/') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(source) ||
      source.split(RegExp(r'[\\/]')).any((segment) => segment == '..')) {
    throw FormatException('Expected a confined relative path at $path.');
  }
  return source;
}
