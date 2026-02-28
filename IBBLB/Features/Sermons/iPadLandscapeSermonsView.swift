import SwiftUI

#if canImport(UIKit)
struct iPadLandscapeSermonsView: View {
    @ObservedObject var viewModel: SermonsViewModel
    @Binding var selectedSermon: Sermon?
    @Binding var notificationSermonId: String?

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: reuse iPadSermonsListView at fixed width
            iPadSermonsListView(viewModel: viewModel, selectedSermon: $selectedSermon)
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
