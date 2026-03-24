import 'package:flutter/widgets.dart';

import 'flutter_cockpit.dart';
import 'flutter_cockpit_config.dart';
import 'flutter_cockpit_root.dart';

final class FlutterCockpitApp extends StatefulWidget {
  const FlutterCockpitApp({
    required this.child,
    this.config = const FlutterCockpitConfig.production(),
    this.ownsRuntime = false,
    super.key,
  });

  final Widget child;
  final FlutterCockpitConfig config;
  final bool ownsRuntime;

  @override
  State<FlutterCockpitApp> createState() => _FlutterCockpitAppState();
}

final class _FlutterCockpitAppState extends State<FlutterCockpitApp> {
  @override
  void initState() {
    super.initState();
    FlutterCockpit.ensureInitialized(widget.config);
  }

  @override
  void didUpdateWidget(covariant FlutterCockpitApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      FlutterCockpit.binding.updateConfiguration(
        widget.config.toRuntimeConfiguration(),
      );
    }
  }

  @override
  void dispose() {
    if (widget.ownsRuntime) {
      FlutterCockpit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterCockpitRoot(child: widget.child);
  }
}
