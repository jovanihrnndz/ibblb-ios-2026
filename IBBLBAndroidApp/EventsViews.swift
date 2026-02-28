import SwiftUI

public struct EventsRootView: View {
    @State private var viewModel = EventsViewModel()
    @State private var navigationPath: [EventSummary] = []
    @State private var pendingRestoreEventID: String? = AndroidAppSessionStore.loadLastOpenedEventID()
    private let repository: EventsRepository = SanityEventsRepository()

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 12) {
                searchBar
                content
            }
            .padding(16)
            .navigationTitle("Events")
            .navigationDestination(for: EventSummary.self) { event in
                EventDetailView(model: event.detailModel)
            }
            .task {
                await loadInitialIfNeeded()
            }
            .onChange(of: navigationPath) { path in
                AndroidAppSessionStore.saveLastOpenedEventID(path.last?.id)
            }
        }
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.updateSearchText($0) }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search events", text: searchTextBinding)
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
        if viewModel.isLoading && viewModel.events.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading events...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let errorMessage = viewModel.errorMessage, viewModel.events.isEmpty {
            EventsErrorStateView(
                message: errorMessage,
                onRetry: { Task { await refreshEvents() } },
                onLoadSample: {
                    viewModel.loadSampleData()
                    restoreLastOpenedEventIfPossible()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if viewModel.filteredEvents.isEmpty {
            EventsEmptyStateView(isSearching: !viewModel.searchText.isEmpty)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            List(viewModel.filteredEvents) { event in
                NavigationLink(value: event) {
                    EventRowView(event: event)
                }
            }
            .listStyle(.plain)
        }
    }

    private func loadInitialIfNeeded() async {
        guard !viewModel.hasLoadedInitial else { return }
        viewModel.hasLoadedInitial = true
        restoreLastOpenedEventIfPossible()
        await refreshEvents()
    }

    private func refreshEvents() async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        do {
            viewModel.replaceWithUpcoming(try await repository.fetchEvents())
            if viewModel.events.isEmpty {
                viewModel.errorMessage = "No upcoming events are available right now."
            }
        } catch {
            viewModel.errorMessage = "Could not load events. Check your connection and try again."
        }

        restoreLastOpenedEventIfPossible()
        viewModel.isLoading = false
    }

    private func restoreLastOpenedEventIfPossible() {
        guard navigationPath.isEmpty,
              let restoreID = pendingRestoreEventID,
              let event = viewModel.events.first(where: { $0.id == restoreID }) else {
            return
        }

        navigationPath = [event]
        pendingRestoreEventID = nil
    }
}

private struct EventRowView: View {
    let event: EventSummary

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.headline)

            Text(event.dateText)
                .font(.caption)
                .foregroundColor(.secondary)

            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(event.descriptionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

private struct EventsErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    let onLoadSample: () -> Void

    public var body: some View {
        VStack(spacing: 14) {
            Text("Unable to Load Events")
                .font(.headline)

            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)

            Button("Load Sample Events", action: onLoadSample)
                .buttonStyle(.bordered)
        }
    }
}

private struct EventsEmptyStateView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(isSearching ? "No results" : "No upcoming events")
                .font(.headline)
            Text(isSearching ? "Try a different search term." : "Pull to refresh or try again later.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

public struct EventDetailView: View {
    let model: EventDetailModel

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let imageURLString = model.imageURLString,
                   let imageURL = URL(string: imageURLString) {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.secondary.opacity(0.15)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                    .clipped()
                    .cornerRadius(12)
                }

                Text(model.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(model.dateText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let location = model.location, !location.isEmpty {
                    EventDetailLine(title: "Location", value: location)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(model.description)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(10)

                if model.registrationEnabled {
                    Text("Registration enabled for this event.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EventDetailLine: View {
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
