import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitTestSecretResolver {
  Future<String> resolve(String reference);
}

final class CockpitTestSecretBindings {
  CockpitTestSecretBindings(Map<String, String> references)
    : _references = Map<String, String>.unmodifiable(references);

  final Map<String, String> _references;

  bool get isEmpty => _references.isEmpty;

  Future<String> resolve(
    CockpitTestSecretToken token,
    CockpitTestSecretResolver resolver,
  ) async {
    final reference = _references[token.value];
    if (reference == null) {
      throw CockpitTestSecretResolutionException(
        CockpitTestError(
          code: CockpitTestErrorCode.secretResolutionFailed,
          message: 'Secret token is not registered for this attempt.',
        ),
      );
    }
    try {
      return await resolver.resolve(reference);
    } catch (_) {
      throw CockpitTestSecretResolutionException(
        CockpitTestError(
          code: CockpitTestErrorCode.secretResolutionFailed,
          message: 'Secret provider failed to resolve a required value.',
        ),
      );
    }
  }
}

final class CockpitTestSecretResolutionException implements Exception {
  const CockpitTestSecretResolutionException(this.error);

  final CockpitTestError error;

  @override
  String toString() => 'CockpitTestSecretResolutionException: ${error.message}';
}

Future<CockpitTestAction> cockpitResolveTestActionSecrets({
  required CockpitTestAction action,
  required CockpitTestSecretBindings secretBindings,
  required CockpitTestSecretResolver resolver,
}) async {
  if (!action.containsSecret) {
    return action;
  }
  final values = <CockpitTestActionField, Object?>{};
  for (final entry in action.values.entries) {
    final value = entry.value;
    if (value is! CockpitTestSecretToken) {
      values[entry.key] = value;
      continue;
    }
    values[entry.key] = await secretBindings.resolve(value, resolver);
  }
  return action.copyWithValues(values);
}
