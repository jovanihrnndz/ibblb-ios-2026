import SwiftUI

public struct IBBLBAppRootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Text("IBBLB")
                .font(.title)
                .fontWeight(.bold)
            Text("Android app shell is running")
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

public final class IBBLBAndroidAppDelegate: Sendable {
    public static let shared = IBBLBAndroidAppDelegate()

    private init() {}

    public func onInit() {}
    public func onLaunch() {}
    public func onResume() {}
    public func onPause() {}
    public func onStop() {}
    public func onDestroy() {}
    public func onLowMemory() {}
}
