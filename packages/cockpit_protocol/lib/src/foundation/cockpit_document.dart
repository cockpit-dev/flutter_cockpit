import '../test/cockpit_test_diagnostic.dart';
import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_value_reader.dart';

final class CockpitCaseIndexEntry {
  CockpitCaseIndexEntry({required this.caseId, this.title, this.location}) {
    CockpitFoundationValueReader.id(caseId, r'$.caseId');
    if (title != null) {
      CockpitFoundationValueReader.string(title, r'$.title', maximum: 256);
    }
  }

  final String caseId;
  final String? title;
  final CockpitTestSourceLocation? location;

  Map<String, Object?> toJson() => <String, Object?>{
    'caseId': caseId,
    if (title != null) 'title': title,
    if (location != null) 'location': location!.toJson(),
  };

  factory CockpitCaseIndexEntry.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'caseId', 'title', 'location'},
      path,
      required: const <String>{'caseId'},
      policy: decodePolicy,
    );
    return CockpitCaseIndexEntry(
      caseId: CockpitFoundationValueReader.id(json['caseId'], '$path.caseId'),
      title: CockpitFoundationValueReader.optionalString(
        json['title'],
        '$path.title',
        maximum: 256,
      ),
      location: json['location'] == null
          ? null
          : CockpitTestSourceLocation.fromJson(
              json['location'],
              path: '$path.location',
            ),
    );
  }
}

final class CockpitDocumentResource {
  CockpitDocumentResource({
    required this.documentId,
    required this.workspaceId,
    required this.relativePath,
    required this.sha256,
    required this.modifiedAt,
    Iterable<CockpitCaseIndexEntry> cases = const <CockpitCaseIndexEntry>[],
  }) : cases = List<CockpitCaseIndexEntry>.unmodifiable(cases) {
    CockpitFoundationValueReader.id(documentId, r'$.documentId');
    CockpitFoundationValueReader.id(workspaceId, r'$.workspaceId');
    CockpitFoundationValueReader.relativePath(relativePath, r'$.relativePath');
    CockpitFoundationValueReader.sha256(sha256, r'$.sha256');
    CockpitFoundationValueReader.utcDateTime(modifiedAt, r'$.modifiedAt');
    final caseIds = <String>{};
    for (final testCase in this.cases) {
      if (!caseIds.add(testCase.caseId)) {
        throw FormatException('Duplicate case ${testCase.caseId}.');
      }
    }
  }

  final String documentId;
  final String workspaceId;
  final String relativePath;
  final String sha256;
  final DateTime modifiedAt;
  final List<CockpitCaseIndexEntry> cases;

  Map<String, Object?> toJson() => <String, Object?>{
    'documentId': documentId,
    'workspaceId': workspaceId,
    'relativePath': relativePath,
    'sha256': sha256,
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    'cases': cases.map((testCase) => testCase.toJson()).toList(),
  };

  factory CockpitDocumentResource.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    const fields = <String>{
      'documentId',
      'workspaceId',
      'relativePath',
      'sha256',
      'modifiedAt',
      'cases',
    };
    CockpitFoundationValueReader.keys(
      json,
      fields,
      path,
      required: fields,
      policy: decodePolicy,
    );
    final rawCases = CockpitFoundationValueReader.list(
      json['cases'],
      '$path.cases',
    );
    return CockpitDocumentResource(
      documentId: CockpitFoundationValueReader.id(
        json['documentId'],
        '$path.documentId',
      ),
      workspaceId: CockpitFoundationValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      relativePath: CockpitFoundationValueReader.relativePath(
        json['relativePath'],
        '$path.relativePath',
      ),
      sha256: CockpitFoundationValueReader.sha256(
        json['sha256'],
        '$path.sha256',
      ),
      modifiedAt: CockpitFoundationValueReader.dateTime(
        json['modifiedAt'],
        '$path.modifiedAt',
      ),
      cases: <CockpitCaseIndexEntry>[
        for (var index = 0; index < rawCases.length; index += 1)
          CockpitCaseIndexEntry.fromJson(
            rawCases[index],
            path: '$path.cases[$index]',
            decodePolicy: decodePolicy,
          ),
      ],
    );
  }
}

final class CockpitIndexedCaseReference {
  CockpitIndexedCaseReference({
    required this.documentId,
    required this.caseId,
    required this.documentSha256,
  }) {
    CockpitFoundationValueReader.id(documentId, r'$.documentId');
    CockpitFoundationValueReader.id(caseId, r'$.caseId');
    CockpitFoundationValueReader.sha256(documentSha256, r'$.documentSha256');
  }

  final String documentId;
  final String caseId;
  final String documentSha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'documentId': documentId,
    'caseId': caseId,
    'documentSha256': documentSha256,
  };

  factory CockpitIndexedCaseReference.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    const fields = <String>{'documentId', 'caseId', 'documentSha256'};
    CockpitFoundationValueReader.keys(
      json,
      fields,
      path,
      required: fields,
      policy: decodePolicy,
    );
    return CockpitIndexedCaseReference(
      documentId: CockpitFoundationValueReader.id(
        json['documentId'],
        '$path.documentId',
      ),
      caseId: CockpitFoundationValueReader.id(json['caseId'], '$path.caseId'),
      documentSha256: CockpitFoundationValueReader.sha256(
        json['documentSha256'],
        '$path.documentSha256',
      ),
    );
  }
}
