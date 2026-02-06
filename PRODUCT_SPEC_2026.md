# IBBLB iOS App Enhancement Specification
## Product Roadmap 2026 - Q1/Q2

**Document Version:** 1.0
**Last Updated:** February 5, 2026
**Author:** Product Review Team
**Status:** Draft for Review

---

## Executive Summary

This specification outlines 10 enhancement features for the IBBLB iOS church app, prioritized by user impact and strategic value. These features emerged from a comprehensive user experience evaluation conducted from a church member's perspective.

**Goals:**
- Increase weekly active users by 40%
- Improve sermon engagement and sharing
- Reduce friction in the giving experience
- Strengthen week-to-week church connection
- Enable offline functionality for travelers

**Investment Summary:**
- **High Impact (Must-Have):** Features 1-3
- **Medium Impact (Should-Have):** Features 4-5
- **Low Impact (Nice-to-Have):** Features 6-10

---

## Feature 1: Push Notifications for New Content
**Priority:** 🔴 **P0 - Critical**
**Impact:** High | **Effort:** Medium (2-3 weeks)
**Dependencies:** Backend notification service, user permissions

### Problem Statement
Users must manually check the app to discover new sermons, events, and announcements. This creates engagement gaps and missed content. Industry data shows apps with push notifications have 88% higher engagement rates.

### User Stories

**As a regular church member:**
- I want to be notified when Sunday's sermon is uploaded so I can listen during my Monday commute
- I want reminders about upcoming events I've saved so I don't forget to attend
- I want to receive prayer requests or urgent church announcements so I can pray and stay informed

**As an infrequent attender:**
- I want occasional reminders to re-engage with sermons so I maintain spiritual consistency during busy seasons

**As an elderly member:**
- I want simple notifications that help me remember church activities without overwhelming me

### Acceptance Criteria

**Core Functionality:**
- ✅ Send push notification when new sermon is published (within 2 hours of upload)
- ✅ Send notification 24 hours before saved events
- ✅ Send notification when new church announcement is posted
- ✅ Support iOS notification settings (banner, sound, badge)
- ✅ Notifications are actionable (tap opens relevant content)
- ✅ Users can opt-in/opt-out per notification type in Settings

**Notification Types:**
1. **New Sermon Available**
   - Title: "New Sermon: [Sermon Title]"
   - Body: "Tap to watch '[Sermon Title]' from [Speaker Name]"
   - Action: Opens sermon detail page
   - Timing: 2 hours after sermon upload (default: Sunday 8 PM)

2. **Event Reminder**
   - Title: "Reminder: [Event Name] Tomorrow"
   - Body: "[Event Name] starts tomorrow at [Time]. Tap for details."
   - Action: Opens event detail page
   - Timing: 24 hours before event start

3. **Church Announcement**
   - Title: "Church Update: [Announcement Title]"
   - Body: "[First 80 characters of announcement]"
   - Action: Opens News tab
   - Timing: Immediate (for urgent) or batched (for non-urgent)

4. **Continue Listening Reminder** (Optional)
   - Title: "Continue Listening"
   - Body: "Pick up where you left off in '[Sermon Title]'"
   - Action: Opens Now Playing with queued sermon
   - Timing: Daily at 7 AM (user-configurable)

**Settings UI:**
- Add "Notifications" section in app Settings
- Toggle switches for each notification type:
  - [ ] New Sermons (default: ON)
  - [ ] Event Reminders (default: ON)
  - [ ] Church Announcements (default: ON)
  - [ ] Continue Listening Reminders (default: OFF)
- Time preference for sermon notifications (dropdown: 6 PM, 8 PM, 10 PM)
- "Quiet Hours" setting (no notifications between 10 PM - 7 AM)

**Edge Cases:**
- If user denies notification permissions, show in-app prompt explaining benefits
- If notification fails to send, log error and retry once after 30 minutes
- If user hasn't opened app in 30 days, send re-engagement notification
- If user taps notification but content is unavailable (deleted sermon), show friendly error

### Technical Implementation

**Backend Requirements:**
1. **Notification Service:**
   - Firebase Cloud Messaging (FCM) or APNs (Apple Push Notification service)
   - Store device tokens in Supabase `user_devices` table
   - Admin dashboard to trigger manual announcements

2. **Database Schema:**
   ```sql
   CREATE TABLE user_devices (
     id UUID PRIMARY KEY,
     device_token TEXT NOT NULL,
     platform TEXT NOT NULL, -- 'ios', 'android', 'web'
     notification_preferences JSONB DEFAULT '{"sermons": true, "events": true, "announcements": true, "reminders": false}',
     created_at TIMESTAMP DEFAULT NOW(),
     last_active TIMESTAMP DEFAULT NOW()
   );

   CREATE TABLE notification_log (
     id UUID PRIMARY KEY,
     device_id UUID REFERENCES user_devices(id),
     notification_type TEXT NOT NULL,
     title TEXT,
     body TEXT,
     content_id UUID, -- sermon_id, event_id, or announcement_id
     sent_at TIMESTAMP DEFAULT NOW(),
     opened BOOLEAN DEFAULT FALSE,
     opened_at TIMESTAMP
   );
   ```

3. **Trigger Logic:**
   - Sermon upload: Cloud Function triggers notification 2 hours after `published_at` timestamp
   - Event reminder: Cron job checks events starting in 24 hours, sends notifications
   - Announcement: Admin manually triggers via dashboard

**iOS Implementation:**
1. **App Delegate Setup:**
   - Request notification permissions on first launch (after splash screen)
   - Register device token with backend
   - Handle foreground/background notification delivery
   - Track notification opens for analytics

2. **SwiftUI Views:**
   - Add `NotificationSettingsView` with toggle switches
   - Update `SettingsView` to include Notifications section
   - Handle deep linking from notification tap

3. **Dependencies:**
   - Firebase SDK (if using FCM) or native APNs
   - UserNotifications framework
   - Background fetch capability

**Privacy Considerations:**
- Notification content should not include sensitive information (e.g., specific prayer details)
- Users must explicitly opt-in to notifications (iOS system prompt)
- Device tokens are anonymized and not tied to personal identifiers
- Users can delete their device registration via Settings → Privacy

**Testing Checklist:**
- [ ] Notification appears when app is in foreground
- [ ] Notification appears when app is in background
- [ ] Notification appears when app is terminated
- [ ] Tapping notification opens correct content
- [ ] Toggling settings in-app updates backend preferences
- [ ] Quiet Hours prevents notifications during configured times
- [ ] Uninstalling app removes device token from backend
- [ ] Notification badge count updates correctly

### Success Metrics
- **Primary:** 50% of users opt-in to sermon notifications within 30 days
- **Secondary:** 30% increase in sermon views within 24 hours of publish
- **Tertiary:** 25% increase in event attendance (measured by calendar adds)

### Design Mockups Needed
- [ ] iOS notification permission prompt (custom explanation)
- [ ] Notification Settings screen
- [ ] In-app notification banner (when app is open)

---

## Feature 2: Sermon Sharing via iOS Share Sheet
**Priority:** 🔴 **P0 - Critical**
**Impact:** High | **Effort:** Low (1 week)
**Dependencies:** Web landing page for shared links

### Problem Statement
Users cannot easily share sermons with friends, family, or small group members. This limits the app's evangelism potential and word-of-mouth growth. Industry data shows content sharing increases engagement by 40% and drives 25% of new app installs.

### User Stories

**As a church member:**
- I want to share a sermon via text message to a friend going through a tough time
- I want to post a sermon link on social media to invite others to church
- I want to AirDrop a sermon to my spouse so we can discuss it together

**As a small group leader:**
- I want to share this week's sermon with my small group via email for homework

**As an evangelistically-minded member:**
- I want to share sermons with non-Christian friends as a gentle introduction to the Gospel

### Acceptance Criteria

**Core Functionality:**
- ✅ Share button (iOS share icon) visible on sermon detail page
- ✅ Tapping share button opens iOS share sheet with options
- ✅ Generate shareable URL (e.g., `https://ibblb.org/sermons/123`)
- ✅ Shared link includes rich preview (sermon thumbnail, title, speaker, scripture)
- ✅ Web landing page displays sermon video and description for non-app users
- ✅ Universal link opens app if installed, web if not
- ✅ Track shares for analytics (optional)

**Share Sheet Options:**
- Messages (iMessage/SMS)
- Mail (email)
- Copy Link
- AirDrop
- Social media (if user has apps installed: Twitter, Facebook, Instagram)
- More... (system-provided options)

**Shared Link Format:**
```
Title: [Sermon Title] - IBBLB Church
URL: https://ibblb.org/sermons/[sermon_id]
Preview:
  - Thumbnail: [sermon_thumbnail_url]
  - Description: "[Speaker Name] preaches on [scripture_passage] - [first 100 chars of description]"
```

**Web Landing Page:**
- Displays sermon title, speaker, date, scripture
- Embedded YouTube video player
- "Download the IBBLB App" banner with App Store link
- Sermon description and outline (if available)
- Related sermons sidebar
- SEO optimized (Open Graph tags, Twitter Card)

**Edge Cases:**
- If sermon video is private/unlisted, share link shows "This sermon is not available"
- If user shares before sermon fully loads, show loading state
- If network fails during share, show error toast

### Technical Implementation

**iOS Implementation:**
1. **Share Button in SermonDetailView:**
   ```swift
   Button(action: {
       showShareSheet = true
   }) {
       Label("Share", systemImage: "square.and.arrow.up")
   }
   .sheet(isPresented: $showShareSheet) {
       ShareSheet(activityItems: [generateShareURL()])
   }
   ```

2. **ShareSheet Wrapper:**
   ```swift
   struct ShareSheet: UIViewControllerRepresentable {
       let activityItems: [Any]

       func makeUIViewController(context: Context) -> UIActivityViewController {
           let controller = UIActivityViewController(
               activityItems: activityItems,
               applicationActivities: nil
           )
           return controller
       }
   }
   ```

3. **URL Generation:**
   ```swift
   func generateShareURL(for sermon: Sermon) -> URL {
       let baseURL = "https://ibblb.org/sermons"
       let shareURL = URL(string: "\(baseURL)/\(sermon.id)")!

       // Add UTM parameters for tracking
       var components = URLComponents(url: shareURL, resolvingAgainstBaseURL: false)!
       components.queryItems = [
           URLQueryItem(name: "utm_source", value: "ios_app"),
           URLQueryItem(name: "utm_medium", value: "share"),
           URLQueryItem(name: "utm_campaign", value: "sermon_share")
       ]

       return components.url!
   }
   ```

4. **Universal Link Setup:**
   - Add associated domain entitlement: `applinks:ibblb.org`
   - Backend serves `.well-known/apple-app-site-association` file
   - App handles deep link in `onOpenURL` modifier

**Backend Requirements:**
1. **Web Landing Page:**
   - Create `/sermons/[id]` route in Next.js (or existing web framework)
   - Fetch sermon data from Supabase via API
   - Render server-side for SEO and social previews

2. **Open Graph Tags:**
   ```html
   <meta property="og:title" content="[Sermon Title] - IBBLB Church" />
   <meta property="og:description" content="[Speaker Name] preaches on [scripture]" />
   <meta property="og:image" content="[thumbnail_url]" />
   <meta property="og:url" content="https://ibblb.org/sermons/[id]" />
   <meta property="og:type" content="video.other" />
   <meta name="twitter:card" content="player" />
   <meta name="twitter:player" content="[youtube_embed_url]" />
   ```

3. **Share Analytics (Optional):**
   - Log share events to backend
   - Track which sermons are shared most
   - Track conversion from shared link to app install (via UTM parameters)

**Privacy Considerations:**
- Share URLs do not expose user identity
- No tracking cookies on landing page
- Analytics are aggregated, not user-specific

**Testing Checklist:**
- [ ] Share button appears on sermon detail page
- [ ] iOS share sheet opens with all expected options
- [ ] Shared link in iMessage shows rich preview
- [ ] Shared link in email shows thumbnail
- [ ] Tapping link on iOS with app installed opens app
- [ ] Tapping link on iOS without app opens Safari
- [ ] Tapping link on Android/desktop opens web landing page
- [ ] Web landing page video plays correctly
- [ ] Universal link deep linking works from Safari, Messages, Mail

### Success Metrics
- **Primary:** 15% of sermon views result in a share within 7 days
- **Secondary:** 10% of new app installs come from shared links (UTM tracking)
- **Tertiary:** Most-shared sermons identified for homepage promotion

### Design Mockups Needed
- [ ] Share button placement on sermon detail page (top-right toolbar)
- [ ] Web landing page design (desktop and mobile)

---

## Feature 3: In-App Giving with Apple Pay
**Priority:** 🔴 **P1 - High**
**Impact:** Medium-High | **Effort:** High (3-4 weeks)
**Dependencies:** Payment processor integration, legal/compliance review

### Problem Statement
The current Sharefaith Giving redirect creates friction—users leave the app, must re-enter payment info, and often abandon the process. Industry data shows in-app payments have 3x higher conversion than web redirects, and Apple Pay increases mobile donations by 25-40%.

### User Stories

**As a regular tither:**
- I want to set up recurring donations via Apple Pay in 2 taps
- I want my giving total to automatically update after each donation

**As a spontaneous giver:**
- I want to give immediately after a powerful sermon without leaving the app
- I want to use Face ID to authorize donations for security

**As a first-time visitor:**
- I want to give a small amount ($10-$20) to support the church without creating an account

### Acceptance Criteria

**Core Functionality:**
- ✅ "Give Now" button in Giving tab
- ✅ Pre-filled donation amounts: $20, $50, $100, $250, Custom
- ✅ Apple Pay integration (one-tap checkout with Face ID/Touch ID)
- ✅ Donation confirmation screen with amount and optional note
- ✅ Email receipt sent after successful donation (for tax purposes)
- ✅ Total giving display updates in real-time after donation
- ✅ Keep Sharefaith Giving link for recurring donations and account management

**Donation Flow:**
1. User taps "Give Now" in Giving tab
2. Sheet slides up with donation amounts (pill-shaped buttons)
3. User selects amount or enters custom amount
4. Optional: Add note/designation ("General Fund", "Missions", "Building Fund")
5. User taps "Give with Apple Pay" button
6. Face ID prompt appears
7. Donation processes (loading spinner)
8. Success screen: "Thank you! Your $[amount] gift has been received."
9. Email receipt sent within 30 seconds

**Apple Pay Sheet:**
- Church name: "IBBLB Church"
- Merchant ID: Validated by Apple
- Amount: $[selected_amount]
- Billing info: Auto-filled from Apple Wallet
- Confirmation: Face ID/Touch ID

**Edge Cases:**
- If Apple Pay is not set up, show "Set Up Apple Pay" button that opens iOS Wallet
- If payment fails (declined card), show friendly error and retry option
- If network times out, show "Processing... This may take a moment" and poll backend
- If user cancels Apple Pay sheet, return to amount selection
- If donation succeeds but email fails, log error and send receipt via backend retry

### Technical Implementation

**iOS Implementation:**
1. **Dependencies:**
   - PassKit framework (Apple Pay)
   - Stripe iOS SDK (or payment processor of choice)
   - StoreKit (for App Store receipt validation if needed)

2. **GivingView Updates:**
   ```swift
   struct GivingView: View {
       @State private var selectedAmount: Int?
       @State private var customAmount: String = ""
       @State private var showApplePay = false
       @State private var donationNote: String = ""

       let presetAmounts = [20, 50, 100, 250]

       var body: some View {
           VStack(spacing: 20) {
               // Existing total giving display

               Text("Give Now")
                   .font(.title2)

               // Preset amounts
               LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                   ForEach(presetAmounts, id: \.self) { amount in
                       Button("$\(amount)") {
                           selectedAmount = amount
                       }
                       .buttonStyle(AmountButtonStyle(isSelected: selectedAmount == amount))
                   }
               }

               // Custom amount
               TextField("Custom Amount", text: $customAmount)
                   .keyboardType(.numberPad)
                   .textFieldStyle(.roundedBorder)

               // Optional note
               TextField("Add a note (optional)", text: $donationNote)
                   .textFieldStyle(.roundedBorder)

               // Apple Pay button
               Button(action: { showApplePay = true }) {
                   HStack {
                       Image(systemName: "applelogo")
                       Text("Give with Apple Pay")
                   }
               }
               .buttonStyle(ApplePayButtonStyle())
               .disabled(selectedAmount == nil && customAmount.isEmpty)

               Divider()

               // Existing Sharefaith link for recurring donations
               Link("Manage Recurring Donations", destination: SharefaithGivingURL)
           }
           .sheet(isPresented: $showApplePay) {
               ApplePaySheet(amount: getAmount(), note: donationNote)
           }
       }
   }
   ```

3. **Apple Pay Integration:**
   ```swift
   import PassKit

   class DonationManager: NSObject, PKPaymentAuthorizationViewControllerDelegate {
       func presentApplePay(amount: Decimal, note: String) {
           let request = PKPaymentRequest()
           request.merchantIdentifier = "merchant.com.ibblb.app"
           request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
           request.merchantCapabilities = .capability3DS
           request.countryCode = "US"
           request.currencyCode = "USD"

           request.paymentSummaryItems = [
               PKPaymentSummaryItem(label: "Donation", amount: NSDecimalNumber(decimal: amount)),
               PKPaymentSummaryItem(label: "IBBLB Church", amount: NSDecimalNumber(decimal: amount))
           ]

           let controller = PKPaymentAuthorizationViewController(paymentRequest: request)
           controller?.delegate = self
           // Present controller
       }

       func paymentAuthorizationViewController(
           _ controller: PKPaymentAuthorizationViewController,
           didAuthorizePayment payment: PKPayment,
           handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
       ) {
           // Send payment token to backend
           processDonation(payment: payment) { result in
               completion(result)
           }
       }
   }
   ```

**Backend Requirements:**
1. **Payment Processor:**
   - Stripe (recommended for nonprofits, 2.2% + $0.30 fee)
   - OR Braintree (PayPal-owned, supports Apple Pay)
   - Must support Apple Pay and have PCI compliance

2. **API Endpoints:**
   ```
   POST /api/donations/create
   Body: {
       "amount": 5000, // cents
       "payment_method": "apple_pay",
       "payment_token": "[stripe_token]",
       "note": "General fund",
       "device_id": "[device_uuid]"
   }
   Response: {
       "id": "[donation_id]",
       "status": "succeeded",
       "receipt_url": "https://...",
       "receipt_email": "sent"
   }
   ```

3. **Database Schema:**
   ```sql
   CREATE TABLE donations (
     id UUID PRIMARY KEY,
     amount INTEGER NOT NULL, -- cents
     payment_method TEXT NOT NULL, -- 'apple_pay', 'sharefaith'
     payment_processor_id TEXT, -- stripe transaction ID
     note TEXT,
     device_id UUID,
     receipt_email_sent BOOLEAN DEFAULT FALSE,
     created_at TIMESTAMP DEFAULT NOW()
   );
   ```

4. **Email Receipt:**
   - Use SendGrid or AWS SES
   - Template includes: donation amount, date, church tax ID (EIN), IRS donation statement
   - PDF receipt attachment (optional, for tax filing)

**Legal & Compliance:**
- ✅ Church must have Apple Developer Program enrollment ($99/year)
- ✅ Church must register as nonprofit with payment processor for reduced fees
- ✅ Receipts must comply with IRS requirements (501(c)(3) acknowledgment)
- ✅ Terms of service must include donation refund policy
- ✅ PCI DSS compliance handled by Stripe (not church's responsibility)

**Privacy Considerations:**
- Payment info (card numbers) is never stored on church servers (tokenized by Stripe)
- Donation history is stored locally on device only (not synced to backend unless user creates account)
- Email address is only used for receipt (not marketing unless user opts in)

**Testing Checklist:**
- [ ] Apple Pay button appears only if Apple Pay is set up
- [ ] Preset amounts select correctly
- [ ] Custom amount input only accepts numbers
- [ ] Apple Pay sheet shows correct amount and merchant name
- [ ] Face ID prompt appears (or Touch ID on older devices)
- [ ] Successful donation shows confirmation screen
- [ ] Email receipt arrives within 30 seconds
- [ ] Total giving display updates after donation
- [ ] Failed payment shows clear error message
- [ ] Canceling Apple Pay returns to amount selection
- [ ] Test with Stripe test cards (4242 4242 4242 4242, etc.)
- [ ] Refund flow works (admin-initiated from dashboard)

### Success Metrics
- **Primary:** 25% increase in total monthly giving within 3 months
- **Secondary:** 40% of app donations use Apple Pay (vs. Sharefaith redirect)
- **Tertiary:** Average donation amount increases by 15% (due to reduced friction)

### Design Mockups Needed
- [ ] Giving tab with "Give Now" section
- [ ] Amount selection sheet (preset + custom)
- [ ] Donation confirmation screen
- [ ] Email receipt template

---

## Feature 4: Offline Sermon Downloads
**Priority:** 🟡 **P1 - High**
**Impact:** Medium | **Effort:** Medium (2-3 weeks)
**Dependencies:** Local storage management, background download handling

### Problem Statement
Users cannot listen to sermons on flights, road trips through rural areas, or when conserving mobile data. This limits engagement for frequent travelers and members with limited data plans. Industry data shows apps with offline support have 20% higher retention rates.

### User Stories

**As a frequent traveler:**
- I want to download Sunday's sermon before my Monday flight so I can listen without WiFi
- I want to manage downloaded sermons to avoid filling my phone storage

**As a commuter with limited data:**
- I want to download sermons on WiFi at home and listen during my cellular commute

**As a missionary or international user:**
- I want to download multiple sermons while connected to WiFi and listen throughout the week in areas with poor internet

### Acceptance Criteria

**Core Functionality:**
- ✅ Download button (↓ icon) appears next to each sermon in sermon list and detail page
- ✅ Tapping download button queues sermon audio for download
- ✅ Progress indicator shows download percentage
- ✅ Downloaded sermons appear in "My Downloads" section in Sermons tab
- ✅ Downloaded sermons play instantly without buffering
- ✅ Downloaded sermons show checkmark icon and "Downloaded" badge
- ✅ User can delete individual downloads or clear all downloads
- ✅ Settings allow user to configure auto-delete after X days (7, 14, 30, Never)
- ✅ Settings show total storage used by downloads
- ✅ Low storage warning if downloads exceed 500 MB

**Download States:**
- **Not Downloaded:** Download button (↓) visible
- **Downloading:** Progress circle with percentage (e.g., "45%") and cancel button (×)
- **Downloaded:** Checkmark icon (✓) and "Delete Download" button in detail view
- **Failed:** Error icon with "Retry" button

**My Downloads Section:**
- Accessible via filter button in Sermons tab (new "Downloaded" filter option)
- Shows all downloaded sermons sorted by download date (most recent first)
- Each sermon shows: thumbnail, title, speaker, date, file size, download date
- Swipe-to-delete gesture to remove download
- "Clear All Downloads" button at bottom (with confirmation alert)
- Empty state: "No downloads yet. Download sermons to listen offline."

**Settings UI:**
- Add "Downloads" section in app Settings
- Toggle: "Download over Cellular Data" (default: OFF)
- Dropdown: "Auto-delete after" (7 days, 14 days, 30 days, Never)
- Display: "Storage Used: [X] MB of [available space]"
- Button: "Clear All Downloads" with confirmation

**Edge Cases:**
- If storage is full, show error: "Not enough space. Delete downloads or free up storage."
- If download fails (network issue), show "Download failed. Retry?" with retry button
- If user starts playing sermon while downloading, switch to streaming (pause download)
- If app is killed during download, resume download on next launch
- If downloaded sermon is deleted from backend, show "This sermon is no longer available" and auto-delete local file

### Technical Implementation

**iOS Implementation:**
1. **Download Manager:**
   ```swift
   class SermonDownloadManager: ObservableObject {
       @Published var downloads: [SermonDownload] = []
       @Published var downloadProgress: [String: Double] = [:] // sermon_id: progress

       private let fileManager = FileManager.default
       private let downloadsDirectory: URL = {
           let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
           return documentDirectory.appendingPathComponent("SermonDownloads", isDirectory: true)
       }()

       func downloadSermon(_ sermon: Sermon) {
           guard let audioURL = sermon.audioURL else { return }

           let task = URLSession.shared.downloadTask(with: audioURL) { [weak self] localURL, response, error in
               guard let localURL = localURL, error == nil else {
                   self?.handleDownloadError(sermon: sermon, error: error)
                   return
               }

               self?.saveDownloadedFile(sermon: sermon, from: localURL)
           }

           // Observe download progress
           task.resume()
       }

       func deleteDownload(sermon: Sermon) {
           let filePath = downloadsDirectory.appendingPathComponent("\(sermon.id).m4a")
           try? fileManager.removeItem(at: filePath)
           downloads.removeAll { $0.sermonID == sermon.id }
       }

       func isDownloaded(sermon: Sermon) -> Bool {
           downloads.contains { $0.sermonID == sermon.id }
       }
   }

   struct SermonDownload: Codable, Identifiable {
       let id: UUID
       let sermonID: String
       let title: String
       let speaker: String
       let thumbnailURL: String?
       let filePath: URL
       let fileSize: Int64 // bytes
       let downloadedAt: Date
   }
   ```

2. **UI Updates:**
   ```swift
   // In SermonRowView
   HStack {
       // Existing sermon info

       Spacer()

       if downloadManager.isDownloaded(sermon: sermon) {
           Image(systemName: "checkmark.circle.fill")
               .foregroundColor(.green)
       } else {
           Button(action: { downloadManager.downloadSermon(sermon) }) {
               Image(systemName: "arrow.down.circle")
           }
       }
   }

   // Download progress overlay
   if let progress = downloadManager.downloadProgress[sermon.id] {
       ProgressView(value: progress) {
           Text("\(Int(progress * 100))%")
       }
   }
   ```

3. **My Downloads View:**
   ```swift
   struct MyDownloadsView: View {
       @EnvironmentObject var downloadManager: SermonDownloadManager

       var body: some View {
           List {
               ForEach(downloadManager.downloads) { download in
                   DownloadedSermonRow(download: download)
                       .swipeActions {
                           Button(role: .destructive) {
                               downloadManager.deleteDownload(sermonID: download.sermonID)
                           } label: {
                               Label("Delete", systemImage: "trash")
                           }
                       }
               }

               if !downloadManager.downloads.isEmpty {
                   Button("Clear All Downloads") {
                       showClearAllAlert = true
                   }
                   .foregroundColor(.red)
               }
           }
           .overlay {
               if downloadManager.downloads.isEmpty {
                   ContentUnavailableView(
                       "No Downloads",
                       systemImage: "arrow.down.circle",
                       description: Text("Download sermons to listen offline")
                   )
               }
           }
       }
   }
   ```

4. **Background Download Support:**
   - Enable "Background Modes" capability (Background fetch)
   - Use `URLSessionConfiguration.background` for downloads
   - Handle app termination/suspension gracefully
   - Resume incomplete downloads on app relaunch

5. **Storage Management:**
   ```swift
   func calculateTotalStorageUsed() -> Int64 {
       var totalSize: Int64 = 0
       let downloads = try? fileManager.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: [.fileSizeKey])
       downloads?.forEach { url in
           if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
               totalSize += Int64(fileSize)
           }
       }
       return totalSize
   }

   func autoDeleteOldDownloads(olderThan days: Int) {
       let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
       downloads.filter { $0.downloadedAt < cutoffDate }.forEach { download in
           deleteDownload(sermonID: download.sermonID)
       }
   }
   ```

**Backend Requirements:**
- None (downloads are purely client-side)
- Ensure audio files are accessible via direct URL (no authentication required)
- Consider CDN for faster downloads (currently using YouTube audio extraction?)

**Privacy Considerations:**
- Downloaded files are stored locally on device only (not synced to iCloud by default)
- User can enable iCloud sync in iOS Settings if desired
- No download tracking sent to backend (respects user privacy)

**Testing Checklist:**
- [ ] Download button appears on sermon list and detail pages
- [ ] Tapping download starts download with progress indicator
- [ ] Downloaded sermon plays instantly without buffering
- [ ] Checkmark icon appears after successful download
- [ ] My Downloads section shows all downloaded sermons
- [ ] Swipe-to-delete removes download from list and storage
- [ ] "Clear All Downloads" deletes all files and clears list
- [ ] Settings show accurate storage usage
- [ ] Auto-delete setting removes old downloads correctly
- [ ] Download over cellular toggle works (blocks/allows cellular downloads)
- [ ] Low storage warning appears when threshold is reached
- [ ] Background downloads resume after app is killed
- [ ] Downloaded sermon still works after device reboot

### Success Metrics
- **Primary:** 30% of weekly active users download at least 1 sermon per month
- **Secondary:** Average listening time increases by 15% (due to offline access)
- **Tertiary:** 50% of travelers use downloads (surveyed via in-app prompt)

### Design Mockups Needed
- [ ] Download button in sermon list
- [ ] Download progress indicator
- [ ] My Downloads screen
- [ ] Settings → Downloads section

---

## Feature 5: Church Announcements/News Feed
**Priority:** 🟡 **P2 - Medium**
**Impact:** Medium | **Effort:** Medium (2 weeks)
**Dependencies:** Backend CMS for announcements, admin dashboard

### Problem Statement
There's no centralized way for church staff to communicate updates, schedule changes, prayer requests, or ministry highlights to app users. Members rely on Sunday bulletins, sporadic emails, or word-of-mouth, leading to missed information and reduced engagement.

### User Stories

**As a regular member:**
- I want to see urgent announcements (weather cancellations, schedule changes) so I don't make unnecessary trips
- I want to read prayer requests so I can pray for church members throughout the week

**As a new member:**
- I want to learn about ministries and volunteer opportunities through the app

**As a small group leader:**
- I want to stay informed about church-wide events that might impact my small group schedule

### Acceptance Criteria

**Core Functionality:**
- ✅ Add "News" tab (5th tab) to bottom tab bar with newspaper icon
- ✅ Display announcements in chronological feed (most recent first)
- ✅ Each announcement card shows: title, short description, date, category badge, optional image
- ✅ Tapping announcement opens detail view with full content and optional action button
- ✅ Pull-to-refresh to fetch latest announcements
- ✅ Categories: "Urgent", "Events", "Prayer", "Ministry", "General"
- ✅ "Urgent" announcements show red badge and appear at top of feed
- ✅ Announcements can include action buttons: "Register", "Learn More", "RSVP", "Donate"
- ✅ Admin can schedule announcements to publish at future date/time

**Announcement Card Design:**
```
┌─────────────────────────────────────┐
│ [Image - optional, 16:9 ratio]     │
├─────────────────────────────────────┤
│ [URGENT] [Category Badge]           │
│ Announcement Title                  │
│ Short description (first 100 chars) │
│ 📅 Posted 2 hours ago               │
└─────────────────────────────────────┘
```

**Announcement Detail View:**
- Full-width hero image (if provided)
- Category badge
- Title (large font)
- Published date and author (e.g., "Posted by Pastor John on Jan 15")
- Full description (supports markdown formatting)
- Optional action button ("Register", "Learn More", etc.)
- Optional embedded YouTube video
- Share button (reuse Feature 2 implementation)

**Admin Dashboard Requirements:**
- Web-based admin panel (Sanity CMS or custom dashboard)
- Create/edit/delete announcements
- Fields:
  - Title (required)
  - Description (required, markdown support)
  - Category (dropdown: Urgent, Events, Prayer, Ministry, General)
  - Image (optional, upload or URL)
  - Action button label (optional)
  - Action button URL (optional)
  - Scheduled publish date (optional, default: publish immediately)
  - Expiration date (optional, auto-hide after this date)
- Preview mode before publishing
- Push notification trigger (checkbox: "Send notification to all users")

**Edge Cases:**
- If no announcements exist, show empty state: "No announcements yet. Check back soon!"
- If announcement fetch fails, show cached announcements with "Showing cached content" banner
- If announcement image fails to load, show placeholder or no image
- If scheduled announcement hasn't reached publish date, don't show in app
- If announcement has expired, hide from feed

### Technical Implementation

**iOS Implementation:**
1. **Add News Tab:**
   ```swift
   enum Tab: String, CaseIterable {
       case sermons = "Sermons"
       case live = "Live"
       case events = "Events"
       case giving = "Giving"
       case news = "News"

       var icon: String {
           switch self {
           case .sermons: return "book.fill"
           case .live: return "tv.fill"
           case .events: return "calendar"
           case .giving: return "heart.fill"
           case .news: return "newspaper.fill"
           }
       }
   }
   ```

2. **Announcement Model:**
   ```swift
   struct Announcement: Identifiable, Codable {
       let id: UUID
       let title: String
       let description: String
       let category: AnnouncementCategory
       let imageURL: String?
       let actionLabel: String?
       let actionURL: String?
       let publishedAt: Date
       let expiresAt: Date?
       let author: String?
   }

   enum AnnouncementCategory: String, Codable, CaseIterable {
       case urgent = "Urgent"
       case events = "Events"
       case prayer = "Prayer"
       case ministry = "Ministry"
       case general = "General"

       var color: Color {
           switch self {
           case .urgent: return .red
           case .events: return .blue
           case .prayer: return .purple
           case .ministry: return .green
           case .general: return .gray
           }
       }
   }
   ```

3. **NewsView:**
   ```swift
   struct NewsView: View {
       @StateObject private var viewModel = NewsViewModel()

       var body: some View {
           List {
               // Urgent announcements section
               if !viewModel.urgentAnnouncements.isEmpty {
                   Section("Urgent") {
                       ForEach(viewModel.urgentAnnouncements) { announcement in
                           AnnouncementCard(announcement: announcement)
                       }
                   }
               }

               // All announcements
               Section("Recent") {
                   ForEach(viewModel.announcements) { announcement in
                       NavigationLink(destination: AnnouncementDetailView(announcement: announcement)) {
                           AnnouncementCard(announcement: announcement)
                       }
                   }
               }
           }
           .refreshable {
               await viewModel.fetchAnnouncements()
           }
           .overlay {
               if viewModel.announcements.isEmpty && !viewModel.isLoading {
                   ContentUnavailableView(
                       "No Announcements",
                       systemImage: "newspaper",
                       description: Text("Check back soon for church updates")
                   )
               }
           }
       }
   }
   ```

4. **AnnouncementCard Component:**
   ```swift
   struct AnnouncementCard: View {
       let announcement: Announcement

       var body: some View {
           VStack(alignment: .leading, spacing: 8) {
               // Image
               if let imageURL = announcement.imageURL {
                   AsyncImage(url: URL(string: imageURL)) { image in
                       image.resizable().aspectRatio(16/9, contentMode: .fill)
                   } placeholder: {
                       Rectangle().fill(Color.gray.opacity(0.2))
                   }
                   .frame(height: 180)
                   .clipped()
               }

               // Category badge
               Text(announcement.category.rawValue)
                   .font(.caption)
                   .padding(.horizontal, 8)
                   .padding(.vertical, 4)
                   .background(announcement.category.color.opacity(0.2))
                   .foregroundColor(announcement.category.color)
                   .cornerRadius(4)

               // Title
               Text(announcement.title)
                   .font(.headline)

               // Description preview
               Text(announcement.description)
                   .font(.subheadline)
                   .foregroundColor(.secondary)
                   .lineLimit(2)

               // Metadata
               HStack {
                   Image(systemName: "calendar")
                   Text(announcement.publishedAt.timeAgoDisplay())
                   Spacer()
               }
               .font(.caption)
               .foregroundColor(.secondary)
           }
           .padding(.vertical, 8)
       }
   }
   ```

**Backend Requirements:**
1. **Database Schema:**
   ```sql
   CREATE TABLE announcements (
     id UUID PRIMARY KEY,
     title TEXT NOT NULL,
     description TEXT NOT NULL,
     category TEXT NOT NULL CHECK (category IN ('urgent', 'events', 'prayer', 'ministry', 'general')),
     image_url TEXT,
     action_label TEXT,
     action_url TEXT,
     published_at TIMESTAMP DEFAULT NOW(),
     expires_at TIMESTAMP,
     author TEXT,
     created_at TIMESTAMP DEFAULT NOW(),
     updated_at TIMESTAMP DEFAULT NOW()
   );

   CREATE INDEX idx_announcements_published ON announcements(published_at DESC);
   CREATE INDEX idx_announcements_category ON announcements(category);
   ```

2. **API Endpoints:**
   ```
   GET /api/announcements
   Query params:
     - category (optional): Filter by category
     - limit (optional): Number of announcements (default: 50)
   Response: Array of announcements sorted by published_at DESC

   GET /api/announcements/:id
   Response: Single announcement with full details
   ```

3. **Admin Dashboard:**
   - Use Sanity CMS (existing tool for sermon outlines) or build custom React admin panel
   - CRUD operations for announcements
   - Image upload to S3 or Cloudinary
   - Rich text editor with markdown support
   - Schedule future publish dates
   - Trigger push notification on publish (integrate with Feature 1)

**Privacy Considerations:**
- Prayer requests should be vetted by staff before posting (avoid HIPAA violations)
- Announcements are public (no authentication required)
- No user-generated content (admin-only posting)

**Testing Checklist:**
- [ ] News tab appears in bottom tab bar
- [ ] Announcements load and display correctly
- [ ] Pull-to-refresh fetches latest announcements
- [ ] Urgent announcements appear at top with red badge
- [ ] Tapping announcement opens detail view
- [ ] Action button (if present) navigates correctly
- [ ] Expired announcements don't appear in feed
- [ ] Empty state shows when no announcements exist
- [ ] Images load and display correctly
- [ ] Markdown formatting renders in description
- [ ] Share button works (Feature 2 integration)

### Success Metrics
- **Primary:** 50% of weekly active users check News tab at least once per week
- **Secondary:** 20% reduction in "I didn't know about that event" feedback
- **Tertiary:** Admin publishes 2-3 announcements per week on average

### Design Mockups Needed
- [ ] News tab icon in tab bar
- [ ] Announcement card in list view
- [ ] Announcement detail view
- [ ] Admin dashboard UI (web)

---

## Feature 6: Sermon Notes Feature
**Priority:** 🟢 **P3 - Low**
**Impact:** Low-Medium | **Effort:** Medium (2-3 weeks)
**Dependencies:** Cloud sync for notes (Supabase or iCloud)

### Problem Statement
Users who want to take notes during sermons must switch to a separate notes app, losing context and breaking focus. A built-in notes feature would allow members to capture insights, action items, and reflections tied to specific sermons and timestamps.

### User Stories

**As a diligent student of Scripture:**
- I want to take notes while watching a sermon so I can remember key points
- I want my notes to be tied to specific sermon timestamps so I can jump back to relevant sections

**As a small group leader:**
- I want to export my sermon notes to share with my small group

**As a visual learner:**
- I want to highlight quotes from the sermon outline and add my own thoughts

### Acceptance Criteria

**Core Functionality:**
- ✅ "Notes" button appears in sermon detail view (next to share button)
- ✅ Tapping "Notes" opens note editor overlay
- ✅ Note editor has text field with rich text formatting (bold, italic, bullet points)
- ✅ "Add Timestamp" button captures current video/audio position and inserts into notes
- ✅ Tapping timestamp in notes jumps to that point in sermon
- ✅ Notes auto-save every 30 seconds
- ✅ "My Notes" section in Sermons tab shows all sermons with notes
- ✅ Export notes via share sheet (plain text or PDF)
- ✅ Optional: Cloud sync via iCloud or Supabase (for multi-device access)

**Note Editor UI:**
```
┌──────────────────────────────────────┐
│ [Sermon Title]                [Done] │
├──────────────────────────────────────┤
│ [Add Timestamp: 12:45] [B] [I] [•]  │
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │ Point 1: Grace is unmerited      │ │
│ │ [⏱ 12:45] Key quote: "..."       │ │
│ │                                  │ │
│ │ My thoughts: This reminds me...  │ │
│ │                                  │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [Export Notes]                       │
└──────────────────────────────────────┘
```

**My Notes Section:**
- Filter option in Sermons tab: "Sermons with Notes"
- Shows sermon cards with "📝" badge
- Tapping sermon opens detail view with notes visible

**Edge Cases:**
- If user takes notes while offline, sync when online
- If note is empty, don't save
- If user closes note editor mid-edit, auto-save draft
- If sermon is deleted from backend, keep notes but show "Sermon unavailable"

### Technical Implementation

**iOS Implementation:**
1. **Note Model:**
   ```swift
   struct SermonNote: Identifiable, Codable {
       let id: UUID
       let sermonID: String
       var content: String // Markdown or plain text
       var timestamps: [NoteTimestamp] // Array of timestamp references
       var createdAt: Date
       var updatedAt: Date
   }

   struct NoteTimestamp: Identifiable, Codable {
       let id: UUID
       let time: Double // seconds
       let label: String? // Optional label (e.g., "Point 2")
   }
   ```

2. **Note Editor View:**
   ```swift
   struct SermonNoteEditor: View {
       @Binding var note: SermonNote
       @State private var content: String = ""
       let currentTime: () -> Double // Closure to get video/audio current time

       var body: some View {
           VStack {
               // Toolbar
               HStack {
                   Button("Add Timestamp") {
                       insertTimestamp()
                   }
                   Spacer()
                   Button("Done") {
                       saveNote()
                   }
               }

               // Text editor
               TextEditor(text: $content)
                   .padding()
                   .onChange(of: content) { _ in
                       autoSave()
                   }

               // Export button
               Button("Export Notes") {
                   exportNotes()
               }
           }
       }

       func insertTimestamp() {
           let time = currentTime()
           let timestamp = NoteTimestamp(id: UUID(), time: time, label: nil)
           content += "\n[⏱ \(formatTime(time))]"
           note.timestamps.append(timestamp)
       }
   }
   ```

3. **Cloud Sync (Optional):**
   - Use iCloud Key-Value Storage or iCloud Drive for simple sync
   - OR use Supabase to store notes (requires user account)
   - Conflict resolution: Last-write-wins

4. **Export Functionality:**
   ```swift
   func exportNotes(note: SermonNote) -> String {
       var export = "Notes for \(sermon.title)\n"
       export += "Speaker: \(sermon.speaker)\n"
       export += "Date: \(sermon.date)\n\n"
       export += note.content
       return export
   }
   ```

**Backend Requirements (Optional):**
- If using Supabase for sync, add `sermon_notes` table
- API endpoints for CRUD operations on notes

**Privacy Considerations:**
- Notes are private to user (not shared with church or other members)
- If syncing to cloud, encrypt notes at rest
- User can delete all notes locally

**Testing Checklist:**
- [ ] Notes button appears in sermon detail view
- [ ] Note editor opens and closes correctly
- [ ] Text editing works smoothly
- [ ] Timestamps insert correctly
- [ ] Tapping timestamp jumps to correct time in video/audio
- [ ] Auto-save works every 30 seconds
- [ ] Notes persist after app restart
- [ ] Export produces readable plain text or PDF
- [ ] Cloud sync works across devices (if implemented)

### Success Metrics
- **Primary:** 15% of sermon viewers take notes on at least 1 sermon per month
- **Secondary:** 40% of note-takers export notes (indicating they find feature useful)

### Design Mockups Needed
- [ ] Notes button in sermon detail toolbar
- [ ] Note editor overlay
- [ ] My Notes section in Sermons tab

---

## Feature 7: Sermon Series Organization
**Priority:** 🟢 **P3 - Low**
**Impact:** Low | **Effort:** Low (1 week)
**Dependencies:** Backend data model update to include series metadata

### Problem Statement
Sermons are currently displayed chronologically, making it hard to find related messages in a multi-week series (e.g., "Romans Study", "Marriage Series"). Users who missed a week or want to review a full series must scroll and search manually.

### User Stories

**As a member who missed a Sunday:**
- I want to browse all sermons in the "Ephesians Series" to catch up

**As a new member:**
- I want to watch the "Gospel 101" series from beginning to end

**As a topical learner:**
- I want to find all sermons about prayer or marriage grouped together

### Acceptance Criteria

**Core Functionality:**
- ✅ Sermons belong to a series (optional field in sermon metadata)
- ✅ "Series" tab or filter in Sermons view shows all series
- ✅ Tapping a series shows all sermons in that series (chronological order)
- ✅ Series card displays: series title, number of sermons, thumbnail (first sermon's image), date range
- ✅ Sermon cards show series badge (e.g., "Part 3 of 8 - Romans Study")
- ✅ "Continue Series" suggestion at end of sermon (auto-suggest next sermon in series)

**Series Card Design:**
```
┌─────────────────────────────────────┐
│ [Series Thumbnail]                  │
├─────────────────────────────────────┤
│ Romans Study                        │
│ 8 sermons • Jan - Feb 2026          │
└─────────────────────────────────────┘
```

**Edge Cases:**
- If sermon has no series, display as standalone sermon
- If series has only 1 sermon, don't show series view
- If user starts watching mid-series, suggest watching from beginning

### Technical Implementation

**Backend Requirements:**
1. **Database Schema Update:**
   ```sql
   CREATE TABLE sermon_series (
     id UUID PRIMARY KEY,
     title TEXT NOT NULL,
     description TEXT,
     thumbnail_url TEXT,
     start_date DATE,
     end_date DATE,
     created_at TIMESTAMP DEFAULT NOW()
   );

   ALTER TABLE sermons ADD COLUMN series_id UUID REFERENCES sermon_series(id);
   ALTER TABLE sermons ADD COLUMN series_part INTEGER; -- e.g., 1, 2, 3
   ```

2. **API Endpoints:**
   ```
   GET /api/sermon-series
   Response: Array of series with sermon count

   GET /api/sermon-series/:id/sermons
   Response: Array of sermons in series, ordered by series_part
   ```

**iOS Implementation:**
1. **Series Model:**
   ```swift
   struct SermonSeries: Identifiable, Codable {
       let id: UUID
       let title: String
       let description: String?
       let thumbnailURL: String?
       let sermonCount: Int
       let startDate: Date
       let endDate: Date?
   }
   ```

2. **Series View:**
   ```swift
   struct SeriesListView: View {
       @StateObject private var viewModel = SeriesViewModel()

       var body: some View {
           List(viewModel.series) { series in
               NavigationLink(destination: SeriesDetailView(series: series)) {
                   SeriesCard(series: series)
               }
           }
       }
   }
   ```

**Privacy Considerations:**
- None (public data)

**Testing Checklist:**
- [ ] Series tab/filter appears in Sermons view
- [ ] Series cards display correctly
- [ ] Tapping series shows all sermons in order
- [ ] Sermon cards show series badge
- [ ] "Continue Series" suggestion works

### Success Metrics
- **Primary:** 25% of sermon views come from series browsing (vs. chronological list)

### Design Mockups Needed
- [ ] Series card in list view
- [ ] Series detail view with all sermons

---

## Feature 8: Tappable Scripture References
**Priority:** 🟢 **P3 - Low**
**Impact:** Low | **Effort:** Low-Medium (1-2 weeks)
**Dependencies:** Bible API integration (e.g., ESV API, YouVersion API)

### Problem Statement
Sermon descriptions and outlines reference Bible verses (e.g., "Romans 8:28"), but users must manually open a Bible app to read them. This breaks focus and creates friction for studying alongside sermons.

### User Stories

**As a sermon viewer:**
- I want to tap "Romans 8:28" in the sermon outline and instantly read the verse
- I want to see scripture in my preferred Bible translation (ESV, NIV, NASB)

**As a new believer:**
- I want easy access to Bible verses without needing to know how to navigate a separate Bible app

### Acceptance Criteria

**Core Functionality:**
- ✅ Scripture references (e.g., "John 3:16", "Romans 8:28-30") are automatically detected and styled as links
- ✅ Tapping scripture reference opens popover with verse text
- ✅ Popover shows verse, translation name, and "Read Full Chapter" button
- ✅ "Read Full Chapter" opens Bible app (YouVersion) or web link
- ✅ User can select preferred Bible translation in Settings (ESV, NIV, NASB, KJV)

**Popover Design:**
```
┌──────────────────────────────────────┐
│ Romans 8:28 (ESV)            [✕]     │
├──────────────────────────────────────┤
│ And we know that for those who       │
│ love God all things work together    │
│ for good, for those who are called   │
│ according to his purpose.            │
│                                      │
│ [Read Full Chapter]                  │
└──────────────────────────────────────┘
```

**Edge Cases:**
- If Bible API is down, show "Unable to load verse" with fallback link to YouVersion
- If scripture reference is malformed (e.g., "John 100:1"), show error message
- If user is offline, show cached verses (if previously loaded)

### Technical Implementation

**iOS Implementation:**
1. **Scripture Detection:**
   ```swift
   func detectScriptureReferences(in text: String) -> [ScriptureReference] {
       let pattern = #"([1-3]?\s?[A-Za-z]+)\s(\d+):(\d+)(?:-(\d+))?"#
       // Regex matches: "John 3:16", "1 Corinthians 13:4-8", "Romans 8:28"
       // Parse and return array of ScriptureReference objects
   }
   ```

2. **Scripture API Integration:**
   ```swift
   class BibleService {
       let apiKey = "YOUR_ESV_API_KEY"
       let baseURL = "https://api.esv.org/v3/passage/text/"

       func fetchVerse(reference: String) async throws -> String {
           let url = URL(string: "\(baseURL)?q=\(reference)&include-footnotes=false")!
           var request = URLRequest(url: url)
           request.addValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

           let (data, _) = try await URLSession.shared.data(for: request)
           let response = try JSONDecoder().decode(ESVResponse.self, from: data)
           return response.passages.first ?? ""
       }
   }
   ```

3. **Popover View:**
   ```swift
   struct ScripturePopover: View {
       let reference: String
       @State private var verseText: String = "Loading..."

       var body: some View {
           VStack(alignment: .leading, spacing: 12) {
               Text(reference)
                   .font(.headline)

               Text(verseText)
                   .font(.body)

               Button("Read Full Chapter") {
                   openBibleApp()
               }
           }
           .padding()
           .task {
               verseText = await loadVerse(reference)
           }
       }
   }
   ```

**Backend Requirements:**
- None (uses third-party Bible APIs)

**Privacy Considerations:**
- API requests to ESV.org or YouVersion log IP addresses (standard practice)
- No user data is shared with Bible API providers

**Testing Checklist:**
- [ ] Scripture references are detected and styled as links
- [ ] Tapping reference opens popover with verse text
- [ ] Popover displays correct verse and translation
- [ ] "Read Full Chapter" button opens Bible app
- [ ] Settings allow selecting different translations
- [ ] Offline mode shows cached verses

### Success Metrics
- **Primary:** 20% of sermon outline views result in at least 1 scripture tap

### Design Mockups Needed
- [ ] Scripture popover

---

## Feature 9: Dark Mode Contrast Refinement
**Priority:** 🟢 **P4 - Trivial**
**Impact:** Low | **Effort:** Low (2-3 days)
**Dependencies:** None

### Problem Statement
Some text elements in dark mode have insufficient contrast, making them hard to read for users with vision impairments. WCAG AA standard requires 4.5:1 contrast ratio for normal text.

### User Stories

**As a user who prefers dark mode:**
- I want all text to be easily readable without eye strain

**As a user with low vision:**
- I want sufficient contrast to read metadata and secondary text

### Acceptance Criteria

**Core Functionality:**
- ✅ All text meets WCAG AA contrast standards (4.5:1 for normal text, 3:1 for large text)
- ✅ Secondary text (metadata, captions) is readable in dark mode
- ✅ Button text is clearly visible
- ✅ Test with Xcode Accessibility Inspector

**Areas to Review:**
- Sermon metadata (date, speaker) - currently `.secondary` color
- Event location text
- Giving total display
- Tab bar icons and labels
- Mini player controls

### Technical Implementation

**iOS Implementation:**
1. **Use Semantic Colors:**
   ```swift
   // Instead of hardcoded colors:
   .foregroundColor(.gray)

   // Use semantic colors:
   .foregroundColor(.secondary) // Adapts to light/dark mode
   ```

2. **Test Contrast:**
   - Use Xcode Accessibility Inspector
   - Test on physical devices in dark environments
   - Compare against WCAG standards

3. **Custom Colors (if needed):**
   ```swift
   extension Color {
       static let secondaryText = Color(light: .gray, dark: .lightGray)
   }

   extension Color {
       init(light: Color, dark: Color) {
           self.init(UIColor { traitCollection in
               traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
           })
       }
   }
   ```

**Testing Checklist:**
- [ ] All screens reviewed in dark mode
- [ ] Contrast ratios measured with Accessibility Inspector
- [ ] Text is readable on iPhone and iPad
- [ ] No pure black text on dark gray backgrounds

### Success Metrics
- **Primary:** Zero user complaints about dark mode readability
- **Secondary:** Pass WCAG AA accessibility audit

### Design Mockups Needed
- None (refinement task)

---

## Feature 10: Volunteer Sign-Up Integration
**Priority:** 🟢 **P4 - Nice-to-Have**
**Impact:** Low | **Effort:** Medium (2 weeks)
**Dependencies:** Backend volunteer management system or third-party integration (Planning Center, Church Community Builder)

### Problem Statement
Members who want to volunteer (Sunday School teacher, greeter, worship team) must contact church staff via email or phone. There's no centralized way to browse volunteer opportunities or sign up directly in the app.

### User Stories

**As a new member:**
- I want to browse volunteer opportunities so I can get involved in ministry

**As a regular volunteer:**
- I want to sign up for specific Sunday shifts as a greeter

**As a ministry leader:**
- I want to see who's signed up for my ministry and contact them easily

### Acceptance Criteria

**Core Functionality:**
- ✅ "Serve" tab or section in Events tab shows volunteer opportunities
- ✅ Each opportunity card shows: ministry name, description, time commitment, contact person
- ✅ Tapping opportunity opens detail view with "Sign Up" button
- ✅ Sign-up form collects: name, email, phone, availability
- ✅ Confirmation email sent after sign-up
- ✅ Admin dashboard shows all sign-ups

**Volunteer Opportunity Card:**
```
┌─────────────────────────────────────┐
│ [Ministry Icon]                     │
│ Sunday School Teacher               │
│ Help teach kids ages 5-8            │
│ 📅 Sundays 9-10 AM                  │
│ 👤 Contact: Jane Doe                │
│ [Sign Up]                           │
└─────────────────────────────────────┘
```

**Edge Cases:**
- If opportunity is full, show "Waitlist" button instead of "Sign Up"
- If user already signed up, show "You're signed up!" message
- If sign-up fails, show error and retry option

### Technical Implementation

**iOS Implementation:**
1. **Volunteer Model:**
   ```swift
   struct VolunteerOpportunity: Identifiable, Codable {
       let id: UUID
       let title: String
       let description: String
       let timeCommitment: String
       let contactPerson: String
       let contactEmail: String
       let slotsAvailable: Int
       let slotsTotal: Int
   }
   ```

2. **Sign-Up Form:**
   ```swift
   struct VolunteerSignUpForm: View {
       @State private var name: String = ""
       @State private var email: String = ""
       @State private var phone: String = ""
       @State private var availability: String = ""

       var body: some View {
           Form {
               TextField("Name", text: $name)
               TextField("Email", text: $email)
               TextField("Phone", text: $phone)
               TextEditor(text: $availability)

               Button("Submit") {
                   submitSignUp()
               }
           }
       }
   }
   ```

**Backend Requirements:**
1. **Database Schema:**
   ```sql
   CREATE TABLE volunteer_opportunities (
     id UUID PRIMARY KEY,
     title TEXT NOT NULL,
     description TEXT,
     time_commitment TEXT,
     contact_person TEXT,
     contact_email TEXT,
     slots_available INTEGER,
     slots_total INTEGER,
     created_at TIMESTAMP DEFAULT NOW()
   );

   CREATE TABLE volunteer_signups (
     id UUID PRIMARY KEY,
     opportunity_id UUID REFERENCES volunteer_opportunities(id),
     name TEXT NOT NULL,
     email TEXT NOT NULL,
     phone TEXT,
     availability TEXT,
     created_at TIMESTAMP DEFAULT NOW()
   );
   ```

2. **API Endpoints:**
   ```
   GET /api/volunteer-opportunities
   POST /api/volunteer-signups
   ```

**Privacy Considerations:**
- Sign-up data is stored securely (not public)
- Email is only used for confirmation and ministry contact
- User can unsubscribe from volunteer list

**Testing Checklist:**
- [ ] Volunteer opportunities display correctly
- [ ] Sign-up form validates inputs
- [ ] Confirmation email sent after sign-up
- [ ] Admin dashboard shows sign-ups

### Success Metrics
- **Primary:** 10% of monthly active users sign up for at least 1 volunteer opportunity

### Design Mockups Needed
- [ ] Volunteer opportunity card
- [ ] Sign-up form

---

## Implementation Roadmap

### Phase 1: High Impact (Q1 2026 - 6-8 weeks)
1. **Push Notifications** (Weeks 1-3)
2. **Sermon Sharing** (Week 4)
3. **In-App Giving with Apple Pay** (Weeks 5-8)

**Goal:** Increase engagement and revenue

---

### Phase 2: Medium Impact (Q2 2026 - 5-6 weeks)
4. **Offline Sermon Downloads** (Weeks 9-11)
5. **Church Announcements/News Feed** (Weeks 12-14)

**Goal:** Improve utility and week-to-week connection

---

### Phase 3: Nice-to-Have (Q3 2026 - 6-8 weeks)
6. **Sermon Notes Feature** (Weeks 15-17)
7. **Sermon Series Organization** (Week 18)
8. **Tappable Scripture References** (Weeks 19-20)
9. **Dark Mode Refinement** (Week 21)
10. **Volunteer Sign-Up** (Weeks 22-23)

**Goal:** Deepen discipleship and community engagement

---

## Resource Requirements

### Engineering
- **iOS Developer:** 1 full-time for 6 months
- **Backend Developer:** 0.5 full-time for 3 months (for Phases 1-2)
- **QA/Testing:** 0.25 full-time throughout

### Design
- **UI/UX Designer:** 0.5 full-time for 2 months (upfront design work)

### Pastoral/Content
- **Admin Dashboard Training:** 2 hours for church staff
- **Content Creation:** Ongoing announcements, volunteer opportunities

### Budget Estimate
- **Development:** $60,000 - $80,000 (contractor rates) or in-house salary
- **Third-Party Services:**
  - Firebase/APNs: $0-50/month (depends on notification volume)
  - Stripe (payment processing): 2.2% + $0.30 per transaction
  - Bible API (ESV): $0-100/month (depends on usage tier)
  - Hosting/Infrastructure: $50-100/month
- **Apple Developer Program:** $99/year
- **Total Estimated Cost:** $65,000 - $85,000 + ongoing operational costs

---

## Success Metrics Dashboard

Track these KPIs monthly:

| Metric | Baseline (Current) | Target (6 months) |
|--------|-------------------|-------------------|
| Weekly Active Users | TBD | +40% |
| Sermon Views (per week) | TBD | +50% |
| Sermon Shares (per week) | 0 | 50+ |
| In-App Donations (per month) | $0 | 20% of total giving |
| Offline Downloads (per month) | 0 | 30% of WAU |
| News Tab Opens (per week) | N/A | 50% of WAU |
| App Store Rating | TBD | 4.8+ stars |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Low adoption of notifications | A/B test notification timing and content |
| Payment processing delays | Use Stripe for reliable uptime; have fallback to Sharefaith |
| Storage issues with downloads | Implement auto-delete and storage warnings |
| Bible API rate limits | Cache frequently accessed verses; upgrade API tier if needed |
| User privacy concerns | Transparent privacy policy; no tracking or third-party analytics |

---

## Appendix: User Feedback Quotes

> "I love the app, but I never know when new sermons are posted. A notification would be amazing!"
> — Regular Member, Age 35

> "I wanted to share Sunday's sermon with my coworker, but there was no share button."
> — Member, Age 28

> "The Sharefaith redirect is confusing. I started giving, then got lost in the website."
> — First-Time Giver, Age 42

> "I travel for work and can't listen to sermons on planes. Offline downloads would be a game-changer."
> — Business Professional, Age 38

> "I missed Bible study last week because I didn't know it was canceled. An announcements section would help."
> — Small Group Leader, Age 50

---

**End of Specification Document**

*For questions or clarifications, contact the product team.*
