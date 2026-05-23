// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cockpit_demo_database.dart';

// ignore_for_file: type=lint
class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dueAtEpochMsMeta = const VerificationMeta(
    'dueAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> dueAtEpochMs = GeneratedColumn<int>(
    'due_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtEpochMsMeta =
      const VerificationMeta('completedAtEpochMs');
  @override
  late final GeneratedColumn<int> completedAtEpochMs = GeneratedColumn<int>(
    'completed_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtEpochMsMeta = const VerificationMeta(
    'deletedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtEpochMs = GeneratedColumn<int>(
    'deleted_at_epoch_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdsJsonMeta = const VerificationMeta(
    'tagIdsJson',
  );
  @override
  late final GeneratedColumn<String> tagIdsJson = GeneratedColumn<String>(
    'tag_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    priority,
    dueAtEpochMs,
    isCompleted,
    completedAtEpochMs,
    deletedAtEpochMs,
    displayOrder,
    tagIdsJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('due_at_epoch_ms')) {
      context.handle(
        _dueAtEpochMsMeta,
        dueAtEpochMs.isAcceptableOrUnknown(
          data['due_at_epoch_ms']!,
          _dueAtEpochMsMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('completed_at_epoch_ms')) {
      context.handle(
        _completedAtEpochMsMeta,
        completedAtEpochMs.isAcceptableOrUnknown(
          data['completed_at_epoch_ms']!,
          _completedAtEpochMsMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at_epoch_ms')) {
      context.handle(
        _deletedAtEpochMsMeta,
        deletedAtEpochMs.isAcceptableOrUnknown(
          data['deleted_at_epoch_ms']!,
          _deletedAtEpochMsMeta,
        ),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayOrderMeta);
    }
    if (data.containsKey('tag_ids_json')) {
      context.handle(
        _tagIdsJsonMeta,
        tagIdsJson.isAcceptableOrUnknown(
          data['tag_ids_json']!,
          _tagIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      dueAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_at_epoch_ms'],
      ),
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      completedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_epoch_ms'],
      ),
      deletedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_epoch_ms'],
      ),
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      tagIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_ids_json'],
      )!,
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String title;
  final String notes;
  final int priority;
  final int? dueAtEpochMs;
  final bool isCompleted;
  final int? completedAtEpochMs;
  final int? deletedAtEpochMs;
  final int displayOrder;
  final String tagIdsJson;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;
  const Task({
    required this.id,
    required this.title,
    required this.notes,
    required this.priority,
    this.dueAtEpochMs,
    required this.isCompleted,
    this.completedAtEpochMs,
    this.deletedAtEpochMs,
    required this.displayOrder,
    required this.tagIdsJson,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['notes'] = Variable<String>(notes);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || dueAtEpochMs != null) {
      map['due_at_epoch_ms'] = Variable<int>(dueAtEpochMs);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAtEpochMs != null) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs);
    }
    if (!nullToAbsent || deletedAtEpochMs != null) {
      map['deleted_at_epoch_ms'] = Variable<int>(deletedAtEpochMs);
    }
    map['display_order'] = Variable<int>(displayOrder);
    map['tag_ids_json'] = Variable<String>(tagIdsJson);
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      notes: Value(notes),
      priority: Value(priority),
      dueAtEpochMs: dueAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAtEpochMs),
      isCompleted: Value(isCompleted),
      completedAtEpochMs: completedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtEpochMs),
      deletedAtEpochMs: deletedAtEpochMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtEpochMs),
      displayOrder: Value(displayOrder),
      tagIdsJson: Value(tagIdsJson),
      createdAtEpochMs: Value(createdAtEpochMs),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String>(json['notes']),
      priority: serializer.fromJson<int>(json['priority']),
      dueAtEpochMs: serializer.fromJson<int?>(json['dueAtEpochMs']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAtEpochMs: serializer.fromJson<int?>(json['completedAtEpochMs']),
      deletedAtEpochMs: serializer.fromJson<int?>(json['deletedAtEpochMs']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      tagIdsJson: serializer.fromJson<String>(json['tagIdsJson']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String>(notes),
      'priority': serializer.toJson<int>(priority),
      'dueAtEpochMs': serializer.toJson<int?>(dueAtEpochMs),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAtEpochMs': serializer.toJson<int?>(completedAtEpochMs),
      'deletedAtEpochMs': serializer.toJson<int?>(deletedAtEpochMs),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'tagIdsJson': serializer.toJson<String>(tagIdsJson),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    int? priority,
    Value<int?> dueAtEpochMs = const Value.absent(),
    bool? isCompleted,
    Value<int?> completedAtEpochMs = const Value.absent(),
    Value<int?> deletedAtEpochMs = const Value.absent(),
    int? displayOrder,
    String? tagIdsJson,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    priority: priority ?? this.priority,
    dueAtEpochMs: dueAtEpochMs.present ? dueAtEpochMs.value : this.dueAtEpochMs,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAtEpochMs: completedAtEpochMs.present
        ? completedAtEpochMs.value
        : this.completedAtEpochMs,
    deletedAtEpochMs: deletedAtEpochMs.present
        ? deletedAtEpochMs.value
        : this.deletedAtEpochMs,
    displayOrder: displayOrder ?? this.displayOrder,
    tagIdsJson: tagIdsJson ?? this.tagIdsJson,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueAtEpochMs: data.dueAtEpochMs.present
          ? data.dueAtEpochMs.value
          : this.dueAtEpochMs,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      completedAtEpochMs: data.completedAtEpochMs.present
          ? data.completedAtEpochMs.value
          : this.completedAtEpochMs,
      deletedAtEpochMs: data.deletedAtEpochMs.present
          ? data.deletedAtEpochMs.value
          : this.deletedAtEpochMs,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      tagIdsJson: data.tagIdsJson.present
          ? data.tagIdsJson.value
          : this.tagIdsJson,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority, ')
          ..write('dueAtEpochMs: $dueAtEpochMs, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAtEpochMs: $completedAtEpochMs, ')
          ..write('deletedAtEpochMs: $deletedAtEpochMs, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('tagIdsJson: $tagIdsJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    priority,
    dueAtEpochMs,
    isCompleted,
    completedAtEpochMs,
    deletedAtEpochMs,
    displayOrder,
    tagIdsJson,
    createdAtEpochMs,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.priority == this.priority &&
          other.dueAtEpochMs == this.dueAtEpochMs &&
          other.isCompleted == this.isCompleted &&
          other.completedAtEpochMs == this.completedAtEpochMs &&
          other.deletedAtEpochMs == this.deletedAtEpochMs &&
          other.displayOrder == this.displayOrder &&
          other.tagIdsJson == this.tagIdsJson &&
          other.createdAtEpochMs == this.createdAtEpochMs &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> notes;
  final Value<int> priority;
  final Value<int?> dueAtEpochMs;
  final Value<bool> isCompleted;
  final Value<int?> completedAtEpochMs;
  final Value<int?> deletedAtEpochMs;
  final Value<int> displayOrder;
  final Value<String> tagIdsJson;
  final Value<int> createdAtEpochMs;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAtEpochMs = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAtEpochMs = const Value.absent(),
    this.deletedAtEpochMs = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.tagIdsJson = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.notes = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAtEpochMs = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAtEpochMs = const Value.absent(),
    this.deletedAtEpochMs = const Value.absent(),
    required int displayOrder,
    this.tagIdsJson = const Value.absent(),
    required int createdAtEpochMs,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       displayOrder = Value(displayOrder),
       createdAtEpochMs = Value(createdAtEpochMs),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? priority,
    Expression<int>? dueAtEpochMs,
    Expression<bool>? isCompleted,
    Expression<int>? completedAtEpochMs,
    Expression<int>? deletedAtEpochMs,
    Expression<int>? displayOrder,
    Expression<String>? tagIdsJson,
    Expression<int>? createdAtEpochMs,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (priority != null) 'priority': priority,
      if (dueAtEpochMs != null) 'due_at_epoch_ms': dueAtEpochMs,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAtEpochMs != null)
        'completed_at_epoch_ms': completedAtEpochMs,
      if (deletedAtEpochMs != null) 'deleted_at_epoch_ms': deletedAtEpochMs,
      if (displayOrder != null) 'display_order': displayOrder,
      if (tagIdsJson != null) 'tag_ids_json': tagIdsJson,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? notes,
    Value<int>? priority,
    Value<int?>? dueAtEpochMs,
    Value<bool>? isCompleted,
    Value<int?>? completedAtEpochMs,
    Value<int?>? deletedAtEpochMs,
    Value<int>? displayOrder,
    Value<String>? tagIdsJson,
    Value<int>? createdAtEpochMs,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      dueAtEpochMs: dueAtEpochMs ?? this.dueAtEpochMs,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAtEpochMs: completedAtEpochMs ?? this.completedAtEpochMs,
      deletedAtEpochMs: deletedAtEpochMs ?? this.deletedAtEpochMs,
      displayOrder: displayOrder ?? this.displayOrder,
      tagIdsJson: tagIdsJson ?? this.tagIdsJson,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (dueAtEpochMs.present) {
      map['due_at_epoch_ms'] = Variable<int>(dueAtEpochMs.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAtEpochMs.present) {
      map['completed_at_epoch_ms'] = Variable<int>(completedAtEpochMs.value);
    }
    if (deletedAtEpochMs.present) {
      map['deleted_at_epoch_ms'] = Variable<int>(deletedAtEpochMs.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (tagIdsJson.present) {
      map['tag_ids_json'] = Variable<String>(tagIdsJson.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('priority: $priority, ')
          ..write('dueAtEpochMs: $dueAtEpochMs, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAtEpochMs: $completedAtEpochMs, ')
          ..write('deletedAtEpochMs: $deletedAtEpochMs, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('tagIdsJson: $tagIdsJson, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtEpochMsMeta = const VerificationMeta(
    'createdAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> createdAtEpochMs = GeneratedColumn<int>(
    'created_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorHex, createdAtEpochMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('created_at_epoch_ms')) {
      context.handle(
        _createdAtEpochMsMeta,
        createdAtEpochMs.isAcceptableOrUnknown(
          data['created_at_epoch_ms']!,
          _createdAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      createdAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_epoch_ms'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final String? colorHex;
  final int createdAtEpochMs;
  const Tag({
    required this.id,
    required this.name,
    this.colorHex,
    required this.createdAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      createdAtEpochMs: Value(createdAtEpochMs),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      createdAtEpochMs: serializer.fromJson<int>(json['createdAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String?>(colorHex),
      'createdAtEpochMs': serializer.toJson<int>(createdAtEpochMs),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    Value<String?> colorHex = const Value.absent(),
    int? createdAtEpochMs,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      createdAtEpochMs: data.createdAtEpochMs.present
          ? data.createdAtEpochMs.value
          : this.createdAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAtEpochMs: $createdAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, createdAtEpochMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.createdAtEpochMs == this.createdAtEpochMs);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> colorHex;
  final Value<int> createdAtEpochMs;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.createdAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.colorHex = const Value.absent(),
    required int createdAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtEpochMs = Value(createdAtEpochMs);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<int>? createdAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (createdAtEpochMs != null) 'created_at_epoch_ms': createdAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? colorHex,
    Value<int>? createdAtEpochMs,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (createdAtEpochMs.present) {
      map['created_at_epoch_ms'] = Variable<int>(createdAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAtEpochMs: $createdAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themePreferenceMeta = const VerificationMeta(
    'themePreference',
  );
  @override
  late final GeneratedColumn<String> themePreference = GeneratedColumn<String>(
    'theme_preference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortModeMeta = const VerificationMeta(
    'sortMode',
  );
  @override
  late final GeneratedColumn<String> sortMode = GeneratedColumn<String>(
    'sort_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showCompletedInInboxMeta =
      const VerificationMeta('showCompletedInInbox');
  @override
  late final GeneratedColumn<bool> showCompletedInInbox = GeneratedColumn<bool>(
    'show_completed_in_inbox',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_completed_in_inbox" IN (0, 1))',
    ),
  );
  static const VerificationMeta _compactModeMeta = const VerificationMeta(
    'compactMode',
  );
  @override
  late final GeneratedColumn<bool> compactMode = GeneratedColumn<bool>(
    'compact_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("compact_mode" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themePreference,
    sortMode,
    showCompletedInInbox,
    compactMode,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_preference')) {
      context.handle(
        _themePreferenceMeta,
        themePreference.isAcceptableOrUnknown(
          data['theme_preference']!,
          _themePreferenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_themePreferenceMeta);
    }
    if (data.containsKey('sort_mode')) {
      context.handle(
        _sortModeMeta,
        sortMode.isAcceptableOrUnknown(data['sort_mode']!, _sortModeMeta),
      );
    } else if (isInserting) {
      context.missing(_sortModeMeta);
    }
    if (data.containsKey('show_completed_in_inbox')) {
      context.handle(
        _showCompletedInInboxMeta,
        showCompletedInInbox.isAcceptableOrUnknown(
          data['show_completed_in_inbox']!,
          _showCompletedInInboxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_showCompletedInInboxMeta);
    }
    if (data.containsKey('compact_mode')) {
      context.handle(
        _compactModeMeta,
        compactMode.isAcceptableOrUnknown(
          data['compact_mode']!,
          _compactModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compactModeMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themePreference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_preference'],
      )!,
      sortMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_mode'],
      )!,
      showCompletedInInbox: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_completed_in_inbox'],
      )!,
      compactMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}compact_mode'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String themePreference;
  final String sortMode;
  final bool showCompletedInInbox;
  final bool compactMode;
  final int updatedAtEpochMs;
  const AppSetting({
    required this.id,
    required this.themePreference,
    required this.sortMode,
    required this.showCompletedInInbox,
    required this.compactMode,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_preference'] = Variable<String>(themePreference);
    map['sort_mode'] = Variable<String>(sortMode);
    map['show_completed_in_inbox'] = Variable<bool>(showCompletedInInbox);
    map['compact_mode'] = Variable<bool>(compactMode);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      themePreference: Value(themePreference),
      sortMode: Value(sortMode),
      showCompletedInInbox: Value(showCompletedInInbox),
      compactMode: Value(compactMode),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      themePreference: serializer.fromJson<String>(json['themePreference']),
      sortMode: serializer.fromJson<String>(json['sortMode']),
      showCompletedInInbox: serializer.fromJson<bool>(
        json['showCompletedInInbox'],
      ),
      compactMode: serializer.fromJson<bool>(json['compactMode']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themePreference': serializer.toJson<String>(themePreference),
      'sortMode': serializer.toJson<String>(sortMode),
      'showCompletedInInbox': serializer.toJson<bool>(showCompletedInInbox),
      'compactMode': serializer.toJson<bool>(compactMode),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  AppSetting copyWith({
    int? id,
    String? themePreference,
    String? sortMode,
    bool? showCompletedInInbox,
    bool? compactMode,
    int? updatedAtEpochMs,
  }) => AppSetting(
    id: id ?? this.id,
    themePreference: themePreference ?? this.themePreference,
    sortMode: sortMode ?? this.sortMode,
    showCompletedInInbox: showCompletedInInbox ?? this.showCompletedInInbox,
    compactMode: compactMode ?? this.compactMode,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      themePreference: data.themePreference.present
          ? data.themePreference.value
          : this.themePreference,
      sortMode: data.sortMode.present ? data.sortMode.value : this.sortMode,
      showCompletedInInbox: data.showCompletedInInbox.present
          ? data.showCompletedInInbox.value
          : this.showCompletedInInbox,
      compactMode: data.compactMode.present
          ? data.compactMode.value
          : this.compactMode,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('themePreference: $themePreference, ')
          ..write('sortMode: $sortMode, ')
          ..write('showCompletedInInbox: $showCompletedInInbox, ')
          ..write('compactMode: $compactMode, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themePreference,
    sortMode,
    showCompletedInInbox,
    compactMode,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.themePreference == this.themePreference &&
          other.sortMode == this.sortMode &&
          other.showCompletedInInbox == this.showCompletedInInbox &&
          other.compactMode == this.compactMode &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> themePreference;
  final Value<String> sortMode;
  final Value<bool> showCompletedInInbox;
  final Value<bool> compactMode;
  final Value<int> updatedAtEpochMs;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.themePreference = const Value.absent(),
    this.sortMode = const Value.absent(),
    this.showCompletedInInbox = const Value.absent(),
    this.compactMode = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String themePreference,
    required String sortMode,
    required bool showCompletedInInbox,
    required bool compactMode,
    required int updatedAtEpochMs,
  }) : themePreference = Value(themePreference),
       sortMode = Value(sortMode),
       showCompletedInInbox = Value(showCompletedInInbox),
       compactMode = Value(compactMode),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? themePreference,
    Expression<String>? sortMode,
    Expression<bool>? showCompletedInInbox,
    Expression<bool>? compactMode,
    Expression<int>? updatedAtEpochMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themePreference != null) 'theme_preference': themePreference,
      if (sortMode != null) 'sort_mode': sortMode,
      if (showCompletedInInbox != null)
        'show_completed_in_inbox': showCompletedInInbox,
      if (compactMode != null) 'compact_mode': compactMode,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? themePreference,
    Value<String>? sortMode,
    Value<bool>? showCompletedInInbox,
    Value<bool>? compactMode,
    Value<int>? updatedAtEpochMs,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      themePreference: themePreference ?? this.themePreference,
      sortMode: sortMode ?? this.sortMode,
      showCompletedInInbox: showCompletedInInbox ?? this.showCompletedInInbox,
      compactMode: compactMode ?? this.compactMode,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themePreference.present) {
      map['theme_preference'] = Variable<String>(themePreference.value);
    }
    if (sortMode.present) {
      map['sort_mode'] = Variable<String>(sortMode.value);
    }
    if (showCompletedInInbox.present) {
      map['show_completed_in_inbox'] = Variable<bool>(
        showCompletedInInbox.value,
      );
    }
    if (compactMode.present) {
      map['compact_mode'] = Variable<bool>(compactMode.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('themePreference: $themePreference, ')
          ..write('sortMode: $sortMode, ')
          ..write('showCompletedInInbox: $showCompletedInInbox, ')
          ..write('compactMode: $compactMode, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$CockpitDemoDatabase extends GeneratedDatabase {
  _$CockpitDemoDatabase(QueryExecutor e) : super(e);
  $CockpitDemoDatabaseManager get managers => $CockpitDemoDatabaseManager(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tasks,
    tags,
    appSettings,
  ];
}

typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String> notes,
      Value<int> priority,
      Value<int?> dueAtEpochMs,
      Value<bool> isCompleted,
      Value<int?> completedAtEpochMs,
      Value<int?> deletedAtEpochMs,
      required int displayOrder,
      Value<String> tagIdsJson,
      required int createdAtEpochMs,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> notes,
      Value<int> priority,
      Value<int?> dueAtEpochMs,
      Value<bool> isCompleted,
      Value<int?> completedAtEpochMs,
      Value<int?> deletedAtEpochMs,
      Value<int> displayOrder,
      Value<String> tagIdsJson,
      Value<int> createdAtEpochMs,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$TasksTableFilterComposer
    extends Composer<_$CockpitDemoDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAtEpochMs => $composableBuilder(
    column: $table.dueAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtEpochMs => $composableBuilder(
    column: $table.deletedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagIdsJson => $composableBuilder(
    column: $table.tagIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TasksTableOrderingComposer
    extends Composer<_$CockpitDemoDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAtEpochMs => $composableBuilder(
    column: $table.dueAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtEpochMs => $composableBuilder(
    column: $table.deletedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagIdsJson => $composableBuilder(
    column: $table.tagIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TasksTableAnnotationComposer
    extends Composer<_$CockpitDemoDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get dueAtEpochMs => $composableBuilder(
    column: $table.dueAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtEpochMs => $composableBuilder(
    column: $table.completedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtEpochMs => $composableBuilder(
    column: $table.deletedAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagIdsJson => $composableBuilder(
    column: $table.tagIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$CockpitDemoDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, BaseReferences<_$CockpitDemoDatabase, $TasksTable, Task>),
          Task,
          PrefetchHooks Function()
        > {
  $$TasksTableTableManager(_$CockpitDemoDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> dueAtEpochMs = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int?> deletedAtEpochMs = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<String> tagIdsJson = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                notes: notes,
                priority: priority,
                dueAtEpochMs: dueAtEpochMs,
                isCompleted: isCompleted,
                completedAtEpochMs: completedAtEpochMs,
                deletedAtEpochMs: deletedAtEpochMs,
                displayOrder: displayOrder,
                tagIdsJson: tagIdsJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> notes = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> dueAtEpochMs = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> completedAtEpochMs = const Value.absent(),
                Value<int?> deletedAtEpochMs = const Value.absent(),
                required int displayOrder,
                Value<String> tagIdsJson = const Value.absent(),
                required int createdAtEpochMs,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                priority: priority,
                dueAtEpochMs: dueAtEpochMs,
                isCompleted: isCompleted,
                completedAtEpochMs: completedAtEpochMs,
                deletedAtEpochMs: deletedAtEpochMs,
                displayOrder: displayOrder,
                tagIdsJson: tagIdsJson,
                createdAtEpochMs: createdAtEpochMs,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$CockpitDemoDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, BaseReferences<_$CockpitDemoDatabase, $TasksTable, Task>),
      Task,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<String?> colorHex,
      required int createdAtEpochMs,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> colorHex,
      Value<int> createdAtEpochMs,
      Value<int> rowid,
    });

class $$TagsTableFilterComposer
    extends Composer<_$CockpitDemoDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagsTableOrderingComposer
    extends Composer<_$CockpitDemoDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$CockpitDemoDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<int> get createdAtEpochMs => $composableBuilder(
    column: $table.createdAtEpochMs,
    builder: (column) => column,
  );
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$CockpitDemoDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, BaseReferences<_$CockpitDemoDatabase, $TagsTable, Tag>),
          Tag,
          PrefetchHooks Function()
        > {
  $$TagsTableTableManager(_$CockpitDemoDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<int> createdAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> colorHex = const Value.absent(),
                required int createdAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                createdAtEpochMs: createdAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$CockpitDemoDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, BaseReferences<_$CockpitDemoDatabase, $TagsTable, Tag>),
      Tag,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      required String themePreference,
      required String sortMode,
      required bool showCompletedInInbox,
      required bool compactMode,
      required int updatedAtEpochMs,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> themePreference,
      Value<String> sortMode,
      Value<bool> showCompletedInInbox,
      Value<bool> compactMode,
      Value<int> updatedAtEpochMs,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$CockpitDemoDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themePreference => $composableBuilder(
    column: $table.themePreference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortMode => $composableBuilder(
    column: $table.sortMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showCompletedInInbox => $composableBuilder(
    column: $table.showCompletedInInbox,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get compactMode => $composableBuilder(
    column: $table.compactMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$CockpitDemoDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themePreference => $composableBuilder(
    column: $table.themePreference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortMode => $composableBuilder(
    column: $table.sortMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showCompletedInInbox => $composableBuilder(
    column: $table.showCompletedInInbox,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get compactMode => $composableBuilder(
    column: $table.compactMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$CockpitDemoDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themePreference => $composableBuilder(
    column: $table.themePreference,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sortMode =>
      $composableBuilder(column: $table.sortMode, builder: (column) => column);

  GeneratedColumn<bool> get showCompletedInInbox => $composableBuilder(
    column: $table.showCompletedInInbox,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get compactMode => $composableBuilder(
    column: $table.compactMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$CockpitDemoDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<
              _$CockpitDemoDatabase,
              $AppSettingsTable,
              AppSetting
            >,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(
    _$CockpitDemoDatabase db,
    $AppSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> themePreference = const Value.absent(),
                Value<String> sortMode = const Value.absent(),
                Value<bool> showCompletedInInbox = const Value.absent(),
                Value<bool> compactMode = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                themePreference: themePreference,
                sortMode: sortMode,
                showCompletedInInbox: showCompletedInInbox,
                compactMode: compactMode,
                updatedAtEpochMs: updatedAtEpochMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String themePreference,
                required String sortMode,
                required bool showCompletedInInbox,
                required bool compactMode,
                required int updatedAtEpochMs,
              }) => AppSettingsCompanion.insert(
                id: id,
                themePreference: themePreference,
                sortMode: sortMode,
                showCompletedInInbox: showCompletedInInbox,
                compactMode: compactMode,
                updatedAtEpochMs: updatedAtEpochMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$CockpitDemoDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$CockpitDemoDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $CockpitDemoDatabaseManager {
  final _$CockpitDemoDatabase _db;
  $CockpitDemoDatabaseManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
