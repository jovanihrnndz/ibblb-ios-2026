# Picture-in-Picture / Sticky Mini-Player Feasibility Report
**Date:** December 22, 2025  
**Feature:** Mini-player overlay for SermonDetailView when video scrolls off-screen

---

## A) Current Architecture Summary

### App Entry & Root Layout

**File:** `IBBLB/App/IBBLBApp.swift`
- Minimal app entry point
- Delegates to `AppRootView`

**File:** `IBBLB/App/AppRootView.swift`
```swift
// Lines 19-29: Root uses ZStack for splash overlay
ZStack {
    mainContent
    if showSplash {
        SplashView()
            .zIndex(1)  // ← Highest zIndex currently used
    }
}
// Lines 36-60: TabView contains all tabs
TabView(selection: $selectedTab) {
    SermonsView(hideTabBar: $hideTabBar)
    LiveView()
    EventsView()
    GivingView()
}
```

**Key Finding:** No global overlay coordinator exists. Each tab manages its own UI.

### Banner/Header Component

**File:** `IBBLB/Components/BannerView.swift`
```swift
// Lines 11-22: Simple GeometryReader-based banner
struct BannerView: View {
    var body: some View {
        GeometryReader { geometry in
            Image("churchBanner")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: 100)
        }
        .frame(height: 100)
    }
}
```

**Banner Placement Pattern:**
- **SermonsView** (line 49): `BannerView()` at top of VStack
- **SermonDetailView** (line 20): `BannerView()` at top of VStack
- **LiveView** (line 14): `BannerView()` at top of VStack
- **EventsView** (line 10): `BannerView()` at top of VStack

**Finding:** Banner is rendered **within each view's hierarchy**, not at AppRoot level. Each view has its own NavigationStack.

### Navigation Structure

**File:** `IBBLB/Features/Sermons/SermonsView.swift`
```swift
// Line 46: NavigationStack per tab
NavigationStack {
    ZStack(alignment: .top) {
        VStack(spacing: 0) {
            BannerView()  // ← Banner inside NavigationStack
            // ... content
        }
    }
    // Line 108: Navigation destination
    .navigationDestination(item: $selectedSermon) { sermon in
        SermonDetailView(sermon: sermon)
    }
}
```

**Finding:** Navigation is **per-tab**, not global. SermonDetailView is pushed within SermonsView's NavigationStack.

### SermonDetailView Structure

**File:** `IBBLB/Features/Sermons/SermonDetailView.swift`
```swift
// Lines 19-23: Structure
VStack(spacing: 0) {
    BannerView()  // ← Banner at top
    ScrollView {  // ← Standard ScrollView (NOT ScrollViewReader)
        VStack(alignment: .leading, spacing: 16) {
            // Line 28: Video player at top of scroll content
            YouTubePlayerView(videoID: videoId)
                .aspectRatio(16/9, contentMode: .fit)
            // ... rest of content
        }
    }
}
```

**Key Findings:**
- Uses `ScrollView` (not `ScrollViewReader`) - no scroll position tracking exists
- Video is first element in scroll content
- No `PreferenceKey` or `GeometryReader` for off-screen detection
- Banner is part of the detail view hierarchy

### Player Implementation

**File:** `IBBLB/UI/Components/YouTubePlayerView.swift`
```swift
// Lines 11-18: WKWebView-based YouTube embed
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    // ... config options
}

// Lines 24-54: WKWebView with iframe embed
func makeUIView(context: Context) -> WKWebView {
    let webView = WKWebView(frame: .zero, configuration: config)
    // ... configuration
    load(videoID: videoID, into: webView)  // ← Loads HTML with iframe
    return webView
}

// Lines 81-125: HTML iframe embed
private func htmlString(for videoID: String) -> String {
    // Returns HTML with YouTube iframe embed
    // Uses youtube-nocookie.com domain
}
```

**Key Findings:**
- **Technology:** WKWebView with YouTube iframe embed (not YouTubePlayerKit, not AVPlayer)
- **No JavaScript API:** No exposed methods for play/pause control
- **Instance-based:** Each `YouTubePlayerView` creates its own WKWebView instance
- **No shared state:** No coordinator or shared player instance

### Existing Overlay Patterns

**File:** `IBBLB/Features/Live/LiveView.swift`
```swift
// Lines 78-110: Fullscreen video overlay pattern
.overlay {
    if let rawVideoId = activeVideoId,
       let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            // ... YouTube player
        }
    }
}
```

**Finding:** Overlay pattern exists but is **view-local** (within LiveView's ScrollView overlay), not global.

**No existing patterns for:**
- PreferenceKey-based scroll tracking
- Global overlay coordinator
- Shared player state management

---

## B) Feasibility Matrix

### Option 1: Mini "Now Playing" Bar (No Video)
**Description:** Text-based mini-player showing title/thumbnail, pinned to top safe area.

**Feasibility:** ✅ **HIGHLY FEASIBLE**

**Pros:**
- No video playback complexity
- Simple state management (just show/hide based on scroll)
- Lightweight UI (text + thumbnail image)
- No player instance conflicts

**Cons:**
- Doesn't show actual video (just metadata)
- User must tap to return to video (no inline playback)

**Complexity:** Low  
**Playback Impact:** None (video continues in background)  
**Risks:** Minimal

**Implementation Notes:**
- Use `PreferenceKey` to detect when video scrolls off-screen
- Place overlay at AppRoot level with `.zIndex(2)` (above splash)
- Simple tap gesture to scroll back to video using `ScrollViewReader`

---

### Option 2: Mini Video View Overlay (Second Player Instance)
**Description:** Small video player overlay (e.g., 200x112) with second YouTubePlayerView instance.

**Feasibility:** ⚠️ **MODERATELY FEASIBLE** (with significant risks)

**Pros:**
- Shows actual video playback
- Better UX (video visible while scrolling)

**Cons:**
- **YouTube iframe limitations:** Each WKWebView instance loads independently
- **Playback state sync:** Two players won't share playback state (pause/play, position)
- **Performance:** Two WKWebView instances = double memory/CPU
- **YouTube rate limiting:** Multiple embeds may trigger bot detection
- **Reload on resize:** WKWebView may reload when resized
- **No JavaScript control:** Cannot programmatically control YouTube iframe playback

**Complexity:** High  
**Playback Impact:** High (video may reload, position lost, sync issues)  
**Risks:**
- Video reloads when switching between full/mini
- Playback position not preserved
- Two videos playing simultaneously (audio conflict)
- YouTube may block multiple embeds

**Implementation Notes:**
- Would require creating second `YouTubePlayerView` instance
- Need to track which player is "active"
- No way to sync playback state between instances
- May need to pause full player when mini appears (defeats purpose)

---

### Option 3: True iOS Picture-in-Picture (AVPlayer)
**Description:** Native iOS PiP using AVPlayer with YouTube video extraction.

**Feasibility:** ❌ **NOT FEASIBLE** (requires major architecture change)

**Pros:**
- Native iOS experience
- System-managed overlay
- Works across app boundaries

**Cons:**
- **YouTube extraction required:** Need to extract direct video URL from YouTube (violates ToS, unreliable)
- **Architecture mismatch:** Current player is WKWebView iframe, not AVPlayer
- **YouTube restrictions:** Direct video URLs are rate-limited and may break
- **Legal/ToS concerns:** YouTube Terms of Service may prohibit direct video extraction
- **Maintenance burden:** YouTube changes break extraction methods frequently

**Complexity:** Very High  
**Playback Impact:** High (requires complete player rewrite)  
**Risks:**
- YouTube API changes break functionality
- Legal/ToS violations
- Unreliable video URL extraction
- Requires AVPlayer integration (not WKWebView)

**Implementation Notes:**
- Would require YouTube video URL extraction library (e.g., youtube-dl, yt-dlp)
- Need to rewrite player to use AVPlayer instead of WKWebView
- YouTube actively blocks direct video access
- Not recommended for production apps

---

## C) Recommended Approach

### **Recommendation: Option 1 - Mini "Now Playing" Bar**

**Rationale:**
1. **Lowest risk:** No player conflicts, no YouTube API issues
2. **Simplest implementation:** Uses existing scroll detection patterns
3. **Good UX:** Users can quickly return to video with tap
4. **Maintainable:** Minimal code, no complex state management
5. **Performance:** Lightweight, no additional WKWebView instances

**UX Flow:**
1. User scrolls SermonDetailView
2. When video scrolls off-screen → Show mini bar at top (below Dynamic Island)
3. Mini bar shows: Thumbnail + Title + "Tap to return to video"
4. Tapping mini bar → Scrolls back to video position
5. Video continues playing in background (no interruption)

**Future Enhancement Path:**
- If YouTube JavaScript API becomes available, add play/pause button to mini bar
- Consider native iOS PiP if app migrates to AVPlayer architecture

---

## D) Minimal Implementation Plan

### 1. Overlay Placement (Above Banner)

**Location:** `IBBLB/App/AppRootView.swift`

```swift
// Add to AppRootView body:
ZStack {
    mainContent
        .opacity(showSplash ? 0 : 1)
    
    if showSplash {
        SplashView()
            .zIndex(1)
    }
    
    // NEW: Mini-player overlay (above banner, below Dynamic Island)
    if let miniPlayerState = miniPlayerCoordinator.activeState {
        MiniPlayerBar(state: miniPlayerState)
            .zIndex(2)  // Above splash, above all content
            .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
    }
}
```

**Why AppRoot level:**
- Must be above TabView and all NavigationStacks
- Must be above BannerView (which is inside each view)
- Needs global zIndex to overlay everything

### 2. Shared State Object/Coordinator

**New File:** `IBBLB/Services/MiniPlayerCoordinator.swift`

```swift
@MainActor
class MiniPlayerCoordinator: ObservableObject {
    @Published var activeState: MiniPlayerState?
    
    struct MiniPlayerState {
        let sermon: Sermon
        let scrollToAction: () -> Void  // Closure to scroll back
    }
    
    func showMiniPlayer(for sermon: Sermon, scrollAction: @escaping () -> Void) {
        activeState = MiniPlayerState(sermon: sermon, scrollToAction: scrollAction)
    }
    
    func hideMiniPlayer() {
        activeState = nil
    }
}
```

**Usage:**
- Inject as `@StateObject` in AppRootView
- Pass as environment object to all views
- SermonDetailView calls `coordinator.showMiniPlayer()` when video off-screen

### 3. Off-Screen Detection

**New File:** `IBBLB/UI/Components/ScrollOffsetPreferenceKey.swift`

```swift
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Usage in SermonDetailView:
ScrollView {
    VStack {
        YouTubePlayerView(videoID: videoId)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                }
            )
        // ... rest of content
    }
}
.coordinateSpace(name: "scroll")
.onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
    // If offset < -100 (video scrolled up off-screen)
    if offset < -100 && !isMiniPlayerShowing {
        coordinator.showMiniPlayer(...)
    }
}
```

**Alternative (Simpler):** Use `GeometryReader` with `.onAppear/.onDisappear` on video view (less precise but simpler).

### 4. Scroll Back to Video on Tap

**File:** `IBBLB/Features/Sermons/SermonDetailView.swift`

```swift
// Change ScrollView to ScrollViewReader:
ScrollViewReader { proxy in
    ScrollView {
        VStack {
            YouTubePlayerView(videoID: videoId)
                .id("videoPlayer")  // ← Add ID
            // ... rest
        }
    }
    .onAppear {
        // Store scroll action in coordinator
        coordinator.setScrollAction {
            withAnimation {
                proxy.scrollTo("videoPlayer", anchor: .top)
            }
        }
    }
}
```

**MiniPlayerBar tap handler:**
```swift
Button {
    coordinator.activeState?.scrollToAction()
    coordinator.hideMiniPlayer()
} label: {
    // Mini bar UI
}
```

---

## Summary

**Recommended:** Option 1 (Mini "Now Playing" Bar)  
**Feasibility:** High  
**Complexity:** Low-Medium  
**Timeline Estimate:** 2-3 days  
**Risk Level:** Low

**Key Constraints:**
- YouTube iframe embeds don't support JavaScript control (no play/pause in mini bar)
- Must place overlay at AppRoot level to be above banner
- Requires PreferenceKey or GeometryReader for scroll detection
- ScrollViewReader needed for scroll-to-video functionality

**Next Steps:**
1. Create `MiniPlayerCoordinator` service
2. Add overlay to `AppRootView` with zIndex(2)
3. Implement scroll detection in `SermonDetailView`
4. Create `MiniPlayerBar` component
5. Wire up tap-to-scroll functionality

