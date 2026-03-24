#include "include/flutter_cockpit/flutter_cockpit_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_cockpit_plugin.h"

void FlutterCockpitPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_cockpit::FlutterCockpitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
