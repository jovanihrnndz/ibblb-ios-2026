import SwiftUI

@main
struct IBBLBApp: App {
    #if !os(Android)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            #if !os(Android)
            AdaptiveRootView()
                .task {
                    await NotificationManager.shared.requestPermission()
                }
            #else
            AdaptiveRootView()
            #endif
        }
    }
}
