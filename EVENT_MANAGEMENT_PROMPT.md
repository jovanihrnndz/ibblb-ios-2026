# Event Management Fix - Prompt for Claude

## Context
This is a SwiftUI iOS app for a church (IBBLB) that displays events to users. The app fetches events from Sanity.io CMS and displays them in an `EventsView`.

## Current Problem

**Issue**: Past events are being displayed to users, but the UI suggests only upcoming events should be shown.

### Current Behavior
1. Events are fetched from Sanity.io with a GROQ query that retrieves ALL events (no date filtering)
2. Events are sorted by `startDate` ascending in the ViewModel
3. Past events appear first in the list (since they have earlier dates)
4. The empty state message says "No hay eventos próximos" (No upcoming events), implying only future events should be shown
5. There's no visual indication that an event has passed
6. Users can still interact with past events (view details, add to calendar, etc.)

### Code Locations
- **Event Model**: `IBBLB/Models/Event.swift` - Contains `startDate` and `endDate` properties
- **API Service**: `IBBLB/Services/MobileAPIService.swift` - `fetchEvents()` method (line 199-203)
- **ViewModel**: `IBBLB/Features/Events/EventsViewModel.swift` - `refresh()` method (line 17-36)
- **View**: `IBBLB/Features/Events/EventsView.swift` - Displays events and empty state

## Required Fix

### Primary Goal
Filter out past events so only upcoming/future events are displayed to users.

### Implementation Options

**Option 1: Client-side filtering (Recommended)**
- Filter events in `EventsViewModel.refresh()` after fetching
- Compare `event.startDate` (or `event.endDate` if available) with current date
- Only include events where the date is >= today
- This allows flexibility for future features (e.g., toggle to show past events)

**Option 2: Server-side filtering**
- Modify the GROQ query in `MobileAPIService.SanityEndpoint.events` to filter by date
- Add a date filter to the query: `startDate >= now()`
- More efficient but less flexible

### Additional Considerations

1. **Date comparison logic**: 
   - Should we use `startDate` or `endDate` for comparison?
   - Should we compare just the date (ignoring time) or include time?
   - Consider timezone handling

2. **Visual indicators** (Optional enhancement):
   - Could add a visual indicator (e.g., grayed out, badge) for events that are happening today vs future
   - Could add a section separator for "Today" vs "Upcoming"

3. **Edge cases**:
   - Events happening today (should they be shown?)
   - Events with no `endDate` (use `startDate` only)
   - Multi-day events (should they be shown if they started in the past but haven't ended?)

4. **User experience**:
   - The empty state message already suggests "upcoming events" - this fix aligns the behavior with the message
   - Consider if users should be able to view past events (maybe in a separate section or view)

## Expected Outcome

After the fix:
- Only events with `startDate >= today` (or `endDate >= today` if event is multi-day) should be displayed
- Past events should be filtered out
- The empty state should appear when there are truly no upcoming events
- Code should be maintainable and follow existing patterns

## Code Style Requirements
- Follow existing Swift 6 and SwiftUI patterns
- Match the code style in `EventsViewModel.swift` and `MobileAPIService.swift`
- Use `@MainActor` appropriately
- Handle errors gracefully (existing error handling should remain)
- Add comments if the date comparison logic is non-trivial




