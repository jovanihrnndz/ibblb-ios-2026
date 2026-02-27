import Combine
import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let openSermonFromNotification = Notification.Name("openSermonFromNotification")
}

// MARK: - iOS Implementation

#if !os(Android)
import UserNotifications
import UIKit

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    private let tokenCacheKey = "registeredDeviceToken"
    private let optInKey = "sermonsNotificationsEnabled"

    @Published var isOptedIn: Bool {
        didSet {
            UserDefaults.standard.set(isOptedIn, forKey: optInKey)
        }
    }

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        self.isOptedIn = UserDefaults.standard.bool(forKey: "sermonsNotificationsEnabled")
    }

    // MARK: - Permission

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func optIn() async {
        isOptedIn = true
        await requestPermission()
        await refreshAuthorizationStatus()
    }

    func optOut() {
        isOptedIn = false
    }

    /// Requests notification authorization if not yet determined, then registers with APNs.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                #if DEBUG
                print("❌ Notification authorization error: \(error.localizedDescription)")
                #endif
            }
        case .authorized, .provisional:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    // MARK: - Token Registration

    /// Hex-encodes the APNs device token and upserts it to Supabase `device_tokens`.
    /// Caches the token in UserDefaults to skip duplicate network calls on the same token.
    func registerDeviceToken(_ tokenData: Data) async {
        guard isOptedIn else {
            #if DEBUG
            print("ℹ️ Notifications opted out — skipping token registration")
            #endif
            return
        }

        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()

        let cached = UserDefaults.standard.string(forKey: tokenCacheKey)
        guard token != cached else {
            #if DEBUG
            print("ℹ️ Device token unchanged — skipping upsert")
            #endif
            return
        }

        guard let url = URL(string: "\(APIConfig.supabaseURL)/rest/v1/device_tokens") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(APIConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(APIConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=ignore-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let body: [String: String] = ["token": token, "platform": "ios"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                UserDefaults.standard.set(token, forKey: tokenCacheKey)
                #if DEBUG
                print("✅ Device token registered with Supabase")
                #endif
            } else {
                #if DEBUG
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("⚠️ Device token upsert returned status \(code)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Device token upsert failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Deep Link Routing

    /// Reads `sermon_id` and `notification_type` from the notification payload and
    /// posts the appropriate `NotificationCenter` notification for the UI to handle.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["notification_type"] as? String else { return }

        switch type {
        case "new_sermon":
            guard let sermonId = userInfo["sermon_id"] as? String else { return }
            NotificationCenter.default.post(
                name: .openSermonFromNotification,
                object: nil,
                userInfo: ["sermon_id": sermonId]
            )
        default:
            break
        }
    }
}

// MARK: - Android Stub

#else

/// Android stub — Firebase Cloud Messaging replaces this in a future phase.
/// Satisfies all callers at compile time; push notifications are a no-op until implemented.
@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isOptedIn: Bool = false
    @Published var authorizationStatus: Int = 0  // Replaces UNAuthorizationStatus

    private init() {}

    func refreshAuthorizationStatus() async {}
    func optIn() async { isOptedIn = true }
    func optOut() { isOptedIn = false }
    func requestPermission() async {}
    func registerDeviceToken(_ tokenData: Data) async {}
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {}
}

#endif
