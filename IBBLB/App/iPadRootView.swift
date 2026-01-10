import SwiftUI

/// iPad-specific root view using a top tab bar instead of sidebar.
struct iPadRootView: View {
    @SceneStorage("selectedTab") private var selectedTab: AppTab = .sermons
    @State private var showSplash = true
    @State private var showNowPlaying = false

    var body: some View {
        ZStack {
            mainContent

            if showSplash {
                ModernPowerOffSplash(isPresented: $showSplash)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(audioManager: AudioPlayerManager.shared)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Main Content with Top Tab Bar

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top tab bar
            topTabBar

            // Content area
            contentArea
        }
        .safeAreaInset(edge: .bottom) {
            iPadMiniPlayerContainer(showNowPlaying: $showNowPlaying)
        }
    }

    // MARK: - Top Tab Bar

    private var topTabBar: some View {
        HStack(spacing: 0) {
            Spacer()

            HStack(spacing: 8) {
                tabButton(tab: .sermons, title: String(localized: "Sermons"), icon: "book")
                tabButton(tab: .live, title: String(localized: "Live"), icon: "tv")
                tabButton(tab: .events, title: String(localized: "Events"), icon: "calendar")
                tabButton(tab: .giving, title: String(localized: "Giving"), icon: "heart")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
            )

            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private func tabButton(tab: AppTab, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote.weight(.medium))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.callout.weight(.medium))
            }
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(selectedTab == tab ? "Currently selected tab" : "Double tap to switch to \(title) tab")
        .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch selectedTab {
        case .sermons:
            SermonsView()
        case .live:
            LiveView()
        case .events:
            EventsView()
        case .giving:
            GivingView()
        }
    }
}

// MARK: - Mini Player Container

/// Isolated mini player container for iPad.
/// Prevents AudioPlayerManager updates from re-rendering the entire view hierarchy.
private struct iPadMiniPlayerContainer: View {
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
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: audioManager.showMiniPlayer)
    }
}

#Preview {
    iPadRootView()
}
