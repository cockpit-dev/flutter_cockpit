# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. Do not raise this minimum.
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "flutter_cockpit")
project(${PROJECT_NAME} LANGUAGES CXX)

cmake_policy(VERSION 3.14...3.25)

set(PLUGIN_NAME "flutter_cockpit_plugin")

list(APPEND PLUGIN_SOURCES
  "flutter_cockpit_plugin.cpp"
  "flutter_cockpit_plugin.h"
)

add_library(${PLUGIN_NAME} SHARED
  "include/flutter_cockpit/flutter_cockpit_plugin_c_api.h"
  "flutter_cockpit_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  flutter_wrapper_plugin
  gdiplus
  gdi32
  mfplat
  mfreadwrite
  mfuuid
  ole32
)

set(flutter_cockpit_bundled_libraries
  ""
  PARENT_SCOPE
)
