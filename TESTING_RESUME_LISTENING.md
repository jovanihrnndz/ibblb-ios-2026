# Testing Resume Listening Feature

## Quick Test Checklist

### ✅ Test 1: Basic Resume Functionality

1. **Start Playback**
   - Open the app and go to Sermons tab
   - Find a sermon with audio (has "Play Audio" button)
   - Tap "Play Audio" to start playback
   - Let it play for 10-15 seconds
   - ✅ **Check**: Audio should be playing

2. **Pause and Resume**
   - Pause the audio
   - Tap play again
   - ✅ **Check**: Audio should resume from where you paused (NOT from beginning)

3. **Close App and Reopen**
   - While audio is paused, force close the app (swipe up from app switcher)
   - Reopen the app
   - Go to Sermons tab
   - ✅ **Check**: "Continue Listening" card should appear at the top with:
     - Sermon thumbnail
     - Sermon title
     - Progress showing saved time (e.g., "0:15 of 1:05:30")
     - Resume button (play icon)
   - Tap the Resume button
   - ✅ **Check**: Audio should resume from the saved position (around 15 seconds in)

---

### ✅ Test 2: Continue Listening Card

1. **Card Appearance**
   - After playing and pausing a sermon, go to Sermons list
   - ✅ **Check**: Card appears at the top of the list
   - ✅ **Check**: Card shows correct sermon thumbnail
   - ✅ **Check**: Card shows correct sermon title
   - ✅ **Check**: Card shows saved playback time (format: "M:SS of H:MM:SS" or "M:SS")
   - ✅ **Check**: Resume button is visible and tappable

2. **Card Behavior**
   - Tap Resume button on the card
   - ✅ **Check**: Audio starts playing
   - ✅ **Check**: Audio resumes from saved position (not from beginning)
   - ✅ **Check**: Navigates to sermon detail view

3. **Card Hiding**
   - Finish listening to a sermon completely (let it play to the end, or skip to near end)
   - ✅ **Check**: Card should disappear (position is cleared when finished)
   - Or play a different sermon
   - ✅ **Check**: Card should update to show the new sermon

---

### ✅ Test 3: Position Persistence

1. **Save on Pause**
   - Play a sermon for 30 seconds
   - Pause it
   - Check the Continue Listening card
   - ✅ **Check**: Saved time shows around 30 seconds

2. **Save on Background**
   - Play a sermon for 45 seconds
   - Put app in background (home button/gesture)
   - Reopen app
   - Go to Sermons tab
   - ✅ **Check**: Continue Listening card shows time around 45 seconds

3. **Periodic Saving**
   - Play a sermon and let it run continuously
   - Check Continue Listening card after 5+ seconds
   - ✅ **Check**: Saved time updates periodically (every 5 seconds)

---

### ✅ Test 4: Edge Cases

1. **No Saved Position**
   - Fresh install or after finishing a sermon
   - ✅ **Check**: Continue Listening card should NOT appear

2. **Sermon Not in List**
   - Play a sermon that's in the list
   - Apply a search filter that removes that sermon from results
   - ✅ **Check**: Continue Listening card should NOT appear (gracefully hidden)

3. **Multiple Sermons**
   - Play Sermon A for 20 seconds, pause
   - Play Sermon B for 30 seconds, pause
   - ✅ **Check**: Continue Listening card shows Sermon B (latest)
   - Resume Sermon B
   - ✅ **Check**: Resumes from 30 seconds

4. **Finish Playback**
   - Play a sermon to completion (or skip to last 2 seconds)
   - ✅ **Check**: Continue Listening card disappears
   - ✅ **Check**: Saved position is cleared (play same sermon again, should start from beginning)

---

### ✅ Test 5: Platform-Specific

**iPhone:**
- ✅ **Check**: Continue Listening card appears in single-column list
- ✅ **Check**: Card layout is appropriate for iPhone screen size
- ✅ **Check**: Card spans full width

**iPad:**
- ✅ **Check**: Continue Listening card appears above grid layout
- ✅ **Check**: Card layout adapts for iPad (larger thumbnail, spacing)
- ✅ **Check**: Card spans full width above grid

**tvOS (if applicable):**
- ✅ **Check**: Continue Listening card does NOT appear (hidden on tvOS)

---

### ✅ Test 6: Integration with Existing Features

1. **Mini Player**
   - Start playback
   - ✅ **Check**: Mini player appears at bottom
   - Pause and close app
   - Reopen app
   - ✅ **Check**: Continue Listening card shows correct information
   - ✅ **Check**: Mini player behavior works correctly with resume

2. **Lock Screen Controls**
   - Start playback, lock device
   - Use lock screen controls to pause
   - Unlock and reopen app
   - ✅ **Check**: Continue Listening card reflects paused position

3. **Sermon Detail View**
   - Use Continue Listening card to resume
   - ✅ **Check**: Navigates to sermon detail view
   - ✅ **Check**: Audio plays from saved position
   - ✅ **Check**: Play/pause button in detail view works correctly

---

## Debug Tips

If something isn't working, check:

1. **UserDefaults** (in Xcode debugger):
   ```swift
   // Check saved values
   po UserDefaults.standard.string(forKey: "AudioPlayerManager.lastPlayedAudioURL")
   po UserDefaults.standard.double(forKey: "AudioPlayerManager.lastPlaybackTime")
   ```

2. **Console Logs**:
   - Check for any error messages related to audio playback
   - Check for concurrency warnings (should be none)

3. **Visual Inspection**:
   - Continue Listening card should appear within 1 second of opening Sermons tab
   - Progress time should match actual playback time
   - Card should update when switching between sermons

---

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| Play sermon for 15s, pause | Saved position = ~15s |
| Close app, reopen | Continue Listening card appears |
| Tap Resume on card | Audio resumes from saved position |
| Play to end | Card disappears, position cleared |
| Play different sermon | Card updates to new sermon |
| Search/filter sermons | Card hides if sermon not in results |

---

## Common Issues & Solutions

**Issue**: Card doesn't appear after pausing
- **Check**: Is there actually audio playing? (some sermons may not have audio)
- **Check**: Did you pause (not stop)? Stopping clears the position

**Issue**: Resume starts from beginning
- **Check**: Did playback finish? Finished playback clears position
- **Check**: Is it the same sermon? Position is per-sermon (by URL)

**Issue**: Card shows wrong time
- **Check**: Time updates every 5 seconds, so slight delay is normal
- **Check**: Ensure you waited for periodic save (5+ seconds of playback)

