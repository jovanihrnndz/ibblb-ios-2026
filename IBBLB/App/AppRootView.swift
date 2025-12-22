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
    
    var body: some View {
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
    }
}

#Preview {
    AppRootView()
}
