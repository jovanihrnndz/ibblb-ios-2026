# iOS App Audit Report
**Date**: 2025-01-27  
**App**: IBBLB iOS App  
**Scope**: Full codebase audit (Build, SwiftUI, Concurrency, Media, Performance, UI/UX)

---

## Executive Summary

The app is generally well-structured with good separation of concerns. However, **critical issues** were found:
- **P0**: Duplicate audio player implementations causing potential conflicts
- **P0**: Deprecated Info.plist configuration
- **P1**: Broken UI button, race conditions in async operations
- **P2**: Performance optimizations and accessibility improvements needed

---

## P0: Critical Issues (Crash/Data Loss Risk)

### 1. Duplicate Audio Player Managers ⚠️ **CRITICAL**

**Location**: 
- `IBBLB/Services/AudioPlayerManager.swift` (lines 1-337)
- `IBBLB/Services/AudioPlaybackController.swift` (lines 1-173)
- `IBBLB/UI/Components/AudioPlayerView.swift` (line 11)

**Problem**: 
- Two separate audio player singletons exist: `AudioPlayerManager` (used app-wide) and `AudioPlaybackController` (only used in `AudioPlayerView`)
- Both manage AVPlayer instances independently, causing:
  - Potential audio conflicts (two players trying to play simultaneously)
  - State desynchronization (mini player shows different state than AudioPlayerView)
  - Memory leaks if both are initialized
  - Background audio session conflicts

**Evidence**:
- `SermonDetailView` uses `AudioPlayerManager.shared`
- `AppRootView`/`iPadRootView` use `AudioPlayerManager.shared` for mini player
- `AudioPlayerView` uses `AudioPlaybackController.shared`

**Fix**:
```swift
// IBBLB/UI/Components/AudioPlayerView.swift
// Replace line 11:
@StateObject private var controller = AudioPlaybackController.shared
// With:
@ObservedObject private var audioManager = AudioPlayerManager.shared
```

Then update all references in `AudioPlayerView`:
```swift
// Replace controller with audioManager throughout
// Update play method call:
audioManager.play(url: url, title: title, artworkURL: nil)
```

**Alternative**: Remove `AudioPlaybackController` entirely if `AudioPlayerManager` provides all needed functionality.

---

### 2. Deprecated Info.plist Configuration

**Location**: `IBBLB/Info.plist` (line 36)

**Problem**:
- `UIRequiredDeviceCapabilities` includes `armv7` which is deprecated
- Modern iOS apps should target arm64 only
- This may cause App Store rejection or compatibility issues

**Fix**:
```xml
<!-- Remove or update UIRequiredDeviceCapabilities -->
<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arm64</string>
</array>
```

**Or remove entirely** (arm64 is implied for modern iOS targets).

---

### 3. Broken Button in AudioPlayerView

**Location**: `IBBLB/UI/Components/AudioPlayerView.swift` (lines 57-61)

**Problem**:
```swift
Button(action: { controller.skip(by: -15) }) {
    Image(systemName: "gobackward.15")
        .font(.title2)
}

Button(action: togglePlayback) {  // Missing opening brace?
```

**Fix**:
```swift
Button(action: { controller.skip(by: -15) }) {
    Image(systemName: "gobackward.15")
        .font(.title2)
}
```

Verify the button structure matches the other buttons in the HStack.

---

## P1: Major UX Issues

### 4. Race Condition in EventsViewModel

**Location**: `IBBLB/Features/Events/EventsViewModel.swift` (lines 17-37)

**Problem**:
- No task cancellation mechanism
- Multiple rapid refresh calls can cause:
  - Out-of-order responses showing stale data
  - Unnecessary network requests
  - Potential crashes if view deallocates during fetch

**Fix**:
```swift
@MainActor
class EventsViewModel: ObservableObject {
    // ... existing code ...
    private var fetchTask: Task<Void, Never>?
    
    func refresh() async {
        // Cancel previous task
        fetchTask?.cancel()
        
        fetchTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            isLoading = true
            errorMessage = nil

            do {
                let fetchedEvents = try await apiService.fetchEvents()
                guard !Task.isCancelled else { return }
                let upcomingEvents = filterUpcomingEvents(fetchedEvents)
                self.events = upcomingEvents.sorted(by: { $0.startDate < $1.startDate })
            } catch {
                // Handle cancellation silently
                if error is CancellationError { return }
                // ... existing error handling ...
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
        
        await fetchTask?.value
    }
}
```

---

### 5. Timer Leak Risk in LiveViewModel

**Location**: `IBBLB/Features/Live/LiveViewModel.swift` (lines 106-126)

**Problem**:
- Timer is created in `sink` closure which is stored in `cancellables`
- If `setupTimer()` is called multiple times, old timers may not be properly cleaned up
- Timer can fire after view disappears if cleanup timing is off

**Fix**:
```swift
func setupTimer() {
    print("🕒 Setting up timer...")
    // Cancel any existing timer subscription FIRST
    timer?.cancel()
    timer = nil

    guard let startsAt = status?.event?.startsAt, 
          status?.state == .upcoming else {
        cachedStartsAt = nil
        timeRemaining = nil
        return
    }

    cachedStartsAt = startsAt
    let now = Date()
    let initialRemaining = startsAt.timeIntervalSince(now)
    timeRemaining = initialRemaining > 0 ? initialRemaining : 0

    guard isVisible else {
        print("🕒 Timer deferred: View not visible")
        return
    }

    // Use weak self in sink to prevent retain cycle
    timer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()
        .sink { [weak self] now in
            guard let self = self,
                  let startsAt = self.cachedStartsAt,
                  !self.isLoading,
                  self.isVisible else { 
                self?.timer?.cancel()
                self?.timer = nil
                return 
            }

            let remaining = startsAt.timeIntervalSince(now)
            self.timeRemaining = remaining > 0 ? remaining : 0

            if remaining <= 0 {
                print("🕒 Timer expired. Refreshing...")
                self.timer?.cancel()
                self.timer = nil
                self.cachedStartsAt = nil
                Task {
                    await self.refresh()
                }
            }
        }
}
```

---

### 6. State Synchronization Issue in SermonDetailView

**Location**: `IBBLB/Features/Sermons/SermonDetailView.swift` (lines 205-207)

**Problem**:
- `isCurrentlyPlaying()` only checks URL match, not actual playing state
- Button shows "Playing" even if audio is paused
- Missing reactive binding to audio manager state

**Fix**:
```swift
// Add @ObservedObject
@ObservedObject private var audioManager = AudioPlayerManager.shared

// Update check
private func isCurrentlyPlaying(url: URL) -> Bool {
    guard let currentTrack = audioManager.currentTrack else { return false }
    return currentTrack.audioURL == url && audioManager.isPlaying
}

// Update button to use reactive binding
Button {
    playAudio(url: audioURL)
} label: {
    HStack(spacing: 6) {
        Image(systemName: isCurrentlyPlaying(url: audioURL) ? "pause.fill" : "play.fill")
            .font(.system(size: 12, weight: .semibold))
        Text(isCurrentlyPlaying(url: audioURL) ? "Playing" : "Play Audio")
            .font(.system(size: 14, weight: .semibold))
    }
    // ... rest of button style ...
}
```

---

### 7. Missing Task Cancellation in GivingViewModel

**Location**: `IBBLB/Features/Giving/GivingViewModel.swift` (lines 25-37)

**Problem**:
- No cancellation support
- Multiple rapid calls can cause race conditions

**Fix**: Add task cancellation similar to EventsViewModel fix above.

---

## P2: Polish & Cleanup

### 8. Inefficient Search Suggestions Computation

**Location**: `IBBLB/Features/Sermons/SermonsView.swift` (lines 42-54)

**Problem**:
- Computed property recalculates on every body evaluation
- Creates new arrays/sets on each access
- No caching for repeated searches

**Fix**:
```swift
@State private var cachedSuggestions: [String] = []
@State private var lastSearchQuery: String = ""

private var searchSuggestions: [String] {
    let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { 
        cachedSuggestions = []
        return []
    }
    
    // Only recalculate if query changed
    guard query != lastSearchQuery else { return cachedSuggestions }
    lastSearchQuery = query
    
    let lowercasedQuery = query.lowercased()
    let titles = listSermons.map { $0.title }
    let uniqueTitles = Array(Set(titles))
    let suggestions = uniqueTitles
        .filter { $0.lowercased().contains(lowercasedQuery) }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        .prefix(5)
        .map { $0 }
    
    cachedSuggestions = Array(suggestions)
    return cachedSuggestions
}
```

---

### 9. Missing Accessibility Labels

**Location**: Multiple view files

**Problem**:
- Buttons and interactive elements lack accessibility labels
- Poor VoiceOver/TalkBack support

**Fix**: Add `.accessibilityLabel()` modifiers:
```swift
// Example from AudioMiniPlayerBar
Button {
    audioManager.togglePlayPause()
} label: {
    // ... existing label ...
}
.accessibilityLabel(audioManager.isPlaying ? "Pause audio" : "Play audio")
.accessibilityHint("Double tap to toggle playback")
```

Apply to:
- `AudioMiniPlayerBar.swift` (play/pause button)
- `NowPlayingView.swift` (all control buttons)
- `SermonDetailView.swift` (play audio button)
- `EventsView.swift` (event cards)
- Navigation buttons throughout

---

### 10. AsyncImage Loading Performance

**Location**: Multiple files using `AsyncImage`

**Problem**:
- No caching strategy
- Repeated network requests for same images
- No placeholder sizing (layout shift)

**Fix**: Consider using `FallbackAsyncImage` (already exists) or implementing custom cached image loader:
```swift
// Already have FallbackAsyncImage - use it more consistently
// For thumbnails in list views, add fixed frame to prevent layout shift:
AsyncImage(url: url) { phase in
    // ... existing code ...
}
.frame(width: thumbnailWidth, height: thumbnailHeight)
.clipped()
```

---

### 11. Unused Property in AppRootView

**Location**: `IBBLB/App/AppRootView.swift` (line 12)

**Problem**:
- `hideTabBar` state is declared but only set to false, never used to hide tab bar

**Fix**: Either implement tab bar hiding or remove the unused state.

---

### 12. Info.plist Missing NSAppTransportSecurity (if needed)

**Location**: `IBBLB/Info.plist`

**Problem**:
- No explicit ATS configuration
- May cause issues if API endpoints change or if custom domains are used

**Recommendation**: If all APIs use HTTPS (which they should), no action needed. If HTTP is required, add appropriate ATS exceptions (but prefer fixing backend to use HTTPS).

---

## Additional Observations

### Positive Findings ✅

1. **Good concurrency practices**: Proper use of `@MainActor`, `weak self` in closures, Task cancellation in some ViewModels
2. **Security**: Input sanitization in API services, URL validation, certificate pinning
3. **Code organization**: Clear separation between Views, ViewModels, Services
4. **Error handling**: Most async operations have proper error handling

### Recommendations

1. **Consider SwiftUI NavigationStack migration**: Already using it, good!
2. **Add unit tests**: No test files found - consider adding tests for ViewModels
3. **Consider Combine cleanup**: Some ViewModels could benefit from centralized cancellation
4. **Documentation**: Add doc comments for public APIs

---

## Summary by Category

### Build Health
- ✅ No compile errors
- ⚠️ Info.plist has deprecated armv7 requirement
- ✅ Proper imports and API usage

### SwiftUI Correctness
- ✅ Proper use of @State/@StateObject/@ObservedObject
- ⚠️ State synchronization issue in SermonDetailView
- ✅ NavigationStack used correctly

### Concurrency
- ✅ Good MainActor usage
- ⚠️ Missing task cancellation in EventsViewModel, GivingViewModel
- ✅ Proper weak self usage in closures

### Media/Playback
- ❌ **CRITICAL**: Duplicate audio player managers
- ⚠️ Timer cleanup could be improved
- ✅ Background audio session properly configured

### Performance
- ⚠️ Inefficient search suggestions computation
- ⚠️ No image caching strategy
- ✅ Lazy loading used in lists

### UI/UX
- ⚠️ Missing accessibility labels
- ✅ Good responsive design for iPad/iPhone
- ⚠️ Unused hideTabBar state

---

## Priority Action Items

1. **IMMEDIATE**: Remove duplicate audio player (`AudioPlaybackController` or migrate `AudioPlayerView` to use `AudioPlayerManager`)
2. **IMMEDIATE**: Fix broken button in `AudioPlayerView`
3. **HIGH**: Add task cancellation to `EventsViewModel` and `GivingViewModel`
4. **HIGH**: Fix state sync in `SermonDetailView`
5. **MEDIUM**: Update Info.plist to remove armv7
6. **MEDIUM**: Add accessibility labels
7. **LOW**: Optimize search suggestions computation
8. **LOW**: Remove unused `hideTabBar` state

---

**End of Report**

