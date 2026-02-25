import Foundation
import UserNotifications
import UIKit

// MARK: - Notification Names

extension Notification.Name {
    static let openSermonFromNotification = Notification.Name("openSermonFromNotification")
}

// MARK: - NotificationManager

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    private let tokenCacheKey = "registeredDeviceToken"

    private init() {}

    // MARK: - Permission

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
