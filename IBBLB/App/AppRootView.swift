import SwiftUI

enum AppTab {
    case sermons
    case live
    case events
    case giving
}

struct AppRootView: View {
    @State private var selectedTab: AppTab = .sermons
    @State private var hideTabBar: Bool = false
    @State private var showSplash = true
    @State private var showNowPlaying = false

    @StateObject private var audioManager = AudioPlayerManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            mainContent
                .zIndex(0)

            if showSplash {
                ModernPowerOffSplash(isPresented: $showSplash)
                    .zIndex(100)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioManager: audioManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SermonsView(hideTabBar: $hideTabBar)
                    .tabItem {
                        Label("Sermons", systemImage: "book")
                    }
                    .tag(AppTab.sermons)

                LiveView()
                    .tabItem {
                        Label("Live", systemImage: "tv")
                    }
                    .tag(AppTab.live)

                EventsView()
                    .tabItem {
                        Label("Events", systemImage: "calendar")
                    }
                    .tag(AppTab.events)

                GivingView()
                    .tabItem {
                        Label("Giving", systemImage: "heart")
                    }
                    .tag(AppTab.giving)
            }

            // Mini player overlay (above tab bar)
            if audioManager.showMiniPlayer {
                AudioMiniPlayerBar(audioManager: audioManager) {
                    showNowPlaying = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 49) // Standard tab bar height
                .allowsHitTesting(true)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: audioManager.showMiniPlayer)
    }

}

#Preview {
    AppRootView()
}
