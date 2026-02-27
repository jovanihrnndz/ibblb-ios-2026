#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v skip >/dev/null 2>&1; then
  echo "error: skip is not installed or not on PATH"
  exit 1
fi

if ! command -v gradle >/dev/null 2>&1; then
  echo "error: gradle is not installed or not on PATH"
  exit 1
fi

# Prefer Homebrew Android command line tools when SDK env vars are unset.
if [[ -z "${ANDROID_HOME:-}" && -d "/opt/homebrew/share/android-commandlinetools" ]]; then
  export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
fi
if [[ -z "${ANDROID_SDK_ROOT:-}" && -n "${ANDROID_HOME:-}" ]]; then
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
fi
if [[ -n "${ANDROID_HOME:-}" ]]; then
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

if ! command -v adb >/dev/null 2>&1; then
  echo "error: adb is not on PATH. Set ANDROID_HOME/ANDROID_SDK_ROOT or install platform-tools."
  exit 1
fi

if ! adb devices | awk 'NR>1 {print $2}' | grep -q '^device$'; then
  echo "error: no Android device/emulator connected. Start one, then rerun."
  exit 1
fi

echo "==> skip android build"
skip android build

echo "==> skip android test"
skip android test

echo "==> gradle -p Android :app:assembleDebug"
gradle -p Android :app:assembleDebug

echo "Android verification complete."
