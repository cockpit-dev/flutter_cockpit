import 'foundation_schema_helpers.dart';

Map<String, Object?> foundationResourceDefinitions() => <String, Object?>{
  'ArtifactResource': objectSchema(
    <String, Object?>{
      'artifactId': schemaRef('Identifier'),
      'workspaceId': schemaRef('Identifier'),
      'runId': schemaRef('Identifier'),
      'attemptId': schemaRef('Identifier'),
      'stepExecutionId': stringSchema(maxLength: 512),
      'kind': schemaRef('Kind'),
      'relativePath': schemaRef('RelativePath'),
      'mediaType': stringSchema(
        pattern: r'^[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+$',
        maxLength: 127,
      ),
      'sizeBytes': integerSchema(minimum: 0),
      'sha256': schemaRef('Sha256'),
      'createdAt': schemaRef('UtcTimestamp'),
      'downloadUrl': schemaRef('ApiPath'),
    },
    optional: const <String>{'attemptId', 'stepExecutionId'},
  ),
  'RootResource': objectSchema(
    <String, Object?>{
      'rootId': schemaRef('Identifier'),
      'canonicalPath': schemaRef('AbsolutePath'),
      'filesystemIdentity': stringSchema(maxLength: 512),
      'state': stringSchema(
        values: const <String>['active', 'draining', 'retired'],
      ),
      'registeredAt': schemaRef('UtcTimestamp'),
      'updatedAt': schemaRef('UtcTimestamp'),
      'retiredAt': schemaRef('UtcTimestamp'),
    },
    optional: const <String>{'retiredAt'},
    extra: <String, Object?>{
      'allOf': <Object?>[
        <String, Object?>{
          'if': <String, Object?>{
            'properties': <String, Object?>{
              'state': <String, Object?>{'const': 'retired'},
            },
          },
          'then': <String, Object?>{
            'required': <String>['retiredAt'],
          },
          'else': <String, Object?>{
            'not': <String, Object?>{
              'required': <String>['retiredAt'],
            },
          },
        },
      ],
    },
  ),
  'RootRegistration': objectSchema(
    <String, Object?>{
      'path': schemaRef('AbsolutePath'),
      'label': stringSchema(maxLength: 128),
    },
    optional: const <String>{'label'},
  ),
  'RootRemoval': objectSchema(<String, Object?>{
    'force': booleanSchema(),
    'drainTimeoutMs': integerSchema(minimum: 0, maximum: 300000),
  }),
  'WorkspaceMarker': objectSchema(<String, Object?>{
    'schemaVersion': stringSchema(constant: 'cockpit.workspace/v2'),
    'workspaceId': schemaRef('Identifier'),
    'projectId': schemaRef('Identifier'),
    'checkoutId': schemaRef('Identifier'),
    'createdAt': schemaRef('UtcTimestamp'),
  }),
  'WorkspaceResource': objectSchema(<String, Object?>{
    'workspaceId': schemaRef('Identifier'),
    'projectId': schemaRef('Identifier'),
    'checkoutId': schemaRef('Identifier'),
    'rootId': schemaRef('Identifier'),
    'canonicalPath': schemaRef('AbsolutePath'),
    'filesystemIdentity': stringSchema(maxLength: 512),
    'state': stringSchema(
      values: const <String>['active', 'draining', 'retired'],
    ),
    'registeredAt': schemaRef('UtcTimestamp'),
    'updatedAt': schemaRef('UtcTimestamp'),
  }),
  'WorkspaceRegistration': objectSchema(<String, Object?>{
    'rootId': schemaRef('Identifier'),
    'path': schemaRef('AbsolutePath'),
  }),
  'WorkspaceRebind': objectSchema(<String, Object?>{
    'path': schemaRef('AbsolutePath'),
    'expectedCheckoutId': schemaRef('Identifier'),
  }),
  'WorkspaceRemoval': objectSchema(<String, Object?>{
    'force': booleanSchema(),
    'drainTimeoutMs': integerSchema(minimum: 0, maximum: 300000),
  }),
  'SourceLocation': objectSchema(
    <String, Object?>{
      'line': integerSchema(minimum: 1),
      'column': integerSchema(minimum: 1),
      'endLine': integerSchema(minimum: 1),
      'endColumn': integerSchema(minimum: 1),
    },
    optional: const <String>{'endLine', 'endColumn'},
    extra: <String, Object?>{
      'dependentRequired': <String, Object?>{
        'endLine': <String>['endColumn'],
        'endColumn': <String>['endLine'],
      },
    },
  ),
  'SourceMapEntry': objectSchema(<String, Object?>{
    'path': stringSchema(maxLength: 4096),
    'location': schemaRef('SourceLocation'),
  }),
  'Diagnostic': objectSchema(
    <String, Object?>{
      'code': schemaRef('Identifier'),
      'message': stringSchema(maxLength: 4096),
      'path': stringSchema(maxLength: 4096),
      'severity': stringSchema(values: const <String>['error', 'warning']),
      'location': schemaRef('SourceLocation'),
      'details': schemaRef('JsonObject'),
    },
    optional: const <String>{'location', 'details'},
  ),
  'CaseIndexEntry': objectSchema(
    <String, Object?>{
      'caseId': schemaRef('Identifier'),
      'title': stringSchema(maxLength: 256),
      'location': schemaRef('SourceLocation'),
    },
    optional: const <String>{'title', 'location'},
  ),
  'DocumentResource': objectSchema(<String, Object?>{
    'documentId': schemaRef('Identifier'),
    'workspaceId': schemaRef('Identifier'),
    'relativePath': schemaRef('RelativePath'),
    'sha256': schemaRef('Sha256'),
    'modifiedAt': schemaRef('UtcTimestamp'),
    'cases': arraySchema(schemaRef('CaseIndexEntry'), unique: true),
  }),
  'IndexedCaseReference': objectSchema(<String, Object?>{
    'documentId': schemaRef('Identifier'),
    'caseId': schemaRef('Identifier'),
    'documentSha256': schemaRef('Sha256'),
  }),
  'DocumentValidationRequest': objectSchema(
    <String, Object?>{
      'format': stringSchema(values: const <String>['yaml', 'json']),
      'sourceText': stringSchema(minLength: 0, maxLength: 1048576),
      'relativePath': schemaRef('RelativePath'),
    },
    optional: const <String>{'relativePath'},
  ),
  'DocumentValidationResult': objectSchema(
    <String, Object?>{
      'valid': booleanSchema(),
      'sourceSha256': schemaRef('Sha256'),
      'case': externalRef('cockpit.test.v2.schema.json#/\$defs/case'),
      'diagnostics': arraySchema(schemaRef('Diagnostic')),
      'sourceMap': arraySchema(schemaRef('SourceMapEntry')),
    },
    optional: const <String>{'case'},
    extra: <String, Object?>{
      'allOf': <Object?>[
        <String, Object?>{
          'if': <String, Object?>{
            'properties': <String, Object?>{
              'valid': <String, Object?>{'const': true},
            },
          },
          'then': <String, Object?>{
            'required': <String>['case'],
          },
          'else': <String, Object?>{
            'not': <String, Object?>{
              'required': <String>['case'],
            },
            'properties': <String, Object?>{
              'diagnostics': <String, Object?>{'minItems': 1},
            },
          },
        },
      ],
    },
  ),
  'RootPage': pageSchema('RootResource'),
  'WorkspacePage': pageSchema('WorkspaceResource'),
  'DocumentPage': pageSchema('DocumentResource'),
  'CasePage': pageSchema('CaseIndexEntry'),
  'ArtifactPage': pageSchema('ArtifactResource'),
};
