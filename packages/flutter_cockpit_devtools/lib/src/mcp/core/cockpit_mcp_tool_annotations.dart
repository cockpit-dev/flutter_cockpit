final class CockpitMcpToolAnnotations {
  const CockpitMcpToolAnnotations({
    required this.readOnly,
    required this.destructive,
    required this.idempotent,
    required this.longRunning,
    required this.requiresSession,
    required this.producesBundleEvidence,
  });

  static const defaults = CockpitMcpToolAnnotations(
    readOnly: false,
    destructive: false,
    idempotent: false,
    longRunning: false,
    requiresSession: false,
    producesBundleEvidence: false,
  );

  final bool readOnly;
  final bool destructive;
  final bool idempotent;
  final bool longRunning;
  final bool requiresSession;
  final bool producesBundleEvidence;

  Map<String, Object?> toJson() => <String, Object?>{
        'readOnly': readOnly,
        'destructive': destructive,
        'idempotent': idempotent,
        'longRunning': longRunning,
        'requiresSession': requiresSession,
        'producesBundleEvidence': producesBundleEvidence,
      };
}
