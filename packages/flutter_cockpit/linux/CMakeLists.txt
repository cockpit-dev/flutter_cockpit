# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. Do not raise this minimum.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_cockpit")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "flutter_cockpit_plugin")

list(APPEND PLUGIN_SOURCES
  "flutter_cockpit_plugin.cc"
)

add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET gstreamer-1.0)
pkg_check_modules(GSTREAMER_APP REQUIRED IMPORTED_TARGET gstreamer-app-1.0)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE
  flutter
  PkgConfig::GTK
  PkgConfig::GSTREAMER
  PkgConfig::GSTREAMER_APP
)

set(flutter_cockpit_bundled_libraries
  ""
  PARENT_SCOPE
)
