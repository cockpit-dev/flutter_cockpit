import '../test/cockpit_test_case.dart';
import '../test/cockpit_test_diagnostic.dart';
import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_value_reader.dart';

enum CockpitDocumentFormat { yaml, json }

final class CockpitDocumentValidationRequest {
  CockpitDocumentValidationRequest({
    required this.format,
    required this.sourceText,
    this.relativePath,
  }) {
    CockpitFoundationValueReader.boundedString(
      sourceText,
      r'$.sourceText',
      maximum: 1048576,
    );
    if (relativePath != null) {
      CockpitFoundationValueReader.relativePath(
        relativePath,
        r'$.relativePath',
      );
    }
  }

  final CockpitDocumentFormat format;
  final String sourceText;
  final String? relativePath;

  Map<String, Object?> toJson() => <String, Object?>{
    'format': format.name,
    'sourceText': sourceText,
    if (relativePath != null) 'relativePath': relativePath,
  };

  factory CockpitDocumentValidationRequest.fromJson(
    Object? value, {
    String path = r'$',
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'format', 'sourceText', 'relativePath'},
      path,
      required: const <String>{'format', 'sourceText'},
    );
    return CockpitDocumentValidationRequest(
      format: CockpitEnumValue<CockpitDocumentFormat>.parse(
        json['format'],
        CockpitDocumentFormat.values,
        '$path.format',
        policy: CockpitDecodePolicy.requests,
      ).requireKnown(),
      sourceText: CockpitFoundationValueReader.boundedString(
        json['sourceText'],
        '$path.sourceText',
        maximum: 1048576,
      ),
      relativePath: json['relativePath'] == null
          ? null
          : CockpitFoundationValueReader.relativePath(
              json['relativePath'],
              '$path.relativePath',
            ),
    );
  }
}

final class CockpitDocumentValidationResult {
  CockpitDocumentValidationResult({
    required this.valid,
    required this.sourceSha256,
    this.testCase,
    Iterable<CockpitTestDiagnostic> diagnostics =
        const <CockpitTestDiagnostic>[],
    Iterable<CockpitTestSourceMapEntry> sourceMap =
        const <CockpitTestSourceMapEntry>[],
  }) : diagnostics = List<CockpitTestDiagnostic>.unmodifiable(diagnostics),
       sourceMap = List<CockpitTestSourceMapEntry>.unmodifiable(sourceMap) {
    CockpitFoundationValueReader.sha256(sourceSha256, r'$.sourceSha256');
    final hasErrors = this.diagnostics.any(
      (diagnostic) =>
          diagnostic.severity == CockpitTestDiagnosticSeverity.error,
    );
    if (valid != (testCase != null && !hasErrors) ||
        (!valid && this.diagnostics.isEmpty)) {
      throw const FormatException('Validation result is inconsistent.');
    }
  }

  final bool valid;
  final String sourceSha256;
  final CockpitTestCase? testCase;
  final List<CockpitTestDiagnostic> diagnostics;
  final List<CockpitTestSourceMapEntry> sourceMap;

  Map<String, Object?> toJson() => <String, Object?>{
    'valid': valid,
    'sourceSha256': sourceSha256,
    if (testCase != null) 'case': testCase!.toJson(),
    'diagnostics': diagnostics
        .map((diagnostic) => diagnostic.toJson())
        .toList(),
    'sourceMap': sourceMap.map((entry) => entry.toJson()).toList(),
  };

  factory CockpitDocumentValidationResult.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'valid',
        'sourceSha256',
        'case',
        'diagnostics',
        'sourceMap',
      },
      path,
      required: const <String>{
        'valid',
        'sourceSha256',
        'diagnostics',
        'sourceMap',
      },
      policy: decodePolicy,
    );
    final rawDiagnostics = CockpitFoundationValueReader.list(
      json['diagnostics'],
      '$path.diagnostics',
    );
    final rawSourceMap = CockpitFoundationValueReader.list(
      json['sourceMap'],
      '$path.sourceMap',
    );
    return CockpitDocumentValidationResult(
      valid: CockpitFoundationValueReader.boolean(json['valid'], '$path.valid'),
      sourceSha256: CockpitFoundationValueReader.sha256(
        json['sourceSha256'],
        '$path.sourceSha256',
      ),
      testCase: json['case'] == null
          ? null
          : CockpitTestCase.fromJson(json['case'], path: '$path.case'),
      diagnostics: <CockpitTestDiagnostic>[
        for (var index = 0; index < rawDiagnostics.length; index += 1)
          CockpitTestDiagnostic.fromJson(
            rawDiagnostics[index],
            path: '$path.diagnostics[$index]',
          ),
      ],
      sourceMap: <CockpitTestSourceMapEntry>[
        for (var index = 0; index < rawSourceMap.length; index += 1)
          CockpitTestSourceMapEntry.fromJson(
            rawSourceMap[index],
            path: '$path.sourceMap[$index]',
          ),
      ],
    );
  }
}
