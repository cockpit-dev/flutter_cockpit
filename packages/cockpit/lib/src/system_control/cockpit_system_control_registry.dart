import 'adapters/cockpit_android_system_control_adapter.dart';
import 'adapters/cockpit_desktop_system_control_adapter.dart';
import 'adapters/cockpit_ios_system_control_adapter.dart';
import 'cockpit_system_control_adapter.dart';

typedef CockpitSystemControlAdapterFactory =
    CockpitSystemControlAdapter Function(String platform);

final class CockpitSystemControlRegistry {
  const CockpitSystemControlRegistry({
    Map<String, CockpitSystemControlAdapter> adapters =
        const <String, CockpitSystemControlAdapter>{},
  }) : _adapters = adapters;

  final Map<String, CockpitSystemControlAdapter> _adapters;

  CockpitSystemControlAdapter resolve(String platform) {
    final normalized = platform.trim().toLowerCase();
    final override = _adapters[normalized];
    if (override != null) {
      return override;
    }
    return switch (normalized) {
      'android' => const CockpitAndroidSystemControlAdapter(),
      'ios' => const CockpitIosSystemControlAdapter(),
      'macos' => const CockpitDesktopSystemControlAdapter(
        platform: 'macos',
        adapter: 'macos.accessibility+screencapture',
        inputStrategy: 'Accessibility API + CGEvent',
        screenshotStrategy: 'screencapture or ScreenCaptureKit',
        recordingStrategy: 'ScreenCaptureKit or ffmpeg avfoundation',
        requires: <String>[
          'Accessibility permission',
          'Screen Recording permission',
        ],
      ),
      'windows' => const CockpitDesktopSystemControlAdapter(
        platform: 'windows',
        adapter: 'windows.uia+sendinput',
        inputStrategy: 'UI Automation + SendInput',
        screenshotStrategy: 'Windows Graphics Capture or Desktop Duplication',
        recordingStrategy: 'Windows Graphics Capture',
        requires: <String>['interactive desktop session'],
      ),
      'linux' => const CockpitDesktopSystemControlAdapter(
        platform: 'linux',
        adapter: 'linux.at-spi+x11+portal',
        inputStrategy: 'AT-SPI or X11 input',
        screenshotStrategy:
            'xdg-desktop-portal, grim, gnome-screenshot, xwd+ffmpeg, ffmpeg x11grab, or X11',
        recordingStrategy: 'PipeWire portal or ffmpeg x11grab',
        requires: <String>['desktop session', 'portal permission on Wayland'],
        limitations: <String>[
          'Wayland blocks arbitrary global input without compositor support',
        ],
      ),
      'web' => const CockpitWebSystemControlAdapter(),
      _ => CockpitUnsupportedSystemControlAdapter(normalized),
    };
  }
}
