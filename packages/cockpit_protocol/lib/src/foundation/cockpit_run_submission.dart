import '../test/cockpit_test_case.dart';
import 'cockpit_decode_policy.dart';
import 'cockpit_document.dart';
import 'cockpit_foundation_value_reader.dart';
import 'cockpit_idempotency.dart';

sealed class CockpitCaseSubmissionSource {
  const CockpitCaseSubmissionSource();

  String get kind;

  Map<String, Object?> toJson();

  static CockpitCaseSubmissionSource fromJson(
    Object? value, {
    String path = r'$',
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    final kind = CockpitFoundationValueReader.string(
      json['kind'],
      '$path.kind',
    );
    return switch (kind) {
      'inline' => CockpitInlineCaseSource.fromJson(value, path: path),
      'indexed' => CockpitIndexedCaseSource.fromJson(value, path: path),
      _ => throw FormatException('Unsupported case source kind at $path.kind.'),
    };
  }
}

final class CockpitInlineCaseSource extends CockpitCaseSubmissionSource {
  CockpitInlineCaseSource({
    required this.testCase,
    required this.sourceSha256,
  }) {
    CockpitFoundationValueReader.sha256(sourceSha256, r'$.sourceSha256');
  }

  @override
  String get kind => 'inline';

  final CockpitTestCase testCase;
  final String sourceSha256;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'case': testCase.toJson(),
    'sourceSha256': sourceSha256,
  };

  factory CockpitInlineCaseSource.fromJson(
    Object? value, {
    String path = r'$',
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'kind', 'case', 'sourceSha256'},
      path,
      required: const <String>{'kind', 'case', 'sourceSha256'},
    );
    if (json['kind'] != 'inline') {
      throw FormatException('Expected inline case source at $path.kind.');
    }
    return CockpitInlineCaseSource(
      testCase: CockpitTestCase.fromJson(json['case'], path: '$path.case'),
      sourceSha256: CockpitFoundationValueReader.sha256(
        json['sourceSha256'],
        '$path.sourceSha256',
      ),
    );
  }
}

final class CockpitIndexedCaseSource extends CockpitCaseSubmissionSource {
  CockpitIndexedCaseSource({required this.reference});

  @override
  String get kind => 'indexed';

  final CockpitIndexedCaseReference reference;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind,
    'reference': reference.toJson(),
  };

  factory CockpitIndexedCaseSource.fromJson(
    Object? value, {
    String path = r'$',
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'kind', 'reference'},
      path,
      required: const <String>{'kind', 'reference'},
    );
    if (json['kind'] != 'indexed') {
      throw FormatException('Expected indexed case source at $path.kind.');
    }
    return CockpitIndexedCaseSource(
      reference: CockpitIndexedCaseReference.fromJson(
        json['reference'],
        path: '$path.reference',
      ),
    );
  }
}

final class CockpitRunSubmission {
  CockpitRunSubmission({
    required this.workspaceId,
    required this.source,
    required this.idempotencyKey,
    Map<String, Object?> inputs = const <String, Object?>{},
    this.targetId,
    Iterable<String> requiredFeatures = const <String>[],
  }) : inputs = CockpitFoundationValueReader.jsonObject(inputs, r'$.inputs'),
       requiredFeatures = List<String>.unmodifiable(requiredFeatures) {
    CockpitFoundationValueReader.id(workspaceId, r'$.workspaceId');
    if (targetId != null) {
      CockpitFoundationValueReader.id(targetId, r'$.targetId');
    }
    final features = <String>{};
    for (final feature in this.requiredFeatures) {
      CockpitFoundationValueReader.id(feature, r'$.requiredFeatures[]');
      if (!features.add(feature)) {
        throw FormatException('Duplicate required feature $feature.');
      }
    }
  }

  final String workspaceId;
  final CockpitCaseSubmissionSource source;
  final CockpitIdempotencyKey idempotencyKey;
  final Map<String, Object?> inputs;
  final String? targetId;
  final List<String> requiredFeatures;

  Map<String, Object?> toJson() => <String, Object?>{
    'workspaceId': workspaceId,
    'source': source.toJson(),
    'idempotencyKey': idempotencyKey.toJson(),
    'inputs': inputs,
    if (targetId != null) 'targetId': targetId,
    'requiredFeatures': requiredFeatures,
  };

  factory CockpitRunSubmission.fromJson(Object? value, {String path = r'$'}) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{
        'workspaceId',
        'source',
        'idempotencyKey',
        'inputs',
        'targetId',
        'requiredFeatures',
      },
      path,
      required: const <String>{
        'workspaceId',
        'source',
        'idempotencyKey',
        'inputs',
        'requiredFeatures',
      },
    );
    return CockpitRunSubmission(
      workspaceId: CockpitFoundationValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      source: CockpitCaseSubmissionSource.fromJson(
        json['source'],
        path: '$path.source',
      ),
      idempotencyKey: CockpitIdempotencyKey.fromJson(
        json['idempotencyKey'],
        path: '$path.idempotencyKey',
      ),
      inputs: CockpitFoundationValueReader.jsonObject(
        json['inputs'],
        '$path.inputs',
      ),
      targetId: json['targetId'] == null
          ? null
          : CockpitFoundationValueReader.id(json['targetId'], '$path.targetId'),
      requiredFeatures: CockpitFoundationValueReader.ids(
        json['requiredFeatures'],
        '$path.requiredFeatures',
      ),
    );
  }
}

final class CockpitRunAccepted {
  CockpitRunAccepted({
    required this.workspaceId,
    required this.runId,
    required this.statusUrl,
    required this.eventsUrl,
    required this.submittedAt,
    required this.replayed,
  }) {
    CockpitFoundationValueReader.id(workspaceId, r'$.workspaceId');
    CockpitFoundationValueReader.id(runId, r'$.runId');
    CockpitFoundationValueReader.apiPath(statusUrl, r'$.statusUrl');
    CockpitFoundationValueReader.apiPath(eventsUrl, r'$.eventsUrl');
    CockpitFoundationValueReader.utcDateTime(submittedAt, r'$.submittedAt');
  }

  final String workspaceId;
  final String runId;
  final String statusUrl;
  final String eventsUrl;
  final DateTime submittedAt;
  final bool replayed;

  Map<String, Object?> toJson() => <String, Object?>{
    'workspaceId': workspaceId,
    'runId': runId,
    'statusUrl': statusUrl,
    'eventsUrl': eventsUrl,
    'submittedAt': submittedAt.toIso8601String(),
    'replayed': replayed,
  };

  factory CockpitRunAccepted.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    const fields = <String>{
      'workspaceId',
      'runId',
      'statusUrl',
      'eventsUrl',
      'submittedAt',
      'replayed',
    };
    CockpitFoundationValueReader.keys(
      json,
      fields,
      path,
      required: fields,
      policy: decodePolicy,
    );
    return CockpitRunAccepted(
      workspaceId: CockpitFoundationValueReader.id(
        json['workspaceId'],
        '$path.workspaceId',
      ),
      runId: CockpitFoundationValueReader.id(json['runId'], '$path.runId'),
      statusUrl: CockpitFoundationValueReader.apiPath(
        json['statusUrl'],
        '$path.statusUrl',
      ),
      eventsUrl: CockpitFoundationValueReader.apiPath(
        json['eventsUrl'],
        '$path.eventsUrl',
      ),
      submittedAt: CockpitFoundationValueReader.dateTime(
        json['submittedAt'],
        '$path.submittedAt',
      ),
      replayed: CockpitFoundationValueReader.boolean(
        json['replayed'],
        '$path.replayed',
      ),
    );
  }
}

final class CockpitRunCancellationRequest {
  CockpitRunCancellationRequest({required this.idempotencyKey, this.reason}) {
    if (reason != null) {
      CockpitFoundationValueReader.string(reason, r'$.reason', maximum: 512);
    }
  }

  final CockpitIdempotencyKey idempotencyKey;
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'idempotencyKey': idempotencyKey.toJson(),
    if (reason != null) 'reason': reason,
  };

  factory CockpitRunCancellationRequest.fromJson(
    Object? value, {
    String path = r'$',
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    CockpitFoundationValueReader.keys(
      json,
      const <String>{'idempotencyKey', 'reason'},
      path,
      required: const <String>{'idempotencyKey'},
    );
    return CockpitRunCancellationRequest(
      idempotencyKey: CockpitIdempotencyKey.fromJson(
        json['idempotencyKey'],
        path: '$path.idempotencyKey',
      ),
      reason: CockpitFoundationValueReader.optionalString(
        json['reason'],
        '$path.reason',
        maximum: 512,
      ),
    );
  }
}

final class CockpitRunCancellation {
  CockpitRunCancellation({
    required this.runId,
    required this.requestedAt,
    required this.replayed,
  }) {
    CockpitFoundationValueReader.id(runId, r'$.runId');
    CockpitFoundationValueReader.utcDateTime(requestedAt, r'$.requestedAt');
  }

  final String runId;
  final DateTime requestedAt;
  final bool replayed;

  Map<String, Object?> toJson() => <String, Object?>{
    'runId': runId,
    'requestedAt': requestedAt.toIso8601String(),
    'replayed': replayed,
  };

  factory CockpitRunCancellation.fromJson(
    Object? value, {
    String path = r'$',
    CockpitDecodePolicy decodePolicy = CockpitDecodePolicy.requests,
  }) {
    final json = CockpitFoundationValueReader.object(value, path);
    const fields = <String>{'runId', 'requestedAt', 'replayed'};
    CockpitFoundationValueReader.keys(
      json,
      fields,
      path,
      required: fields,
      policy: decodePolicy,
    );
    return CockpitRunCancellation(
      runId: CockpitFoundationValueReader.id(json['runId'], '$path.runId'),
      requestedAt: CockpitFoundationValueReader.dateTime(
        json['requestedAt'],
        '$path.requestedAt',
      ),
      replayed: CockpitFoundationValueReader.boolean(
        json['replayed'],
        '$path.replayed',
      ),
    );
  }
}
