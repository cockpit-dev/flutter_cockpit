import 'package:cockpit_protocol/src/foundation/cockpit_foundation_constraints.dart';
import 'foundation_schema_helpers.dart';

Map<String, Object?> foundationCommonDefinitions() => <String, Object?>{
  'Identifier': stringSchema(
    pattern: r'^[A-Za-z][A-Za-z0-9._-]{0,127}$',
    maxLength: 128,
  ),
  'Kind': stringSchema(
    pattern: r'^[a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)+$',
    maxLength: 128,
  ),
  'Sha256': stringSchema(pattern: r'^[a-f0-9]{64}$', maxLength: 64),
  'UtcTimestamp': stringSchema(
    format: 'date-time',
    pattern: r'Z$',
    maxLength: 64,
  ),
  'AbsolutePath': stringSchema(
    pattern: cockpitFoundationAbsolutePathPattern,
    maxLength: 4096,
  ),
  'RelativePath': stringSchema(
    pattern:
        r'^(?!/)(?![A-Za-z]:)(?!.*\\)(?!.*(?:^|/)\.\.?(?:/|$))[^/]+(?:/[^/]+)*$',
    maxLength: 4096,
  ),
  'ApiPath': stringSchema(pattern: r'^/api/v2/', maxLength: 4096),
  'ApiTemplate': stringSchema(pattern: r'^/api/v2/', maxLength: 4096),
  'SchemaReference': stringSchema(pattern: r'#\/\$defs\/', maxLength: 1024),
  'Cursor': stringSchema(pattern: r'^[A-Za-z0-9_-]+$', maxLength: 512),
  'IdempotencyKey': stringSchema(
    pattern: r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
    maxLength: 128,
  ),
  'JsonObject': jsonObjectSchema(),
  'ApiVersion': objectSchema(<String, Object?>{
    'major': integerSchema(minimum: 1),
    'minor': integerSchema(minimum: 0),
  }),
  'FeatureDescriptor': objectSchema(<String, Object?>{
    'id': schemaRef('Identifier'),
    'revision': integerSchema(minimum: 1),
    'minimumApiMinor': integerSchema(minimum: 0),
  }),
  'ServerInfo': objectSchema(<String, Object?>{
    'schemaVersion': stringSchema(constant: 'cockpit.foundation/v2'),
    'instanceId': schemaRef('Identifier'),
    'apiVersion': schemaRef('ApiVersion'),
    'engineVersion': stringSchema(maxLength: 128),
    'startedAt': schemaRef('UtcTimestamp'),
    'features': arraySchema(schemaRef('FeatureDescriptor'), unique: true),
  }),
  'NegotiationRequest': objectSchema(<String, Object?>{
    'apiVersion': schemaRef('ApiVersion'),
    'requiredFeatures': arraySchema(schemaRef('Identifier'), unique: true),
  }),
  'NegotiationResult': objectSchema(<String, Object?>{
    'apiVersion': schemaRef('ApiVersion'),
    'featureIds': arraySchema(schemaRef('Identifier'), unique: true),
  }),
  'ArtifactReference': objectSchema(
    <String, Object?>{
      'artifactId': schemaRef('Identifier'),
      'runId': schemaRef('Identifier'),
      'sha256': schemaRef('Sha256'),
    },
    optional: const <String>{'sha256'},
  ),
  'ApiError': objectSchema(
    <String, Object?>{
      'code': schemaRef('Identifier'),
      'category': stringSchema(
        values: const <String>[
          'invalidInput',
          'unsupported',
          'environment',
          'resource',
          'driver',
          'locator',
          'assertion',
          'application',
          'evidence',
          'cancelled',
          'interrupted',
          'internal',
        ],
      ),
      'message': stringSchema(maxLength: 4096),
      'retryable': booleanSchema(),
      'responsibleLayer': stringSchema(
        values: const <String>[
          'client',
          'supervisor',
          'worker',
          'provider',
          'driver',
          'application',
        ],
      ),
      'redactedDetails': schemaRef('JsonObject'),
      'artifacts': arraySchema(schemaRef('ArtifactReference'), unique: true),
    },
    optional: const <String>{'redactedDetails', 'artifacts'},
  ),
  'ApiWarning': objectSchema(<String, Object?>{
    'stage': stringSchema(values: const <String>['cleanup', 'evidence']),
    'error': schemaRef('ApiError'),
  }),
  'Failure': objectSchema(
    <String, Object?>{
      'primary': schemaRef('ApiError'),
      'warnings': arraySchema(schemaRef('ApiWarning')),
    },
    optional: const <String>{'warnings'},
  ),
  'ApiErrorResponse': objectSchema(<String, Object?>{
    'schemaVersion': stringSchema(constant: 'cockpit.foundation/v2'),
    'requestId': schemaRef('Identifier'),
    'timestamp': schemaRef('UtcTimestamp'),
    'failure': schemaRef('Failure'),
  }),
  'PageRequest': objectSchema(
    <String, Object?>{
      'limit': integerSchema(
        minimum: 1,
        maximum: cockpitFoundationPageSizeMaximum,
      ),
      'cursor': schemaRef('Cursor'),
    },
    optional: const <String>{'limit', 'cursor'},
  ),
};
