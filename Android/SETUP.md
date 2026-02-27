# Android Setup (Skip)

## Prerequisites

- Install Skip CLI:
  - `brew install skiptools/skip/skip`
- Install Java 17 or newer:
  - `brew install openjdk@17`
- Install Android Studio and complete SDK setup (SDK + emulator/device tools).

## Initialize

From this folder (`Android/`):

```bash
cd /Users/jovanihernandez/ibblb_ios/IBBLB/Android
skip checkup
skip init
```

## Build

```bash
cd /Users/jovanihernandez/ibblb_ios/IBBLB/Android
skip android build
```

Optional run command:

```bash
skip android run
```
