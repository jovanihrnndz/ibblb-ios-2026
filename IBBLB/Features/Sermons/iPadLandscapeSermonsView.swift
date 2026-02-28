import SwiftUI

#if canImport(UIKit)
struct iPadLandscapeSermonsView: View {
    @ObservedObject var viewModel: SermonsViewModel
    @Binding var selectedSermon: Sermon?
    @Binding var notificationSermonId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Banner spans full landscape width above both panes
            BannerView()
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                // Left sidebar: banner suppressed — already shown full-width above
                iPadSermonsListView(viewModel: viewModel, selectedSermon: $selectedSermon, showBanner: false)
                    .frame(width: 320)

                Divider()

                // Right pane: detail fills remaining width
                GeometryReader { geo in
                    if let sermon = selectedSermon {
                        SermonDetailView(
                            sermon: sermon,
                            splitViewWidth: geo.size.width,
                            showBanner: false
                        )
                        .id(sermon.id)
                    } else {
                        emptyState
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onChange(of: notificationSermonId) { _, id in
            guard let id,
                  let s = viewModel.sermons.first(where: { $0.id == id }) else { return }
            selectedSermon = s
            notificationSermonId = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Select a sermon")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
#else
struct iPadLandscapeSermonsView: View {
    var viewModel: SermonsViewModel
    @Binding var selectedSermon: Sermon?
    @Binding var notificationSermonId: String?

    var body: some View { EmptyView() }
}
#endif
