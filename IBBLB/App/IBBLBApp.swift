import SwiftUI

#if canImport(UIKit)
@main
struct IBBLBApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AdaptiveRootView()
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
#endif
