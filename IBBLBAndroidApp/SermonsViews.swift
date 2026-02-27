import SwiftUI

struct SermonsRootView: View {
    @State private var viewModel = SermonsViewModel()
    private let repository: SermonsRepository = LiveSermonsRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                content
            }
            .padding(16)
            .navigationTitle("Sermons")
            .navigationDestination(for: SermonSummary.self) { sermon in
                SermonDetailView(model: sermon.detailModel)
            }
            .task {
                await loadInitialIfNeeded()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search sermons", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)

            if !viewModel.searchText.isEmpty {
                Button("Clear") {
                    viewModel.clearSearch()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sermons.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading sermons...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let errorMessage = viewModel.errorMessage, viewModel.sermons.isEmpty {
            SermonsErrorStateView(
                message: errorMessage,
                onRetry: { Task { await refreshSermons() } },
                onLoadSample: { viewModel.loadSampleData() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if viewModel.filteredSermons.isEmpty {
            SermonsEmptyStateView(isSearching: !viewModel.searchText.isEmpty)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List(viewModel.filteredSermons) { sermon in
                NavigationLink(value: sermon) {
                    SermonRowView(sermon: sermon)
                }
            }
            .listStyle(.plain)
        }
    }

    private func loadInitialIfNeeded() async {
        guard !viewModel.hasLoadedInitial else { return }
        viewModel.hasLoadedInitial = true
        await refreshSermons()
    }

    private func refreshSermons() async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        do {
            viewModel.sermons = try await repository.fetchSermons()
            if viewModel.sermons.isEmpty {
                viewModel.errorMessage = "No sermons are available right now."
            }
        } catch {
            viewModel.errorMessage = "Could not load sermons. Check your connection and try again."
        }

        viewModel.isLoading = false
    }
}

private struct SermonRowView: View {
    let sermon: SermonSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sermon.title)
                .font(.headline)

            HStack(spacing: 10) {
                if let speaker = sermon.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(sermon.dateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(sermon.descriptionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

private struct SermonsErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    let onLoadSample: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Unable to Load Sermons")
                .font(.headline)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)

            Button("Load Sample Sermons", action: onLoadSample)
                .buttonStyle(.bordered)
        }
    }
}

private struct SermonsEmptyStateView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(isSearching ? "No results" : "No sermons available")
                .font(.headline)
            Text(isSearching ? "Try a different search term." : "Pull to refresh or try again later.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct SermonDetailView: View {
    let model: SermonDetailModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(model.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    if let speaker = model.speaker, !speaker.isEmpty {
                        Text(speaker)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(model.dateText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(model.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(10)

                VStack(alignment: .leading, spacing: 8) {
                    if let youtubeVideoID = model.youtubeVideoID, !youtubeVideoID.isEmpty {
                        DetailLine(title: "YouTube ID", value: youtubeVideoID)
                    }
                    if let audioURLString = model.audioURLString, !audioURLString.isEmpty {
                        DetailLine(title: "Audio URL", value: audioURLString)
                    }
                    if let slug = model.slug, !slug.isEmpty {
                        DetailLine(title: "Slug", value: slug)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Sermon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.footnote)
        }
    }
}

struct FeaturePlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .navigationTitle(title)
        }
    }
}
