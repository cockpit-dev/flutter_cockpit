import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'src/cockpit_demo_app.dart';

void main() {
  const enableDebugDiagnostics = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_DEBUG_DIAGNOSTICS',
  );
  const enableTapFeedback = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_TAP_FEEDBACK',
  );

  runApp(
    CockpitDemoApp(
      configuration: FlutterCockpitConfiguration(
        initialRouteName: '/inbox',
        httpNetworkObserver: CockpitHttpNetworkObserverConfiguration(
          maxRetainedEntries: 80,
        ),
        diagnostics: CockpitDiagnosticsConfig(
          enableRebuildTracking: enableDebugDiagnostics,
          enableTapFeedback: enableTapFeedback,
        ),
        remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
          fallback: const CockpitRemoteSessionConfiguration(
            enabled: true,
            host: '127.0.0.1',
            port: 47331,
          ),
        ),
      ),
    ),
  );
}
