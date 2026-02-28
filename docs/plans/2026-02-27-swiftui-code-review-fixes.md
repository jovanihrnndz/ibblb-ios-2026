# SwiftUI Code Review Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all issues identified in the SwiftUI code review: deprecated APIs, incorrect state management, performance regressions, missing animations, and accessibility gaps.

**Architecture:** Each task is isolated and surgical — no behavioral changes, only correctness and modernization. Changes are grouped by file to minimize churn. No new files needed except `EventCardView`.

**Tech Stack:** Swift 6, SwiftUI, iOS 15+ minimum deployment target, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

---

## Context: Issues to Fix

From the code review, ordered by severity:

| # | Issue | File(s) |
|---|-------|---------|
| 1 | `foregroundColor` → `foregroundStyle` (deprecated iOS 15+) | 6 files |
| 2 | `cornerRadius()` → `clipShape(.rect(cornerRadius:))` (deprecated iOS 15+) | 5 files |
| 3 | Missing `withAnimation` for video overlay transition | `LiveView.swift` |
| 4 | `@StateObject` for injected viewModel → `@ObservedObject` | `SermonsView.swift` |
| 5 | `SermonsView` re-renders every 0.5s from audio updates | `SermonsView.swift` |
| 6 | Extract `eventCard` → dedicated `EventCardView` struct | `EventsView.swift` |
| 7 | Remove no-op `listSermons` wrapper | `SermonsView.swift` |
| 8 | Accessibility label for date badge | `EventsView.swift` |

---

## How to Verify Changes Are Safe

After each task, build and run in Simulator to confirm:
- No compiler errors
- Visual appearance unchanged
- The feature the changed file drives still works

Build command (from Xcode or CLI):
```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -20
```

---

### Task 1: Fix `foregroundColor` in `SermonsView.swift`

**Files:**
- Modify: `IBBLB/Features/Sermons/SermonsView.swift`

These are all straightforward token swaps — `foregroundColor` is deprecated; `foregroundStyle` is the replacement.

**Step 1: Open the file and locate all `foregroundColor` calls**

Lines to change: 249, 255, 285, 299

**Step 2: Apply replacements**

Line 249 — error icon color:
```swift
// Before
.foregroundColor(.amber)
// After
.foregroundStyle(Color.amber)
```

Line 255 — error message secondary:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 285 — empty state secondary:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 299 — "Clear Search" button text:
```swift
// Before
.foregroundColor(.white)
// After
.foregroundStyle(.white)
```

**Step 3: Build to confirm no errors**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

**Step 4: Commit**

```bash
git add IBBLB/Features/Sermons/SermonsView.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in SermonsView"
```

---

### Task 2: Fix `foregroundColor` in `SermonCardView.swift` and `SermonDetailView.swift`

**Files:**
- Modify: `IBBLB/UI/Components/SermonCardView.swift`
- Modify: `IBBLB/Features/Sermons/SermonDetailView.swift`

**Step 1: Fix `SermonCardView.swift`**

Line 23 — title color:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

Line 42 — speaker/date secondary:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

**Step 2: Fix `SermonDetailView.swift`**

Line 66 — speaker icon + text:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 83 — calendar icon + date:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 95 — audio button tint (inside button label):
```swift
// Before
.foregroundColor(.accentColor)
// After
.foregroundStyle(.accent)
```

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

**Step 4: Commit**

```bash
git add IBBLB/UI/Components/SermonCardView.swift IBBLB/Features/Sermons/SermonDetailView.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in sermon views"
```

---

### Task 3: Fix `foregroundColor` in `AudioMiniPlayerBar.swift`

**Files:**
- Modify: `IBBLB/UI/Components/AudioMiniPlayerBar.swift`

**Step 1: Apply replacements**

Line 34 — track title:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

Line 44 — play/pause icon:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

**Step 2: Build and commit**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
git add IBBLB/UI/Components/AudioMiniPlayerBar.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in AudioMiniPlayerBar"
```

---

### Task 4: Fix `foregroundColor` in `EventsView.swift` and `LiveView.swift`

**Files:**
- Modify: `IBBLB/Features/Events/EventsView.swift`
- Modify: `IBBLB/Features/Live/LiveView.swift`

**Step 1: Fix `EventsView.swift`**

Find every `.foregroundColor(` in the file and replace with `.foregroundStyle(`:

Locations: lines 37 (orange), 109 (secondary), 117 (secondary), 152 (secondary), 157 (secondary), 168 (accentColor → `.accent`), 173 (secondary), 184 (secondary)

```swift
// All instances: replace
.foregroundColor(.orange)        → .foregroundStyle(.orange)
.foregroundColor(.secondary)     → .foregroundStyle(.secondary)
.foregroundColor(.accentColor)   → .foregroundStyle(.accent)
```

**Step 2: Fix `LiveView.swift`**

Locations: lines 107, 116, 165, 194, 232, 299, 303, 328

```swift
// All instances: replace
.foregroundColor(.black)         → .foregroundStyle(.black)
.foregroundColor(.gray)          → .foregroundStyle(.gray)
.foregroundColor(.secondary)     → .foregroundStyle(.secondary)
.foregroundColor(.white)         → .foregroundStyle(.white)
```

Note: `LiveView` has hardcoded `.black` and `.white` colors in places like `WebStyleCountdownCard` and `NoUpcomingServiceCard` — replace those too, same pattern.

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```
Expected: `Build succeeded`

**Step 4: Commit**

```bash
git add IBBLB/Features/Events/EventsView.swift IBBLB/Features/Live/LiveView.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in Events and Live views"
```

---

### Task 5: Fix `cornerRadius()` in `SermonsView.swift`

**Files:**
- Modify: `IBBLB/Features/Sermons/SermonsView.swift`

**Step 1: Locate and replace `cornerRadius` usages in `errorView` and `emptyView`**

Line 269 — Retry button background:
```swift
// Before
.background(Color.accentColor)
.cornerRadius(10)
// After
.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
```

Line 303 — Clear Search button background:
```swift
// Before
.background(Color.accentColor)
.cornerRadius(10)
// After
.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
```

**Step 2: Build and commit**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
git add IBBLB/Features/Sermons/SermonsView.swift
git commit -m "fix: replace deprecated cornerRadius with clipShape in SermonsView"
```

---

### Task 6: Fix `cornerRadius()` in `EventsView.swift`

**Files:**
- Modify: `IBBLB/Features/Events/EventsView.swift`

**Step 1: Replace `cornerRadius` usages**

Line 177 — date badge background:
```swift
// Before
.background(Color.accentColor.opacity(0.1))
.cornerRadius(8)
// After
.background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
```

Line 198 — "Registrarse" button fill + cornerRadius:
```swift
// Before
.background(Color.accentColor)
.foregroundStyle(.white)
.cornerRadius(8)
// After
.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
.foregroundStyle(.white)
```

Line 207 — event card outer container:
```swift
// Before
.background(Color(.secondarySystemGroupedBackground))
.cornerRadius(16)
.shadow(...)
// After
.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
.shadow(...)
```

**Step 2: Build and commit**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
git add IBBLB/Features/Events/EventsView.swift
git commit -m "fix: replace deprecated cornerRadius with clipShape in EventsView"
```

---

### Task 7: Fix `cornerRadius()` in `LiveView.swift` and `SermonDetailView.swift`

**Files:**
- Modify: `IBBLB/Features/Live/LiveView.swift`
- Modify: `IBBLB/Features/Sermons/SermonDetailView.swift`

**Step 1: Fix `SermonDetailView.swift`**

Line 164 — YouTube player:
```swift
// Before
.cornerRadius(12)
// After
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

**Step 2: Fix `LiveView.swift`**

Line 65 — inline video overlay player:
```swift
// Before
.cornerRadius(12)
// After
.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

Line 269 — `WebStyleCountdownCard` outer shape:
```swift
// Before
.background(Color.white)
.cornerRadius(16)
// After
.background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
```

Line 364 — `NoUpcomingServiceCard` outer shape:
```swift
// Before
.frame(maxWidth: .infinity)
.background(Color.white)
.cornerRadius(16)
// After
.frame(maxWidth: .infinity)
.background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
```

Line 378 — `ServiceTimesCard` calendar icon background:
```swift
// Before
.background(Color.gray.opacity(0.1))
.cornerRadius(8)
// After
.background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
```

Line 394 — `ServiceTimesCard` card background:
```swift
// Before
.background(Color.white)
.cornerRadius(16)
// After
.background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
```

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

**Step 4: Commit**

```bash
git add IBBLB/Features/Live/LiveView.swift IBBLB/Features/Sermons/SermonDetailView.swift
git commit -m "fix: replace deprecated cornerRadius with clipShape in Live and SermonDetail views"
```

---

### Task 8: Fix missing animation for video overlay transition in `LiveView.swift`

**Files:**
- Modify: `IBBLB/Features/Live/LiveView.swift`

**Background:** The video overlay ZStack uses `.transition(.opacity)` but nothing drives that animation. When `activeVideoId` is set to `nil` (close button) or set to a value (open), the transition fires without an animation curve, making it jump instead of fade.

**Step 1: Wrap `activeVideoId` mutations in `withAnimation`**

Find the close button action (~line 52):
```swift
// Before
Button {
    activeVideoId = nil
} label: {
    Image(systemName: "xmark.circle.fill")
    ...
}

// After
Button {
    withAnimation(.easeInOut(duration: 0.2)) {
        activeVideoId = nil
    }
} label: {
    Image(systemName: "xmark.circle.fill")
    ...
}
```

Then find where `activeVideoId` is set when opening the player. Search for `activeVideoId =` assignments elsewhere in the file (likely in a button or tap handler on a video thumbnail) and wrap those too:
```swift
withAnimation(.easeInOut(duration: 0.2)) {
    activeVideoId = someVideoId
}
```

**Step 2: Verify transition**

Run in Simulator, go to Live tab, tap a previous service video. Confirm it fades in. Tap the X button. Confirm it fades out.

**Step 3: Build and commit**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
git add IBBLB/Features/Live/LiveView.swift
git commit -m "fix: add withAnimation to video overlay transition in LiveView"
```

---

### Task 9: Fix `@StateObject` → `@ObservedObject` for injected viewModel in `SermonsView.swift`

**Files:**
- Modify: `IBBLB/Features/Sermons/SermonsView.swift`

**Background:** `@StateObject` means "this view owns this object." `@ObservedObject` means "this view observes an object owned elsewhere." `SermonsViewModel` is created in `AppRootView` as `@StateObject private var sermonsViewModel`, then passed to `SermonsView`. The child doesn't own it — it receives it — so it should use `@ObservedObject`.

**Step 1: Change the property wrapper**

```swift
// Before
@StateObject private var viewModel: SermonsViewModel

// After
@ObservedObject var viewModel: SermonsViewModel
```

Note: remove `private` since the property is now received from outside (convention, not required).

**Step 2: Simplify the `init`**

```swift
// Before
init(
    viewModel: SermonsViewModel,
    hideTabBar: Binding<Bool>,
    notificationSermonId: Binding<String?>
) {
    _viewModel = StateObject(wrappedValue: viewModel)
    _hideTabBar = hideTabBar
    _notificationSermonId = notificationSermonId
}

// After
init(
    viewModel: SermonsViewModel,
    hideTabBar: Binding<Bool>,
    notificationSermonId: Binding<String?>
) {
    self.viewModel = viewModel
    _hideTabBar = hideTabBar
    _notificationSermonId = notificationSermonId
}
```

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

**Step 4: Smoke test**

Run in Simulator. Confirm the Sermons tab loads and displays sermons, search works, and the Continue Listening card appears when audio is playing.

**Step 5: Commit**

```bash
git add IBBLB/Features/Sermons/SermonsView.swift
git commit -m "fix: use @ObservedObject for injected SermonsViewModel in SermonsView"
```

---

### Task 10: Remove no-op `listSermons` wrapper and isolate audio observation in `SermonsView.swift`

**Files:**
- Modify: `IBBLB/Features/Sermons/SermonsView.swift`

This task has two parts: removing a pointless indirection and extracting audio-dependent content into a subview so `SermonsView.body` doesn't re-render every 0.5s.

**Step 1: Remove `listSermons`**

Delete lines 52–55:
```swift
// Delete entirely
private var listSermons: [Sermon] {
    return viewModel.sermons
}
```

Replace the two `ForEach(listSermons)` usages (in the grid and list branches of `sermonsListContent`) with `ForEach(viewModel.sermons)`.

**Step 2: Extract `ContinueListeningSection` to isolate audio observation**

The existing `@ObservedObject private var audioManager = AudioPlayerManager.shared` in `SermonsView` causes the entire view to re-render on every audio tick. Move the Continue Listening card and its `audioManager` dependency into a dedicated private struct:

```swift
/// Isolated observer for AudioPlayerManager so SermonsView doesn't re-render on every audio tick.
private struct ContinueListeningSection: View {
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    let sermons: [Sermon]
    let onCardTap: (Sermon) -> Void

    private var continueListeningInfo: AudioPlayerManager.ContinueListeningResult? {
        audioManager.getContinueListeningInfo(from: sermons)
    }

    var body: some View {
        if audioManager.currentTrack == nil, let info = continueListeningInfo {
            ContinueListeningCardView(
                result: info,
                duration: nil,
                onCardTap: info.hasMatchingSermon ? { onCardTap(info.sermon) } : nil,
                onResume: { audioManager.resumeListening(from: info) }
            )
        }
    }
}
```

**Step 3: Remove `audioManager` and `continueListeningInfo` from `SermonsView`**

Delete:
```swift
// Delete these two properties from SermonsView
@ObservedObject private var audioManager = AudioPlayerManager.shared
private var continueListeningInfo: AudioPlayerManager.ContinueListeningResult? { ... }
```

**Step 4: Update `sermonsListContent` to use the new subview**

Replace the inline Continue Listening block:
```swift
// Before
if !isTV, audioManager.currentTrack == nil,
   let info = continueListeningInfo {
    ContinueListeningCardView(...)
        .padding(...)
}

// After
if !isTV {
    ContinueListeningSection(sermons: viewModel.sermons) { sermon in
        selectedSermon = sermon
    }
    .padding(.top, useGridLayout ? 28 : 24)
    .padding(.bottom, useGridLayout ? -8 : 0)
}
```

**Step 5: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

**Step 6: Smoke test**

Run in Simulator. Start playing a sermon's audio, go back to Sermons list. Confirm the Continue Listening card appears. Confirm the list doesn't visibly "flicker" or re-render (it shouldn't, since `SermonsView` no longer observes `audioManager`).

**Step 7: Commit**

```bash
git add IBBLB/Features/Sermons/SermonsView.swift
git commit -m "perf: isolate AudioPlayerManager observation to ContinueListeningSection in SermonsView"
```

---

### Task 11: Extract `eventCard` to `EventCardView` in `EventsView.swift`

**Files:**
- Modify: `IBBLB/Features/Events/EventsView.swift`

**Background:** The 86-line `eventCard(@ViewBuilder func)` mixes layout, image loading, and action handlers. Extracting it to a struct improves readability, diffing performance, and makes it a proper building block.

**Step 1: Create `EventCardView` struct at the bottom of `EventsView.swift` (before `#Preview`)**

```swift
private struct EventCardView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageUrl = event.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .aspectRatio(16/9, contentMode: .fill)
                }
                .frame(maxHeight: 180)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(event.startDate.formatted(date: .long, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let location = event.location {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Date Badge
                    VStack(spacing: 0) {
                        Text(EventsView.dayString(from: event.startDate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.accent)
                        Text(EventsView.monthString(from: event.startDate))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(event.startDate, format: .dateTime.day().month(.wide)))
                }

                if let description = event.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }

                if event.registrationEnabled == true {
                    Button(action: {
                        // Registration action
                    }) {
                        Text("Registrarse")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 12)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}
```

Note: the accessibility label for the date badge is included here (Task 12 merged in for efficiency).

**Step 2: Replace `eventCard` calls in `eventsListContent`**

Find the two `NavigationLink` blocks (grid and list):
```swift
// Before
NavigationLink(value: event) {
    eventCard(event: event)
}

// After
NavigationLink(value: event) {
    EventCardView(event: event)
}
```

**Step 3: Delete the `eventCard` function** from `EventsView` (the `@ViewBuilder private func eventCard(event:)` block).

**Step 4: Delete the now-unused `dayFormatter`, `monthFormatter`, `dayString`, `monthString` helpers IF they are only used by `EventCardView` internally**

Actually — `EventCardView` calls `EventsView.dayString(from:)` and `EventsView.monthString(from:)`, which are `static` on `EventsView`. Move those static helpers to `EventCardView` or keep them on `EventsView` — either works. Keep them on `EventsView` since they're already `static`.

**Step 5: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|Build succeeded"
```

**Step 6: Commit**

```bash
git add IBBLB/Features/Events/EventsView.swift
git commit -m "refactor: extract eventCard to EventCardView struct, fix deprecated APIs, add date badge a11y"
```

---

### Task 12: Final build and smoke test

**Step 1: Full clean build**

```bash
xcodebuild clean -scheme IBBLB && xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: `Build succeeded`

**Step 2: Manual smoke test checklist**

Run on iPhone 16 Simulator:

- [ ] Sermons tab loads a list of sermons
- [ ] Searching filters the list correctly
- [ ] Tapping a sermon opens `SermonDetailView`
- [ ] Audio play button appears and plays audio
- [ ] Mini player appears after starting audio
- [ ] Continue Listening card appears on Sermons list while audio paused
- [ ] Live tab shows countdown or live stream
- [ ] Previous service video overlay opens and fades in/out correctly
- [ ] Events tab shows event cards with correct styling
- [ ] Date badge on event cards reads correctly with VoiceOver (enable: Settings → Accessibility → VoiceOver)

**Step 3: Tag the review as complete**

```bash
git log --oneline -12
```

Confirm all 11 commits from this plan are visible.
