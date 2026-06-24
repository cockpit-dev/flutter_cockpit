import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

Future<void> main() async {
  runApp(const CockpitExampleApp());
}

class CockpitExampleApp extends StatefulWidget {
  const CockpitExampleApp({super.key});

  @override
  State<CockpitExampleApp> createState() => _CockpitExampleAppState();
}

class _CockpitExampleAppState extends State<CockpitExampleApp> {
  var _routeName = '/';

  @override
  void initState() {
    super.initState();
    FlutterCockpit.setCurrentRouteName(_routeName);
  }

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitApp(
      config: FlutterCockpitConfig.production(
        remoteSession: CockpitRemoteSessionConfiguration.resolveFromEnvironment(
          fallback: const CockpitRemoteSessionConfiguration(
            enabled: true,
            host: '127.0.0.1',
            port: 47331,
          ),
        ),
      ),
      child: MaterialApp(
        navigatorObservers: <NavigatorObserver>[
          FlutterCockpit.navigatorObserver,
        ],
        home: Scaffold(
          appBar: AppBar(title: const Text('Cockpit runtime example')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Current route: $_routeName'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _routeName = _routeName == '/' ? '/settings' : '/';
                      FlutterCockpit.setCurrentRouteName(_routeName);
                    });
                  },
                  child: const Text('Toggle route signal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
