abstract interface class CockpitTestDocument {
  String get schemaVersion;

  String get kind;

  String get id;

  String? get name;

  Map<String, Object?> toJson();
}
