Map<String, Object?> componentSchemaRef(String name) => <String, Object?>{
  r'$ref': '#/components/schemas/$name',
};

Map<String, Object?> parameterRef(String name) => <String, Object?>{
  r'$ref': '#/components/parameters/$name',
};

Map<String, Object?> requestBody(String schemaName) => <String, Object?>{
  'required': true,
  'content': <String, Object?>{
    'application/json': <String, Object?>{
      'schema': componentSchemaRef(schemaName),
    },
  },
};

Map<String, Object?> jsonResponse(String description, String schemaName) =>
    <String, Object?>{
      'description': description,
      'content': <String, Object?>{
        'application/json': <String, Object?>{
          'schema': componentSchemaRef(schemaName),
        },
      },
    };

Map<String, Object?> negotiatedOperation({
  required String operationId,
  required String summary,
  required Map<String, Object?> responses,
  String? requestSchema,
  Iterable<Map<String, Object?>> parameters = const <Map<String, Object?>>[],
  String? description,
}) => <String, Object?>{
  'operationId': operationId,
  'summary': summary,
  'description': ?description,
  'parameters': <Object?>[
    parameterRef('ApiVersion'),
    parameterRef('RequiredFeatures'),
    ...parameters,
  ],
  if (requestSchema != null) 'requestBody': requestBody(requestSchema),
  'responses': <String, Object?>{...responses, ...standardErrorResponses()},
};

Map<String, Object?> standardErrorResponses() => <String, Object?>{
  '400': <String, Object?>{r'$ref': '#/components/responses/BadRequest'},
  '401': <String, Object?>{r'$ref': '#/components/responses/Unauthorized'},
  '404': <String, Object?>{r'$ref': '#/components/responses/NotFound'},
  '409': <String, Object?>{r'$ref': '#/components/responses/Conflict'},
  '413': <String, Object?>{r'$ref': '#/components/responses/TooLarge'},
  '415': <String, Object?>{r'$ref': '#/components/responses/UnsupportedMedia'},
  '422': <String, Object?>{r'$ref': '#/components/responses/Unprocessable'},
  '426': <String, Object?>{r'$ref': '#/components/responses/UpgradeRequired'},
  '429': <String, Object?>{r'$ref': '#/components/responses/ResourceBusy'},
  '500': <String, Object?>{r'$ref': '#/components/responses/Internal'},
  '503': <String, Object?>{r'$ref': '#/components/responses/Unavailable'},
};

Map<String, Object?> pageParameters() => <String, Object?>{
  'Limit': <String, Object?>{
    'name': 'limit',
    'in': 'query',
    'required': false,
    'schema': <String, Object?>{
      'type': 'integer',
      'minimum': 1,
      'maximum': 100,
      'default': 50,
    },
  },
  'Cursor': <String, Object?>{
    'name': 'cursor',
    'in': 'query',
    'required': false,
    'schema': <String, Object?>{
      'type': 'string',
      'pattern': r'^[A-Za-z0-9_-]+$',
      'maxLength': 512,
    },
  },
};
