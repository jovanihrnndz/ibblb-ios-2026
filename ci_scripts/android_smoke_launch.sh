#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

do_install=1
if [[ "${1:-}" == "--skip-install" ]]; then
  do_install=0
fi

PKG="com.jovanihrnndz.ibblb"
ACTIVITY_FULL="com.jovanihrnndz.ibblb.MainActivity"
ACTIVITY_SHORT=".MainActivity"
COMPONENT="${PKG}/${ACTIVITY_SHORT}"

if ! command -v gradle >/dev/null 2>&1; then
  echo "error: gradle is not installed or not on PATH"
  exit 1
fi

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

if [[ "$do_install" -eq 1 ]]; then
  echo "==> gradle -p Android :app:installDebug"
  gradle -p Android :app:installDebug >/dev/null
fi

resolved_component="$(adb shell cmd package resolve-activity --brief "${PKG}" 2>/dev/null | tail -n1 | tr -d '\r')"
if [[ "$resolved_component" == */* ]]; then
  COMPONENT="$resolved_component"
fi
if [[ "$COMPONENT" == "${PKG}/${PKG}."* ]]; then
  COMPONENT="${PKG}/.${COMPONENT#${PKG}/${PKG}.}"
fi

echo "==> adb shell am start -n ${COMPONENT}"
adb shell am start -n "${COMPONENT}" >/dev/null

echo "==> waiting for foreground focus on ${COMPONENT}"
focused_ok=0
resumed_ok=0
for _ in {1..10}; do
  focus_line="$(adb shell dumpsys window | awk '/mCurrentFocus=/{print; exit}')"
  resumed_line="$(adb shell dumpsys activity activities | awk '/topResumedActivity=/{print; exit}')"

  if [[ "$focus_line" == *"${PKG}/${ACTIVITY_FULL}"* || "$focus_line" == *"${PKG}/${ACTIVITY_SHORT}"* ]]; then
    focused_ok=1
  fi
  if [[ "$resumed_line" == *"${PKG}/${ACTIVITY_SHORT}"* || "$resumed_line" == *"${PKG}/${ACTIVITY_FULL}"* ]]; then
    resumed_ok=1
  fi

  if [[ "$focused_ok" -eq 1 && "$resumed_ok" -eq 1 ]]; then
    break
  fi
  sleep 1
done

if [[ "$focused_ok" -ne 1 || "$resumed_ok" -ne 1 ]]; then
  echo "error: app did not reach stable foreground state"
  echo "focus:   $(adb shell dumpsys window | awk '/mCurrentFocus=/{print; exit}')"
  echo "resumed: $(adb shell dumpsys activity activities | awk '/topResumedActivity=/{print; exit}')"
  exit 1
fi

echo "Android launch smoke passed."
