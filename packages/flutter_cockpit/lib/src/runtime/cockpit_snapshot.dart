import 'package:collection/collection.dart';

import '../control/cockpit_command_type.dart';
import '../model/cockpit_artifact_ref.dart';
import '../network/cockpit_network_snapshot.dart';
import 'cockpit_accessibility_summary.dart';
import 'cockpit_rebuild_models.dart';
import 'cockpit_snapshot_options.dart';
import 'cockpit_runtime_snapshot.dart';

enum CockpitDiagnosticCategory {
  basic('basic'),
  layout('layout'),
  spacing('spacing'),
  appearance('appearance'),
  typography('typography'),
  other('other');

  const CockpitDiagnosticCategory(this.jsonValue);

  final String jsonValue;

  static CockpitDiagnosticCategory fromJson(Object? json) {
    return values.firstWhere(
      (category) => category.jsonValue == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported diagnostic category.',
      ),
    );
  }
}

final class CockpitDiagnosticProperty {
  const CockpitDiagnosticProperty({
    required this.name,
    required this.value,
    required this.category,
  });

  final String name;
  final String value;
  final CockpitDiagnosticCategory category;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'value': value,
    'category': category.jsonValue,
  };

  factory CockpitDiagnosticProperty.fromJson(Map<String, Object?> json) {
    return CockpitDiagnosticProperty(
      name: json['name']! as String,
      value: json['value']! as String,
      category: CockpitDiagnosticCategory.fromJson(json['category']),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitDiagnosticProperty &&
            other.name == name &&
            other.value == value &&
            other.category == category;
  }

  @override
  int get hashCode => Object.hash(name, value, category);
}

final class CockpitSnapshotLayout {
  const CockpitSnapshotLayout({
    required this.width,
    required this.height,
    required this.dx,
    required this.dy,
    this.constraintsSummary,
  });

  final double width;
  final double height;
  final double dx;
  final double dy;
  final String? constraintsSummary;

  Map<String, Object?> toJson() => <String, Object?>{
    'width': width,
    'height': height,
    'dx': dx,
    'dy': dy,
    if (constraintsSummary != null) 'constraintsSummary': constraintsSummary,
  };

  factory CockpitSnapshotLayout.fromJson(Map<String, Object?> json) {
    return CockpitSnapshotLayout(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
      constraintsSummary: json['constraintsSummary'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotLayout &&
            other.width == width &&
            other.height == height &&
            other.dx == dx &&
            other.dy == dy &&
            other.constraintsSummary == constraintsSummary;
  }

  @override
  int get hashCode => Object.hash(width, height, dx, dy, constraintsSummary);
}

final class CockpitSnapshotContent {
  const CockpitSnapshotContent({this.displayLabel, this.textPreview});

  final String? displayLabel;
  final String? textPreview;

  Map<String, Object?> toJson() => <String, Object?>{
    if (displayLabel != null) 'displayLabel': displayLabel,
    if (textPreview != null) 'textPreview': textPreview,
  };

  factory CockpitSnapshotContent.fromJson(Map<String, Object?> json) {
    return CockpitSnapshotContent(
      displayLabel: json['displayLabel'] as String?,
      textPreview: json['textPreview'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotContent &&
            other.displayLabel == displayLabel &&
            other.textPreview == textPreview;
  }

  @override
  int get hashCode => Object.hash(displayLabel, textPreview);
}

final class CockpitSnapshotStyle {
  const CockpitSnapshotStyle({
    this.textColor,
    this.backgroundColor,
    this.fontSize,
    this.fontWeight,
    this.borderSummary,
    this.shadowSummary,
  });

  final String? textColor;
  final String? backgroundColor;
  final double? fontSize;
  final String? fontWeight;
  final String? borderSummary;
  final String? shadowSummary;

  Map<String, Object?> toJson() => <String, Object?>{
    if (textColor != null) 'textColor': textColor,
    if (backgroundColor != null) 'backgroundColor': backgroundColor,
    if (fontSize != null) 'fontSize': fontSize,
    if (fontWeight != null) 'fontWeight': fontWeight,
    if (borderSummary != null) 'borderSummary': borderSummary,
    if (shadowSummary != null) 'shadowSummary': shadowSummary,
  };

  factory CockpitSnapshotStyle.fromJson(Map<String, Object?> json) {
    return CockpitSnapshotStyle(
      textColor: json['textColor'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontWeight: json['fontWeight'] as String?,
      borderSummary: json['borderSummary'] as String?,
      shadowSummary: json['shadowSummary'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotStyle &&
            other.textColor == textColor &&
            other.backgroundColor == backgroundColor &&
            other.fontSize == fontSize &&
            other.fontWeight == fontWeight &&
            other.borderSummary == borderSummary &&
            other.shadowSummary == shadowSummary;
  }

  @override
  int get hashCode => Object.hash(
    textColor,
    backgroundColor,
    fontSize,
    fontWeight,
    borderSummary,
    shadowSummary,
  );
}

final class CockpitSnapshotAncestor {
  const CockpitSnapshotAncestor({
    required this.typeName,
    this.cockpitId,
    this.semanticId,
    this.keyValue,
    this.textPreview,
    this.tooltip,
    this.routeName,
    this.path,
  });

  final String typeName;
  final String? cockpitId;
  final String? semanticId;
  final String? keyValue;
  final String? textPreview;
  final String? tooltip;
  final String? routeName;
  final String? path;

  Map<String, Object?> toJson() => <String, Object?>{
    'typeName': typeName,
    if (cockpitId != null) 'cockpitId': cockpitId,
    if (semanticId != null) 'semanticId': semanticId,
    if (keyValue != null) 'keyValue': keyValue,
    if (textPreview != null) 'textPreview': textPreview,
    if (tooltip != null) 'tooltip': tooltip,
    if (routeName != null) 'routeName': routeName,
    if (path != null) 'path': path,
  };

  factory CockpitSnapshotAncestor.fromJson(Map<String, Object?> json) {
    return CockpitSnapshotAncestor(
      typeName: json['typeName']! as String,
      cockpitId: json['cockpitId'] as String?,
      semanticId: json['semanticId'] as String?,
      keyValue: json['keyValue'] as String?,
      textPreview: json['textPreview'] as String?,
      tooltip: json['tooltip'] as String?,
      routeName: json['routeName'] as String?,
      path: json['path'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotAncestor &&
            other.typeName == typeName &&
            other.cockpitId == cockpitId &&
            other.semanticId == semanticId &&
            other.keyValue == keyValue &&
            other.textPreview == textPreview &&
            other.tooltip == tooltip &&
            other.routeName == routeName &&
            other.path == path;
  }

  @override
  int get hashCode => Object.hash(
    typeName,
    cockpitId,
    semanticId,
    keyValue,
    textPreview,
    tooltip,
    routeName,
    path,
  );
}

final class CockpitSnapshotSummary {
  const CockpitSnapshotSummary({
    required this.visibleTargetCount,
    required this.targetsWithCockpitIdCount,
    required this.targetsWithTextCount,
    required this.styleDetailsIncluded,
    required this.diagnosticPropertiesIncluded,
    required this.ancestorSummariesIncluded,
    required this.rebuildSummaryIncluded,
    required this.accessibilitySummaryIncluded,
  });

  final int visibleTargetCount;
  final int targetsWithCockpitIdCount;
  final int targetsWithTextCount;
  final bool styleDetailsIncluded;
  final bool diagnosticPropertiesIncluded;
  final bool ancestorSummariesIncluded;
  final bool rebuildSummaryIncluded;
  final bool accessibilitySummaryIncluded;

  Map<String, Object?> toJson() => <String, Object?>{
    'visibleTargetCount': visibleTargetCount,
    'targetsWithCockpitIdCount': targetsWithCockpitIdCount,
    'targetsWithTextCount': targetsWithTextCount,
    'styleDetailsIncluded': styleDetailsIncluded,
    'diagnosticPropertiesIncluded': diagnosticPropertiesIncluded,
    'ancestorSummariesIncluded': ancestorSummariesIncluded,
    'rebuildSummaryIncluded': rebuildSummaryIncluded,
    'accessibilitySummaryIncluded': accessibilitySummaryIncluded,
  };

  factory CockpitSnapshotSummary.fromJson(Map<String, Object?> json) {
    return CockpitSnapshotSummary(
      visibleTargetCount: json['visibleTargetCount'] as int? ?? 0,
      targetsWithCockpitIdCount: json['targetsWithCockpitIdCount'] as int? ?? 0,
      targetsWithTextCount: json['targetsWithTextCount'] as int? ?? 0,
      styleDetailsIncluded: json['styleDetailsIncluded'] as bool? ?? false,
      diagnosticPropertiesIncluded:
          json['diagnosticPropertiesIncluded'] as bool? ?? false,
      ancestorSummariesIncluded:
          json['ancestorSummariesIncluded'] as bool? ?? false,
      rebuildSummaryIncluded: json['rebuildSummaryIncluded'] as bool? ?? false,
      accessibilitySummaryIncluded:
          json['accessibilitySummaryIncluded'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotSummary &&
            other.visibleTargetCount == visibleTargetCount &&
            other.targetsWithCockpitIdCount == targetsWithCockpitIdCount &&
            other.targetsWithTextCount == targetsWithTextCount &&
            other.styleDetailsIncluded == styleDetailsIncluded &&
            other.diagnosticPropertiesIncluded ==
                diagnosticPropertiesIncluded &&
            other.ancestorSummariesIncluded == ancestorSummariesIncluded &&
            other.rebuildSummaryIncluded == rebuildSummaryIncluded &&
            other.accessibilitySummaryIncluded == accessibilitySummaryIncluded;
  }

  @override
  int get hashCode => Object.hash(
    visibleTargetCount,
    targetsWithCockpitIdCount,
    targetsWithTextCount,
    styleDetailsIncluded,
    diagnosticPropertiesIncluded,
    ancestorSummariesIncluded,
    rebuildSummaryIncluded,
    accessibilitySummaryIncluded,
  );
}

final class CockpitSnapshotTarget {
  CockpitSnapshotTarget({
    required this.registrationId,
    this.cockpitId,
    this.semanticId,
    this.keyValue,
    this.text,
    this.tooltip,
    this.typeName,
    this.path,
    this.scrollablePath,
    this.scrollableKeyValue,
    this.scrollableTypeName,
    required this.routeName,
    List<CockpitCommandType> supportedCommands = const <CockpitCommandType>[],
    this.layout,
    this.content,
    this.style,
    List<CockpitSnapshotAncestor> ancestors = const <CockpitSnapshotAncestor>[],
    List<CockpitDiagnosticProperty> diagnosticProperties =
        const <CockpitDiagnosticProperty>[],
  }) : supportedCommands = List.unmodifiable(supportedCommands),
       ancestors = List.unmodifiable(ancestors),
       diagnosticProperties = List.unmodifiable(diagnosticProperties);

  final String registrationId;
  final String? cockpitId;
  final String? semanticId;
  final String? keyValue;
  final String? text;
  final String? tooltip;
  final String? typeName;
  final String? path;
  final String? scrollablePath;
  final String? scrollableKeyValue;
  final String? scrollableTypeName;
  final String routeName;
  final List<CockpitCommandType> supportedCommands;
  final CockpitSnapshotLayout? layout;
  final CockpitSnapshotContent? content;
  final CockpitSnapshotStyle? style;
  final List<CockpitSnapshotAncestor> ancestors;
  final List<CockpitDiagnosticProperty> diagnosticProperties;

  static const ListEquality<CockpitCommandType> _commandListEquality =
      ListEquality<CockpitCommandType>();
  static const ListEquality<CockpitSnapshotAncestor> _ancestorListEquality =
      ListEquality<CockpitSnapshotAncestor>();
  static const ListEquality<CockpitDiagnosticProperty> _propertyListEquality =
      ListEquality<CockpitDiagnosticProperty>();

  String? get displayLabel =>
      cockpitId ?? semanticId ?? text ?? tooltip ?? keyValue ?? typeName;

  Map<String, Object?> toJson() => {
    'registrationId': registrationId,
    if (cockpitId != null) 'cockpitId': cockpitId,
    if (semanticId != null) 'semanticId': semanticId,
    if (keyValue != null) 'keyValue': keyValue,
    if (text != null) 'text': text,
    if (tooltip != null) 'tooltip': tooltip,
    if (typeName != null) 'typeName': typeName,
    if (path != null) 'path': path,
    if (scrollablePath != null) 'scrollablePath': scrollablePath,
    if (scrollableKeyValue != null) 'scrollableKeyValue': scrollableKeyValue,
    if (scrollableTypeName != null) 'scrollableTypeName': scrollableTypeName,
    'routeName': routeName,
    'supportedCommands': supportedCommands
        .map((command) => command.name)
        .toList(),
    if (layout != null) 'layout': layout!.toJson(),
    if (content != null) 'content': content!.toJson(),
    if (style != null) 'style': style!.toJson(),
    'ancestors': ancestors.map((ancestor) => ancestor.toJson()).toList(),
    'diagnosticProperties': diagnosticProperties
        .map((property) => property.toJson())
        .toList(),
  };

  factory CockpitSnapshotTarget.fromJson(Map<String, Object?> json) {
    final layoutJson = json['layout'] as Map<Object?, Object?>?;
    final contentJson = json['content'] as Map<Object?, Object?>?;
    final styleJson = json['style'] as Map<Object?, Object?>?;
    return CockpitSnapshotTarget(
      registrationId: json['registrationId']! as String,
      cockpitId: json['cockpitId'] as String?,
      semanticId: json['semanticId'] as String?,
      keyValue: json['keyValue'] as String?,
      text: json['text'] as String?,
      tooltip: json['tooltip'] as String?,
      typeName: json['typeName'] as String?,
      path: json['path'] as String?,
      scrollablePath: json['scrollablePath'] as String?,
      scrollableKeyValue: json['scrollableKeyValue'] as String?,
      scrollableTypeName: json['scrollableTypeName'] as String?,
      routeName: json['routeName']! as String,
      supportedCommands:
          (json['supportedCommands'] as List<Object?>? ?? const <Object?>[])
              .map(CockpitCommandType.fromJson)
              .toList(growable: false),
      layout: layoutJson == null
          ? null
          : CockpitSnapshotLayout.fromJson(
              Map<String, Object?>.from(layoutJson),
            ),
      content: contentJson == null
          ? null
          : CockpitSnapshotContent.fromJson(
              Map<String, Object?>.from(contentJson),
            ),
      style: styleJson == null
          ? null
          : CockpitSnapshotStyle.fromJson(Map<String, Object?>.from(styleJson)),
      ancestors: (json['ancestors'] as List<Object?>? ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (item) => CockpitSnapshotAncestor.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .toList(growable: false),
      diagnosticProperties:
          (json['diagnosticProperties'] as List<Object?>? ?? const <Object?>[])
              .cast<Map<Object?, Object?>>()
              .map(
                (item) => CockpitDiagnosticProperty.fromJson(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshotTarget &&
            other.registrationId == registrationId &&
            other.cockpitId == cockpitId &&
            other.semanticId == semanticId &&
            other.keyValue == keyValue &&
            other.text == text &&
            other.tooltip == tooltip &&
            other.typeName == typeName &&
            other.path == path &&
            other.scrollablePath == scrollablePath &&
            other.scrollableKeyValue == scrollableKeyValue &&
            other.scrollableTypeName == scrollableTypeName &&
            other.routeName == routeName &&
            other.layout == layout &&
            other.content == content &&
            other.style == style &&
            _ancestorListEquality.equals(other.ancestors, ancestors) &&
            _propertyListEquality.equals(
              other.diagnosticProperties,
              diagnosticProperties,
            ) &&
            _commandListEquality.equals(
              other.supportedCommands,
              supportedCommands,
            );
  }

  @override
  int get hashCode => Object.hash(
    registrationId,
    cockpitId,
    semanticId,
    keyValue,
    text,
    tooltip,
    typeName,
    path,
    scrollablePath,
    scrollableKeyValue,
    scrollableTypeName,
    routeName,
    layout,
    content,
    style,
    _ancestorListEquality.hash(ancestors),
    _propertyListEquality.hash(diagnosticProperties),
    _commandListEquality.hash(supportedCommands),
  );
}

final class CockpitSnapshot {
  CockpitSnapshot({
    required this.routeName,
    List<CockpitSnapshotTarget> visibleTargets =
        const <CockpitSnapshotTarget>[],
    this.diagnosticLevel = CockpitSnapshotProfile.live,
    this.truncated = false,
    this.diagnosticsArtifactRef,
    this.summary,
    this.network,
    this.runtime,
    this.rebuild,
    this.accessibility,
  }) : visibleTargets = List.unmodifiable(visibleTargets);

  final String? routeName;
  final List<CockpitSnapshotTarget> visibleTargets;
  final CockpitSnapshotProfile diagnosticLevel;
  final bool truncated;
  final CockpitArtifactRef? diagnosticsArtifactRef;
  final CockpitSnapshotSummary? summary;
  final CockpitNetworkSnapshot? network;
  final CockpitRuntimeSnapshot? runtime;
  final CockpitRebuildSnapshot? rebuild;
  final CockpitAccessibilitySummary? accessibility;

  static const ListEquality<CockpitSnapshotTarget> _targetListEquality =
      ListEquality<CockpitSnapshotTarget>();

  Map<String, Object?> toJson() => {
    if (routeName != null) 'routeName': routeName,
    'visibleTargets': visibleTargets.map((target) => target.toJson()).toList(),
    'diagnosticLevel': diagnosticLevel.jsonValue,
    'truncated': truncated,
    if (diagnosticsArtifactRef != null)
      'diagnosticsArtifactRef': diagnosticsArtifactRef!.toJson(),
    if (summary != null) 'summary': summary!.toJson(),
    if (network != null) 'network': network!.toJson(),
    if (runtime != null) 'runtime': runtime!.toJson(),
    if (rebuild != null) 'rebuild': rebuild!.toJson(),
    if (accessibility != null) 'accessibility': accessibility!.toJson(),
  };

  factory CockpitSnapshot.fromJson(Map<String, Object?> json) {
    final diagnosticsArtifactJson =
        json['diagnosticsArtifactRef'] as Map<Object?, Object?>?;
    final summaryJson = json['summary'] as Map<Object?, Object?>?;
    final networkJson = json['network'] as Map<Object?, Object?>?;
    final runtimeJson = json['runtime'] as Map<Object?, Object?>?;
    final rebuildJson = json['rebuild'] as Map<Object?, Object?>?;
    final accessibilityJson = json['accessibility'] as Map<Object?, Object?>?;
    return CockpitSnapshot(
      routeName: json['routeName'] as String?,
      visibleTargets:
          (json['visibleTargets'] as List<Object?>? ?? const <Object?>[])
              .cast<Map<Object?, Object?>>()
              .map(
                (item) => CockpitSnapshotTarget.fromJson(
                  Map<String, Object?>.from(item),
                ),
              )
              .toList(growable: false),
      diagnosticLevel: json['diagnosticLevel'] == null
          ? CockpitSnapshotProfile.live
          : CockpitSnapshotProfile.fromJson(json['diagnosticLevel']),
      truncated: json['truncated'] as bool? ?? false,
      diagnosticsArtifactRef: diagnosticsArtifactJson == null
          ? null
          : CockpitArtifactRef.fromJson(
              Map<String, Object?>.from(diagnosticsArtifactJson),
            ),
      summary: summaryJson == null
          ? null
          : CockpitSnapshotSummary.fromJson(
              Map<String, Object?>.from(summaryJson),
            ),
      network: networkJson == null
          ? null
          : CockpitNetworkSnapshot.fromJson(
              Map<String, Object?>.from(networkJson),
            ),
      runtime: runtimeJson == null
          ? null
          : CockpitRuntimeSnapshot.fromJson(
              Map<String, Object?>.from(runtimeJson),
            ),
      rebuild: rebuildJson == null
          ? null
          : CockpitRebuildSnapshot.fromJson(
              Map<String, Object?>.from(rebuildJson),
            ),
      accessibility: accessibilityJson == null
          ? null
          : CockpitAccessibilitySummary.fromJson(
              Map<String, Object?>.from(accessibilityJson),
            ),
    );
  }

  CockpitSnapshot copyWith({
    String? routeName,
    List<CockpitSnapshotTarget>? visibleTargets,
    CockpitSnapshotProfile? diagnosticLevel,
    bool? truncated,
    CockpitArtifactRef? diagnosticsArtifactRef,
    CockpitSnapshotSummary? summary,
    CockpitNetworkSnapshot? network,
    CockpitRuntimeSnapshot? runtime,
    CockpitRebuildSnapshot? rebuild,
    CockpitAccessibilitySummary? accessibility,
  }) {
    return CockpitSnapshot(
      routeName: routeName ?? this.routeName,
      visibleTargets: visibleTargets ?? this.visibleTargets,
      diagnosticLevel: diagnosticLevel ?? this.diagnosticLevel,
      truncated: truncated ?? this.truncated,
      diagnosticsArtifactRef:
          diagnosticsArtifactRef ?? this.diagnosticsArtifactRef,
      summary: summary ?? this.summary,
      network: network ?? this.network,
      runtime: runtime ?? this.runtime,
      rebuild: rebuild ?? this.rebuild,
      accessibility: accessibility ?? this.accessibility,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitSnapshot &&
            other.routeName == routeName &&
            other.diagnosticLevel == diagnosticLevel &&
            other.truncated == truncated &&
            other.diagnosticsArtifactRef == diagnosticsArtifactRef &&
            other.summary == summary &&
            other.network == network &&
            other.runtime == runtime &&
            other.rebuild == rebuild &&
            other.accessibility == accessibility &&
            _targetListEquality.equals(other.visibleTargets, visibleTargets);
  }

  @override
  int get hashCode => Object.hash(
    routeName,
    diagnosticLevel,
    truncated,
    diagnosticsArtifactRef,
    summary,
    network,
    runtime,
    rebuild,
    accessibility,
    _targetListEquality.hash(visibleTargets),
  );
}
