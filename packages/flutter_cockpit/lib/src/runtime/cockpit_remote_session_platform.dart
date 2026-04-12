import 'package:flutter/foundation.dart';

String resolveCockpitRemoteSessionPlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) {
    return 'web';
  }
  return switch (targetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.linux => 'linux',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
