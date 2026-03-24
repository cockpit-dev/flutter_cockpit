import 'package:flutter/widgets.dart';

import 'flutter_cockpit.dart';
import 'flutter_cockpit_app.dart';
import 'flutter_cockpit_config.dart';
import 'flutter_cockpit_configuration.dart';

final class FlutterCockpitHost extends StatefulWidget {
  const FlutterCockpitHost({
    this.child,
    this.builder,
    this.configuration = const FlutterCockpitConfiguration(),
    this.ownsRuntime = false,
    super.key,
  }) : assert(child != null || builder != null);

  final Widget? child;
  final WidgetBuilder? builder;
  final FlutterCockpitConfiguration configuration;
  final bool ownsRuntime;

  @override
  State<FlutterCockpitHost> createState() => _FlutterCockpitHostState();
}

final class _FlutterCockpitHostState extends State<FlutterCockpitHost> {
  @override
  void initState() {
    super.initState();
    FlutterCockpit.initialize(widget.configuration);
  }

  @override
  void didUpdateWidget(covariant FlutterCockpitHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration) {
      FlutterCockpit.binding.updateConfiguration(widget.configuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.builder?.call(context) ?? widget.child;
    if (child == null) {
      throw StateError(
        'FlutterCockpitHost requires either a child or builder.',
      );
    }
    return FlutterCockpitApp(
      ownsRuntime: widget.ownsRuntime,
      config: FlutterCockpitConfig.fromRuntimeConfiguration(
        widget.configuration,
      ),
      child: child,
    );
  }
}
