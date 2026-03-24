final class CockpitEnvironment {
  const CockpitEnvironment({
    required this.platform,
    required this.flutterVersion,
    required this.dartVersion,
  });

  final String platform;
  final String flutterVersion;
  final String dartVersion;

  Map<String, Object?> toJson() => {
        'platform': platform,
        'flutterVersion': flutterVersion,
        'dartVersion': dartVersion,
      };

  factory CockpitEnvironment.fromJson(Map<String, Object?> json) {
    return CockpitEnvironment(
      platform: json['platform']! as String,
      flutterVersion: json['flutterVersion']! as String,
      dartVersion: json['dartVersion']! as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitEnvironment &&
            other.platform == platform &&
            other.flutterVersion == flutterVersion &&
            other.dartVersion == dartVersion;
  }

  @override
  int get hashCode => Object.hash(platform, flutterVersion, dartVersion);
}
