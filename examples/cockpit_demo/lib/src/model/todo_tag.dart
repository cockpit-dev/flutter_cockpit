import 'package:flutter/foundation.dart';

@immutable
final class TodoTag {
  const TodoTag({
    required this.id,
    required this.name,
    this.colorHex,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? colorHex;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TodoTag &&
            other.id == id &&
            other.name == name &&
            other.colorHex == colorHex &&
            other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, createdAt);
}
