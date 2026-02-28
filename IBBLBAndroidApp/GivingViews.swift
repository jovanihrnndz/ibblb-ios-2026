import SwiftUI

public struct GivingRootView: View {
    @State private var viewModel = GivingViewModel()
    private let repository: GivingRepository = LiveGivingRepository()

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    subtitle

                    if viewModel.isLoading && viewModel.page == nil {
                        loadingState
                    } else if let errorMessage = viewModel.errorMessage, viewModel.page == nil {
                        GivingErrorStateView(
                            message: errorMessage,
                            onRetry: { Task { await refreshGivingPage() } },
                            onLoadSample: { viewModel.loadSampleData() }
                        )
                    } else if let page = viewModel.page {
                        givingContent(page: page)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Giving information is currently unavailable.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Giving")
            .task {
                await loadInitialIfNeeded()
            }
        }
    }

    private var subtitle: some View {
        Text("Trust God with your finances by giving your first 10% back to Him.")
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading giving page...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    @ViewBuilder
    private func givingContent(page: GivingPageModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(page.title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(page.bodyText)
                .foregroundColor(.secondary)

            if let givingURL = page.givingURL {
                Link(destination: givingURL) {
                    Text("Give with Sharefaith Giving")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Link("Manage Your Account & Scheduled Gifts.", destination: givingURL)
                    .font(.footnote)
            } else {
                Text("Giving link is unavailable right now.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(12)
    }

    private func loadInitialIfNeeded() async {
        guard !viewModel.hasLoadedInitial else { return }
        viewModel.hasLoadedInitial = true
        await refreshGivingPage()
    }

    private func refreshGivingPage() async {
        viewModel.isLoading = true
        viewModel.errorMessage = nil

        do {
            viewModel.replacePage(try await repository.fetchGivingPage())
        } catch {
            viewModel.errorMessage = "Unable to load giving information. Check your connection and try again."
        }

        viewModel.isLoading = false
    }
}

private struct GivingErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    let onLoadSample: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Unable to Load Giving")
                .font(.headline)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)

            Button("Load Sample Giving Info", action: onLoadSample)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}
