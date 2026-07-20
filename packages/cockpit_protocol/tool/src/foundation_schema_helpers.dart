Map<String, Object?> schemaRef(String name) => <String, Object?>{
  r'$ref': '#/\$defs/$name',
};

Map<String, Object?> externalRef(String value) => <String, Object?>{
  r'$ref': value,
};

Map<String, Object?> stringSchema({
  String? pattern,
  String? format,
  Iterable<String>? values,
  int minLength = 1,
  int? maxLength,
  String? constant,
}) => <String, Object?>{
  'type': 'string',
  'const': ?constant,
  if (values != null) 'enum': values.toList(),
  'pattern': ?pattern,
  'format': ?format,
  'minLength': minLength,
  'maxLength': ?maxLength,
};

Map<String, Object?> integerSchema({int? minimum, int? maximum}) =>
    <String, Object?>{
      'type': 'integer',
      'minimum': ?minimum,
      'maximum': ?maximum,
    };

Map<String, Object?> booleanSchema() => <String, Object?>{'type': 'boolean'};

Map<String, Object?> jsonObjectSchema() => <String, Object?>{
  'type': 'object',
  'additionalProperties': true,
};

Map<String, Object?> objectSchema(
  Map<String, Object?> properties, {
  Set<String> optional = const <String>{},
  Map<String, Object?>? extra,
}) => <String, Object?>{
  'type': 'object',
  'properties': properties,
  'required': properties.keys
      .where((property) => !optional.contains(property))
      .toList(),
  'additionalProperties': false,
  ...?extra,
};

Map<String, Object?> arraySchema(
  Map<String, Object?> items, {
  int? minItems,
  int? maxItems,
  bool unique = false,
}) => <String, Object?>{
  'type': 'array',
  'items': items,
  'minItems': ?minItems,
  'maxItems': ?maxItems,
  if (unique) 'uniqueItems': true,
};

Map<String, Object?> oneOfSchema(Iterable<Map<String, Object?>> schemas) =>
    <String, Object?>{'oneOf': schemas.toList()};

Map<String, Object?> pageSchema(String itemDefinition) => objectSchema(
  <String, Object?>{
    'items': arraySchema(schemaRef(itemDefinition), maxItems: 100),
    'nextCursor': schemaRef('Cursor'),
    'totalCount': integerSchema(minimum: 0),
  },
  optional: const <String>{'nextCursor', 'totalCount'},
);
