#!/usr/bin/env bash
set -euo pipefail

# reactivecircus/android-emulator-runner installs these packages internally
# without retry. Preinstalling them makes transient Google SDK zip failures
# retryable before the action starts the emulator.
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
ANDROID_EMULATOR_API_LEVEL="${ANDROID_EMULATOR_API_LEVEL:-34}"
ANDROID_COMPILE_API_LEVEL="${ANDROID_COMPILE_API_LEVEL:-36}"
SYSTEM_IMAGE_API_LEVEL="${SYSTEM_IMAGE_API_LEVEL:-$ANDROID_EMULATOR_API_LEVEL}"
ANDROID_EMULATOR_TARGET="${ANDROID_EMULATOR_TARGET:-default}"
ANDROID_EMULATOR_ARCH="${ANDROID_EMULATOR_ARCH:-x86_64}"
ANDROID_SDK_CHANNEL="${ANDROID_SDK_CHANNEL:-0}"
ANDROID_BUILD_TOOLS_VERSION="${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-27.0.12077973}"

export ANDROID_HOME ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  SDKMANAGER="$(command -v sdkmanager)"
fi

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    printf 'ANDROID_HOME=%s\n' "$ANDROID_HOME"
    printf 'ANDROID_SDK_ROOT=%s\n' "$ANDROID_SDK_ROOT"
  } >> "$GITHUB_ENV"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  {
    printf '%s\n' "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    printf '%s\n' "$ANDROID_SDK_ROOT/platform-tools"
    printf '%s\n' "$ANDROID_SDK_ROOT/emulator"
  } >> "$GITHUB_PATH"
fi

mkdir -p "$ANDROID_HOME/.android" "${ANDROID_AVD_HOME:-$HOME/.android/avd}"

set +o pipefail
yes | "$SDKMANAGER" --licenses > /dev/null
set -o pipefail

sdkmanager_retry() {
  local package_name="$1"
  local attempt

  for attempt in 1 2 3 4; do
    if "$SDKMANAGER" --install "$package_name" --channel="$ANDROID_SDK_CHANNEL"; then
      return 0
    fi
    echo "sdkmanager install '$package_name' attempt $attempt failed, retrying in 15s..." >&2
    rm -rf "$ANDROID_HOME/.temp" "$ANDROID_SDK_ROOT/.temp"
    sleep 15
  done

  "$SDKMANAGER" --install "$package_name" --channel="$ANDROID_SDK_CHANNEL"
}

sdkmanager_retry "build-tools;$ANDROID_BUILD_TOOLS_VERSION"
sdkmanager_retry "cmake;3.22.1"
sdkmanager_retry "platform-tools"
sdkmanager_retry "platforms;android-$ANDROID_EMULATOR_API_LEVEL"
if [ "$ANDROID_COMPILE_API_LEVEL" != "$ANDROID_EMULATOR_API_LEVEL" ]; then
  sdkmanager_retry "platforms;android-$ANDROID_COMPILE_API_LEVEL"
fi
sdkmanager_retry "emulator"
sdkmanager_retry "system-images;android-$SYSTEM_IMAGE_API_LEVEL;$ANDROID_EMULATOR_TARGET;$ANDROID_EMULATOR_ARCH"
if [ -n "$ANDROID_NDK_VERSION" ]; then
  sdkmanager_retry "ndk;$ANDROID_NDK_VERSION"
fi
