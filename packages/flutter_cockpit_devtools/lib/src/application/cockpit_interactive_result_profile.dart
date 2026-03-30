import 'dart:math' as math;

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_application_service_exception.dart';

enum CockpitInteractiveResultProfileName {
  compact('compact'),
  standard('standard'),
  inspect('inspect'),
  forensic('forensic');

  const CockpitInteractiveResultProfileName(this.jsonValue);

  final String jsonValue;

  static CockpitInteractiveResultProfileName fromJson(Object? value) {
    return values.firstWhere(
      (candidate) => candidate.jsonValue == value,
      orElse: () => throw _invalidProfile('Unsupported profile preset.', value),
    );
  }
}

enum CockpitInteractiveUiLevel {
  none('none'),
  summary('summary'),
  snapshot('snapshot');

  const CockpitInteractiveUiLevel(this.jsonValue);

  final String jsonValue;

  static CockpitInteractiveUiLevel fromJson(Object? value) {
    return values.firstWhere(
      (candidate) => candidate.jsonValue == value,
      orElse: () => throw _invalidProfile('Unsupported UI layer value.', value),
    );
  }
}

enum CockpitInteractiveDiagnosticsLevel {
  none('none'),
  failuresOnly('failures_only'),
  full('full');

  const CockpitInteractiveDiagnosticsLevel(this.jsonValue);

  final String jsonValue;

  static CockpitInteractiveDiagnosticsLevel fromJson(Object? value) {
    return values.firstWhere(
      (candidate) => candidate.jsonValue == value,
      orElse: () => throw _invalidProfile(
        'Unsupported diagnostics layer value.',
        value,
      ),
    );
  }
}

enum CockpitInteractiveArtifactLevel {
  none('none'),
  refs('refs'),
  metadata('metadata');

  const CockpitInteractiveArtifactLevel(this.jsonValue);

  final String jsonValue;

  static CockpitInteractiveArtifactLevel fromJson(Object? value) {
    return values.firstWhere(
      (candidate) => candidate.jsonValue == value,
      orElse: () => throw _invalidProfile(
        'Unsupported artifact layer value.',
        value,
      ),
    );
  }
}

final class CockpitInteractiveResultProfile {
  const CockpitInteractiveResultProfile({
    required this.name,
    required this.ui,
    required this.diagnostics,
    required this.artifacts,
    required this.includeDelta,
    required this.includeRuntimeSteps,
    required this.emitSnapshotRef,
    required this.snapshotProfile,
  });

  const CockpitInteractiveResultProfile.compact()
      : this(
          name: CockpitInteractiveResultProfileName.compact,
          ui: CockpitInteractiveUiLevel.none,
          diagnostics: CockpitInteractiveDiagnosticsLevel.none,
          artifacts: CockpitInteractiveArtifactLevel.none,
          includeDelta: false,
          includeRuntimeSteps: false,
          emitSnapshotRef: false,
          snapshotProfile: CockpitSnapshotProfile.live,
        );

  const CockpitInteractiveResultProfile.standard()
      : this(
          name: CockpitInteractiveResultProfileName.standard,
          ui: CockpitInteractiveUiLevel.summary,
          diagnostics: CockpitInteractiveDiagnosticsLevel.none,
          artifacts: CockpitInteractiveArtifactLevel.refs,
          includeDelta: false,
          includeRuntimeSteps: false,
          emitSnapshotRef: true,
          snapshotProfile: CockpitSnapshotProfile.baseline,
        );

  const CockpitInteractiveResultProfile.inspect()
      : this(
          name: CockpitInteractiveResultProfileName.inspect,
          ui: CockpitInteractiveUiLevel.summary,
          diagnostics: CockpitInteractiveDiagnosticsLevel.failuresOnly,
          artifacts: CockpitInteractiveArtifactLevel.metadata,
          includeDelta: true,
          includeRuntimeSteps: true,
          emitSnapshotRef: true,
          snapshotProfile: CockpitSnapshotProfile.investigate,
        );

  const CockpitInteractiveResultProfile.forensic()
      : this(
          name: CockpitInteractiveResultProfileName.forensic,
          ui: CockpitInteractiveUiLevel.snapshot,
          diagnostics: CockpitInteractiveDiagnosticsLevel.full,
          artifacts: CockpitInteractiveArtifactLevel.metadata,
          includeDelta: true,
          includeRuntimeSteps: true,
          emitSnapshotRef: true,
          snapshotProfile: CockpitSnapshotProfile.forensic,
        );

  final CockpitInteractiveResultProfileName name;
  final CockpitInteractiveUiLevel ui;
  final CockpitInteractiveDiagnosticsLevel diagnostics;
  final CockpitInteractiveArtifactLevel artifacts;
  final bool includeDelta;
  final bool includeRuntimeSteps;
  final bool emitSnapshotRef;
  final CockpitSnapshotProfile snapshotProfile;

  factory CockpitInteractiveResultProfile.fromJson(
    Map<String, Object?>? json, {
    CockpitInteractiveResultProfileName defaultProfile =
        CockpitInteractiveResultProfileName.standard,
  }) {
    if (json == null || json.isEmpty) {
      return preset(defaultProfile);
    }

    final base = preset(
      json.containsKey('profile')
          ? CockpitInteractiveResultProfileName.fromJson(json['profile'])
          : defaultProfile,
    );

    return CockpitInteractiveResultProfile(
      name: base.name,
      ui: _readAliasedValue(json, 'ui_level', 'ui') == null
          ? base.ui
          : CockpitInteractiveUiLevel.fromJson(
              _readAliasedValue(json, 'ui_level', 'ui'),
            ),
      diagnostics:
          _readAliasedValue(json, 'diagnostics_level', 'diagnostics') == null
              ? base.diagnostics
              : CockpitInteractiveDiagnosticsLevel.fromJson(
                  _readAliasedValue(
                    json,
                    'diagnostics_level',
                    'diagnostics',
                  ),
                ),
      artifacts: _readAliasedValue(json, 'artifact_level', 'artifacts') == null
          ? base.artifacts
          : CockpitInteractiveArtifactLevel.fromJson(
              _readAliasedValue(json, 'artifact_level', 'artifacts'),
            ),
      includeDelta: _readOptionalBool(
            json,
            'include_delta',
            'includeDelta',
          ) ??
          base.includeDelta,
      includeRuntimeSteps: _readOptionalBool(
            json,
            'include_runtime_steps',
            'includeRuntimeSteps',
          ) ??
          base.includeRuntimeSteps,
      emitSnapshotRef: _readOptionalBool(
            json,
            'emit_snapshot_ref',
            'emitSnapshotRef',
          ) ??
          base.emitSnapshotRef,
      snapshotProfile: _readAliasedValue(
                json,
                'snapshot_profile',
                'snapshotProfile',
              ) ==
              null
          ? base.snapshotProfile
          : CockpitSnapshotProfile.fromJson(
              _readAliasedValue(json, 'snapshot_profile', 'snapshotProfile'),
            ),
    );
  }

  static CockpitInteractiveResultProfile preset(
    CockpitInteractiveResultProfileName name,
  ) {
    return switch (name) {
      CockpitInteractiveResultProfileName.compact =>
        const CockpitInteractiveResultProfile.compact(),
      CockpitInteractiveResultProfileName.standard =>
        const CockpitInteractiveResultProfile.standard(),
      CockpitInteractiveResultProfileName.inspect =>
        const CockpitInteractiveResultProfile.inspect(),
      CockpitInteractiveResultProfileName.forensic =>
        const CockpitInteractiveResultProfile.forensic(),
    };
  }

  CockpitSnapshotOptions resolveSnapshotOptions([
    CockpitSnapshotOptions? override,
  ]) {
    final base = _defaultSnapshotOptions(snapshotProfile, diagnostics);
    if (override == null) {
      return base;
    }
    if (_snapshotRank(override.profile) >= _snapshotRank(base.profile)) {
      return override;
    }

    return override.copyWith(
      profile: base.profile,
      maxTargets: math.max(override.maxTargets, base.maxTargets),
      maxAncestorsPerTarget: math.max(
        override.maxAncestorsPerTarget,
        base.maxAncestorsPerTarget,
      ),
      maxPropertiesPerTarget: math.max(
        override.maxPropertiesPerTarget,
        base.maxPropertiesPerTarget,
      ),
      includeStyleDetails:
          override.includeStyleDetails || base.includeStyleDetails,
      includeDiagnosticProperties: override.includeDiagnosticProperties ||
          base.includeDiagnosticProperties,
      emitArtifactWhenLarge:
          override.emitArtifactWhenLarge || base.emitArtifactWhenLarge,
      includeRebuildActivity:
          override.includeRebuildActivity || base.includeRebuildActivity,
      maxRebuildEntries: math.max(
        override.maxRebuildEntries,
        base.maxRebuildEntries,
      ),
      includeNetworkActivity:
          override.includeNetworkActivity || base.includeNetworkActivity,
      maxNetworkEntries: math.max(
        override.maxNetworkEntries,
        base.maxNetworkEntries,
      ),
      networkQuery: CockpitNetworkQuery(
        method: override.networkQuery.method ?? base.networkQuery.method,
        uriContains:
            override.networkQuery.uriContains ?? base.networkQuery.uriContains,
        onlyFailures: override.networkQuery.onlyFailures ||
            base.networkQuery.onlyFailures,
        statusCodeAtLeast: override.networkQuery.statusCodeAtLeast ??
            base.networkQuery.statusCodeAtLeast,
      ),
      includeRuntimeActivity:
          override.includeRuntimeActivity || base.includeRuntimeActivity,
      maxRuntimeEntries: math.max(
        override.maxRuntimeEntries,
        base.maxRuntimeEntries,
      ),
      runtimeQuery: CockpitRuntimeQuery(
        onlyErrors:
            override.runtimeQuery.onlyErrors || base.runtimeQuery.onlyErrors,
        messageContains: override.runtimeQuery.messageContains ??
            base.runtimeQuery.messageContains,
      ),
      includeAccessibilitySummary: override.includeAccessibilitySummary ||
          base.includeAccessibilitySummary,
      maxAccessibilityEntries: math.max(
        override.maxAccessibilityEntries,
        base.maxAccessibilityEntries,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'profile': name.jsonValue,
        'ui': ui.jsonValue,
        'diagnostics': diagnostics.jsonValue,
        'artifacts': artifacts.jsonValue,
        'include_delta': includeDelta,
        'include_runtime_steps': includeRuntimeSteps,
        'emit_snapshot_ref': emitSnapshotRef,
        'snapshot_profile': snapshotProfile.jsonValue,
      };

  static Object? _readAliasedValue(
    Map<String, Object?> json,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    if (json.containsKey(snakeCaseKey)) {
      return json[snakeCaseKey];
    }
    return json[camelCaseKey];
  }

  static bool? _readOptionalBool(
    Map<String, Object?> json,
    String snakeCaseKey,
    String camelCaseKey,
  ) {
    final value = _readAliasedValue(json, snakeCaseKey, camelCaseKey);
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw _invalidProfile('Boolean override expected.', value);
  }

  static CockpitSnapshotOptions _defaultSnapshotOptions(
    CockpitSnapshotProfile snapshotProfile,
    CockpitInteractiveDiagnosticsLevel diagnostics,
  ) {
    var options = switch (snapshotProfile) {
      CockpitSnapshotProfile.live => const CockpitSnapshotOptions.live(),
      CockpitSnapshotProfile.baseline =>
        const CockpitSnapshotOptions.baseline(),
      CockpitSnapshotProfile.investigate =>
        const CockpitSnapshotOptions.investigate(),
      CockpitSnapshotProfile.forensic =>
        const CockpitSnapshotOptions.forensic(),
    };

    return switch (diagnostics) {
      CockpitInteractiveDiagnosticsLevel.none => options.copyWith(
          includeRebuildActivity: false,
          includeNetworkActivity: false,
          includeRuntimeActivity: false,
          includeAccessibilitySummary: false,
          networkQuery: const CockpitNetworkQuery(),
          runtimeQuery: const CockpitRuntimeQuery(),
        ),
      CockpitInteractiveDiagnosticsLevel.failuresOnly => options.copyWith(
          includeNetworkActivity: true,
          includeRuntimeActivity: true,
          includeRebuildActivity: true,
          includeAccessibilitySummary: true,
          networkQuery: CockpitNetworkQuery(
            method: options.networkQuery.method,
            uriContains: options.networkQuery.uriContains,
            onlyFailures: true,
            statusCodeAtLeast: options.networkQuery.statusCodeAtLeast,
          ),
          runtimeQuery: CockpitRuntimeQuery(
            onlyErrors: true,
            messageContains: options.runtimeQuery.messageContains,
          ),
        ),
      CockpitInteractiveDiagnosticsLevel.full => options.copyWith(
          includeNetworkActivity: true,
          includeRuntimeActivity: true,
          includeRebuildActivity: true,
          includeAccessibilitySummary: true,
          networkQuery: CockpitNetworkQuery(
            method: options.networkQuery.method,
            uriContains: options.networkQuery.uriContains,
            onlyFailures: false,
            statusCodeAtLeast: options.networkQuery.statusCodeAtLeast,
          ),
          runtimeQuery: CockpitRuntimeQuery(
            onlyErrors: false,
            messageContains: options.runtimeQuery.messageContains,
          ),
        ),
    };
  }

  static int _snapshotRank(CockpitSnapshotProfile profile) {
    return CockpitSnapshotProfile.values.indexOf(profile);
  }
}

CockpitApplicationServiceException _invalidProfile(
  String message,
  Object? value,
) {
  return CockpitApplicationServiceException(
    code: 'invalidInteractiveResultProfile',
    message: message,
    details: <String, Object?>{
      if (value != null) 'value': value.toString(),
    },
  );
}
