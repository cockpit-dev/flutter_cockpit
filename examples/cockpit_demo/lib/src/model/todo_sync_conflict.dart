import 'package:flutter/foundation.dart';

enum TodoSyncConflictType { remoteDelete, concurrentEdit, remoteMetadataChange }

enum TodoConflictResolution { keepLocal, keepRemote, mergeFields }

@immutable
final class TodoSyncConflict {
  const TodoSyncConflict({
    required this.type,
    required this.summary,
    this.localFields = const <String>[],
    this.remoteFields = const <String>[],
  });

  final TodoSyncConflictType type;
  final String summary;
  final List<String> localFields;
  final List<String> remoteFields;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'summary': summary,
    'localFields': localFields,
    'remoteFields': remoteFields,
  };

  factory TodoSyncConflict.fromJson(Map<String, Object?> json) {
    return TodoSyncConflict(
      type: TodoSyncConflictType.values.byName('${json['type']}'),
      summary: '${json['summary'] ?? ''}',
      localFields: (json['localFields'] as List<Object?>? ?? const <Object?>[])
          .map((value) => '$value')
          .toList(growable: false),
      remoteFields:
          (json['remoteFields'] as List<Object?>? ?? const <Object?>[])
              .map((value) => '$value')
              .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TodoSyncConflict &&
            other.type == type &&
            other.summary == summary &&
            listEquals(other.localFields, localFields) &&
            listEquals(other.remoteFields, remoteFields);
  }

  @override
  int get hashCode => Object.hash(
    type,
    summary,
    Object.hashAll(localFields),
    Object.hashAll(remoteFields),
  );
}
