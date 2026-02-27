# Android Setup (Skip)

## Prerequisites

- Skip CLI: `brew install skiptools/skip/skip`
- Java + Android command-line tools (or Android Studio)
- Running emulator/device (`adb devices`)

## Validate Swift/Skip module

From the package root:

```bash
cd /Users/jovanihernandez/ibblb_ios/IBBLB
./ci_scripts/android_verify.sh
```

## Build/Install Android app wrapper

```bash
cd /Users/jovanihernandez/ibblb_ios/IBBLB
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export ANDROID_SDK_ROOT=$ANDROID_HOME
gradle -p Android :app:installDebug
adb shell am start -n com.jovanihrnndz.ibblb/com.jovanihrnndz.ibblb.MainActivity
```
