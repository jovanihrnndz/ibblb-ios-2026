import SwiftUI

public struct LiveRootView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var latestSermon: SermonSummary?
    private let repository: SermonsRepository = LiveSermonsRepository()
    private let liveURL = URL(string: "https://www.youtube.com/IBBLBvideo")!

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    liveHeader
                    latestMessageSection
                    churchTimesSection
                }
                .padding(16)
            }
            .navigationTitle("Live")
            .navigationDestination(for: SermonSummary.self) { sermon in
                SermonDetailView(model: sermon.detailModel)
            }
            .task {
                await loadIfNeeded()
            }
        }
    }

    private var liveHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Join Us Live")
                .font(.title2)
                .fontWeight(.bold)
            Text("Watch our livestream and replay recent messages.")
                .foregroundColor(.secondary)

            Link("Open YouTube Channel", destination: liveURL)
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var latestMessageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Latest Message")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await refresh() }
                }
                .buttonStyle(.bordered)
            }

            if isLoading && latestSermon == nil {
                ProgressView("Loading latest message...")
            } else if let sermon = latestSermon {
                NavigationLink(value: sermon) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sermon.title)
                            .font(.headline)
                        Text(sermon.dateText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(sermon.descriptionText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.10))
                    .cornerRadius(10)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
            } else {
                Text("No recent messages available.")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var churchTimesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service Times")
                .font(.headline)
            Text("Thursday 7:30 PM - Bible Study")
            Text("Sunday 11:00 AM - Sunday School")
            Text("Sunday 12:00 PM - Worship Service")
        }
    }

    private func loadIfNeeded() async {
        guard latestSermon == nil else { return }
        await refresh()
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let sermons = try await repository.fetchSermons()
            latestSermon = sermons.first
            if latestSermon == nil {
                errorMessage = "No recent messages available."
            }
        } catch {
            errorMessage = "Could not load latest message."
        }
    }
}
