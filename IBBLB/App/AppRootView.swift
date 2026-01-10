import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case sermons
    case live
    case events
    case giving
}

struct AppRootView: View {
    @AppStorage("selectedTab") private var selectedTab: AppTab = .sermons
    @State private var showSplash = true
    @State private var showNowPlaying = false

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
            NowPlayingView(audioManager: AudioPlayerManager.shared)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                SermonsView()
                    .tabItem {
                        Label(String(localized: "Sermons"), systemImage: "book")
                    }
                    .tag(AppTab.sermons)

                LiveView()
                    .tabItem {
                        Label(String(localized: "Live"), systemImage: "tv")
                    }
                    .tag(AppTab.live)

                EventsView()
                    .tabItem {
                        Label(String(localized: "Events"), systemImage: "calendar")
                    }
                    .tag(AppTab.events)

                GivingView()
                    .tabItem {
                        Label(String(localized: "Giving"), systemImage: "heart")
                    }
                    .tag(AppTab.giving)
            }
            .toolbar(.visible, for: .tabBar)

            // Mini player overlay - isolated in its own observing view
            // to prevent AudioPlayerManager updates from re-rendering the entire app
            MiniPlayerContainer(showNowPlaying: $showNowPlaying)
        }
    }
}

/// Isolates AudioPlayerManager observation to prevent parent (AppRootView) from re-rendering
/// on every currentTime update (every 0.5s). Only this subtree re-renders on audio state changes.
private struct MiniPlayerContainer: View {
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    @Binding var showNowPlaying: Bool

    var body: some View {
        Group {
            if audioManager.showMiniPlayer {
                AudioMiniPlayerBar(audioManager: audioManager) {
                    showNowPlaying = true
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.95, anchor: .bottom)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
                )
                .padding(.bottom, 49) // Standard tab bar height
                .allowsHitTesting(true)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioManager.showMiniPlayer)
    }
}

#Preview {
    AppRootView()
}
