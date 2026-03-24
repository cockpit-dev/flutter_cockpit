import 'package:flutter/widgets.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'package:cockpit_demo/src/cockpit_demo_app.dart';

Widget buildCockpitDemoDevelopmentApp() {
  const enableDebugDiagnostics = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_DEBUG_DIAGNOSTICS',
  );
  const enableTapFeedback = bool.fromEnvironment(
    'FLUTTER_COCKPIT_ENABLE_TAP_FEEDBACK',
  );

  return CockpitDemoApp(
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
  );
}
