# SwiftUI Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix remaining deprecated APIs, a dark-mode color bug, a layout-overhead anti-pattern, and a hot-path performance issue across four files not touched by the previous PR.

**Architecture:** All changes are surgical — no new files, no behavioral changes. Each task is isolated to one file. Order is: deprecated APIs first (lowest risk), then layout/performance improvements.

**Tech Stack:** Swift 6, SwiftUI, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS minimum deployment target (15+).

---

## Context: Files in Scope

These files were **not touched** by the previous `fix/swiftui-code-review` PR:

| File | Path |
|------|------|
| NowPlayingView | `IBBLB/UI/NowPlaying/NowPlayingView.swift` |
| GivingView | `IBBLB/Features/Giving/GivingView.swift` |
| ContinueListeningCardView | `IBBLB/UI/Components/ContinueListeningCardView.swift` |
| BannerView | `IBBLB/Components/BannerView.swift` |

## How to Verify

After each task, build to confirm no regressions:

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected output: `** BUILD SUCCEEDED **`

---

### Task 1: Fix `foregroundColor` in `ContinueListeningCardView.swift`

**Files:**
- Modify: `IBBLB/UI/Components/ContinueListeningCardView.swift`

Three instances on lines 70, 77, 88.

**Step 1: Apply replacements**

Line 70 — "Continue Listening" label:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 77 — sermon title:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

Line 88 — time label:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

**Step 2: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add IBBLB/UI/Components/ContinueListeningCardView.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in ContinueListeningCardView"
```

---

### Task 2: Fix `foregroundColor` in `GivingView.swift` + dark mode `Color.white` bug

**Files:**
- Modify: `IBBLB/Features/Giving/GivingView.swift`

Eight `foregroundColor` instances **plus** a `Color.white` background that breaks dark mode.

**Step 1: Fix `Color.white` background (dark mode bug)**

Line 22 — the `ZStack` background:
```swift
// Before
Color.white
    .ignoresSafeArea()
// After
Color(.systemBackground)
    .ignoresSafeArea()
```

**Step 2: Replace all `foregroundColor` instances**

Line 29 — subtitle text:
```swift
// Before
.foregroundColor(.gray)
// After
.foregroundStyle(.secondary)
```

Line 37 — total given amount:
```swift
// Before
.foregroundColor(.gray)
// After
.foregroundStyle(.secondary)
```

Line 59 — give button text:
```swift
// Before
.foregroundColor(.white)
// After
.foregroundStyle(.white)
```

Line 74 — manage account link:
```swift
// Before
.foregroundColor(.gray)
// After
.foregroundStyle(.secondary)
```

Line 100 — "Notifications" heading:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

Line 107 — "New Sermons" row title:
```swift
// Before
.foregroundColor(.primary)
// After
.foregroundStyle(.primary)
```

Line 111 — row description:
```swift
// Before
.foregroundColor(.secondary)
// After
.foregroundStyle(.secondary)
```

Line 120 — "Open Settings" button:
```swift
// Before
.foregroundColor(.blue)
// After
.foregroundStyle(.blue)
```

**Step 3: Move `.task` from `notificationsSection` to the parent body**

Currently `.task` is attached to `notificationsSection` (a computed property), which makes the refresh lifecycle hard to trace. Move it to sit alongside the other `.task` on the `ScrollView`.

Find this in `body`:
```swift
notificationsSection
    .task {
        await notificationManager.refreshAuthorizationStatus()
    }
```

Replace with:
```swift
notificationsSection
```

Then add the task to the `ScrollView` (alongside the existing `.task { await viewModel.loadGivingPage() }`):
```swift
.task {
    await viewModel.loadGivingPage()
}
.task {
    await notificationManager.refreshAuthorizationStatus()
}
```

Note: Two separate `.task` modifiers on the same view is valid — each runs independently and is cancelled when the view disappears.

**Step 4: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add IBBLB/Features/Giving/GivingView.swift
git commit -m "fix: foregroundStyle, dark mode systemBackground, and task placement in GivingView"
```

---

### Task 3: Fix `foregroundColor` in `NowPlayingView.swift`

**Files:**
- Modify: `IBBLB/UI/NowPlaying/NowPlayingView.swift`

Eleven instances spread across `titleView`, `seekSection`, `controlsSection`, and `stopButton`.

**Step 1: Replace all instances**

Use the exact locations below. Replace every `.foregroundColor(` with `.foregroundStyle(` — the argument stays the same in all cases.

Locations and their current arguments:
- Line 94: `.foregroundColor(.primary)` → `.foregroundStyle(.primary)`
- Line 100: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`
- Line 108: `.foregroundColor(.primary)` → `.foregroundStyle(.primary)`
- Line 237: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`
- Line 248: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`
- Line 267: `.foregroundColor(.primary)` → `.foregroundStyle(.primary)`
- Line 272: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`
- Line 289: `.foregroundColor(.white)` → `.foregroundStyle(.white)`
- Line 312: `.foregroundColor(.primary)` → `.foregroundStyle(.primary)`
- Line 319: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`
- Line 337: `.foregroundColor(.secondary)` → `.foregroundStyle(.secondary)`

**Step 2: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add IBBLB/UI/NowPlaying/NowPlayingView.swift
git commit -m "fix: replace deprecated foregroundColor with foregroundStyle in NowPlayingView"
```

---

### Task 4: Cache parsed title in `NowPlayingView.swift` to fix 0.5s hot path

**Files:**
- Modify: `IBBLB/UI/NowPlaying/NowPlayingView.swift`

**Background:** `NowPlayingView` observes `AudioPlayerManager`, which fires `currentTime` updates every ~0.5s. On every update, `body` re-evaluates and calls `titleView(for:)`, which calls `parseTitleComponents` — a string-scanning function — even though the track title never changes during playback. The fix: cache the parsed result in `@State` and recompute only when the track title actually changes.

**Step 1: Add `@State` for the cached parsed title**

Add this property alongside the existing `@State` properties (after `isDragging`):

```swift
@State private var parsedTitleComponents: (title: String, subtitle: String)? = nil
```

**Step 2: Populate the cache with `onChange`**

Add this modifier to the outermost `VStack` in `body` (alongside the existing `.onChange(of: audioManager.currentTime)`):

```swift
.onChange(of: audioManager.currentTrack?.title, initial: true) { _, newTitle in
    guard let title = newTitle else {
        parsedTitleComponents = nil
        return
    }
    let separators = ["–", "—", "-"]
    if let (titlePart, subtitlePart, _) = parseTitleComponents(title, separators: separators) {
        parsedTitleComponents = (titlePart, subtitlePart)
    } else {
        parsedTitleComponents = nil
    }
}
```

**Step 3: Rewrite `titleView(for:)` to use the cache**

Replace the current `titleView(for:)` implementation:

```swift
@ViewBuilder
private func titleView(for track: AudioTrackInfo) -> some View {
    if let parsed = parsedTitleComponents {
        VStack(spacing: 6) {
            Text(parsed.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text(parsed.subtitle)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    } else {
        Text(track.title)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(3)
    }
}
```

Note: `parseTitleComponents` method itself stays unchanged — it's still used by the `onChange` handler.

**Step 4: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 5: Smoke test**

Run in Simulator. Open the Now Playing sheet. Confirm the title and subtitle display correctly (e.g. for a title like "Grace – Pastor John", it should split into "Grace" and "Pastor John"). Play/pause — confirm the view still updates correctly.

**Step 6: Commit**

```bash
git add IBBLB/UI/NowPlaying/NowPlayingView.swift
git commit -m "perf: cache parsed title in NowPlayingView to avoid re-parsing every 0.5s"
```

---

### Task 5: Remove unnecessary `GeometryReader` from `BannerView.swift`

**Files:**
- Modify: `IBBLB/Components/BannerView.swift`

**Background:** `BannerView` wraps an `Image` in `GeometryReader` solely to set `width: geometry.size.width`. This causes extra layout passes on every parent resize. Since `BannerView` appears in all four tabs, this overhead multiplies. The image can fill width naturally using `maxWidth: .infinity` without any geometry reading.

**Step 1: Replace the `GeometryReader` with a direct layout**

Current `body`:
```swift
var body: some View {
    GeometryReader { geometry in
        Image("churchBanner")
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: bannerHeight)
            .clipped()
            .overlay(
                LinearGradient(...)
            )
    }
    .frame(height: bannerHeight)
}
```

Replace with:
```swift
var body: some View {
    Image("churchBanner")
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity, minHeight: bannerHeight, maxHeight: bannerHeight)
        .clipped()
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.75), location: 0.0),
                    .init(color: .black.opacity(0.75), location: 0.3),
                    .init(color: .clear,               location: 0.6),
                    .init(color: Color(.systemBackground), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}
```

Note: Remove the `.frame(height: bannerHeight)` call at the call sites — callers use `.frame(maxWidth: .infinity)` which is fine. The banner now sizes itself via `minHeight/maxHeight`.

**Step 2: Check call sites — no changes needed**

Search for `BannerView()` usages:
```bash
grep -r "BannerView()" IBBLB/ --include="*.swift"
```

All call sites use `.frame(maxWidth: .infinity)` which is compatible with the new layout. No changes needed at call sites.

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Visual check**

Run in Simulator. Open each tab (Sermons, Live, Events, Giving). Confirm the banner image fills the full width and the gradient overlay looks identical to before.

**Step 5: Commit**

```bash
git add IBBLB/Components/BannerView.swift
git commit -m "perf: remove unnecessary GeometryReader from BannerView"
```

---

### Task 6: Extract duplicated artwork modifier chain in `NowPlayingView.swift`

**Files:**
- Modify: `IBBLB/UI/NowPlaying/NowPlayingView.swift`

**Background:** The `artworkView` computed property contains two nearly-identical branches (YouTube fallback path and standard `AsyncImage` path), each applying the same `.frame(width:height:).clipped().clipShape(...).shadow(...).shadow(...)` chain. Extracting this to a private helper removes ~30 lines of duplication.

**Step 1: Add a private `artworkContainer` modifier helper**

Add this private method above `artworkView`:

```swift
/// Applies the shared artwork container styling: clipped rounded square with dual shadow.
private func styledArtwork<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .frame(width: artworkSize, height: artworkSize)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
}
```

**Step 2: Rewrite `artworkView` using the helper**

Replace the current `artworkView` implementation with:

```swift
@ViewBuilder
private var artworkView: some View {
    if let artworkURL = audioManager.currentTrack?.artworkURL {
        if let fallbackURLs = thumbnailFallbackURLs(from: artworkURL) {
            styledArtwork {
                FallbackAsyncImage(urls: fallbackURLs) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 30)
                                .scaleEffect(1.2)
                        }
                        .frame(width: artworkSize, height: artworkSize)
                } placeholder: {
                    placeholderArtwork
                        .overlay(ProgressView().tint(.primary))
                }
            }
        } else {
            styledArtwork {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .blur(radius: 30)
                                    .scaleEffect(1.2)
                            }
                    case .failure:
                        placeholderArtwork
                    case .empty:
                        placeholderArtwork
                            .overlay(ProgressView().tint(.primary))
                    @unknown default:
                        placeholderArtwork
                    }
                }
            }
        }
    } else {
        placeholderArtwork
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}
```

Note: The `else` branch (no artwork URL) uses a lighter shadow and is intentionally left separate — it's the fallback with different visual weight.

**Step 3: Build**

```bash
xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "error:|BUILD SUCCEEDED"
```
Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add IBBLB/UI/NowPlaying/NowPlayingView.swift
git commit -m "refactor: extract duplicated artwork modifier chain in NowPlayingView"
```

---

### Task 7: Final build verification

**Step 1: Clean build**

```bash
xcodebuild clean -scheme IBBLB && xcodebuild -scheme IBBLB -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

**Step 2: Manual smoke test checklist**

- [ ] All four tabs show the banner image filling full width with correct gradient
- [ ] Giving tab: dark mode — background is adaptive (not stark white)
- [ ] Giving tab: Notifications toggle works; "Open Settings" appears when permission denied
- [ ] Now Playing sheet: title and subtitle display correctly for hyphenated titles
- [ ] Now Playing sheet: artwork displays with rounded corners and shadows
- [ ] Continue Listening card appears on Sermons tab when audio is paused mid-sermon
