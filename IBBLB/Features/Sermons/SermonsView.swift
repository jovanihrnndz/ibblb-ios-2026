//
//  SermonsView.swift
//  ChurchApp
//
//  Created by jovani hernandez on 7/6/25.
//

import SwiftUI
import Combine

struct SermonsView: View {
    @StateObject private var viewModel: SermonsViewModel
    @State private var selectedSermon: Sermon?
    @Binding var hideTabBar: Bool
    @Binding var notificationSermonId: String?
    @Namespace private var animationNamespace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        viewModel: SermonsViewModel,
        hideTabBar: Binding<Bool>,
        notificationSermonId: Binding<String?>
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _hideTabBar = hideTabBar
        _notificationSermonId = notificationSermonId
    }
    
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    /// True when on iPad or wide split-screen
    private var useGridLayout: Bool {
        horizontalSizeClass == .regular && !isTV
    }

    /// iPad grid configuration - larger cards with more spacing
    private var iPadGridMinWidth: CGFloat { 400 }
    private var iPadGridSpacing: CGFloat { 24 }
    private var iPadHorizontalPadding: CGFloat { 24 }
    
    // All sermons for the list
    private var listSermons: [Sermon] {
        return viewModel.sermons
    }

    // Audio manager for continue listening feature
    @ObservedObject private var audioManager = AudioPlayerManager.shared

    // Continue listening info from shared helper (supports offline fallback)
    private var continueListeningInfo: AudioPlayerManager.ContinueListeningResult? {
        audioManager.getContinueListeningInfo(from: viewModel.sermons)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    BannerView()
                        .frame(maxWidth: .infinity)
                    
                    ZStack {
                        Color(.systemGroupedBackground)
                            .ignoresSafeArea()
                            .onTapGesture {
                                // Dismiss keyboard when tapping on background
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        
                        contentView
                    }
                }
                
                // Search bar overlaying content - content bleeds underneath
                VStack(spacing: 0) {
                    UIKitSearchBar(text: $viewModel.searchText, placeholder: "Search sermons")
                        .padding(.horizontal, isTV ? 60 : (useGridLayout ? iPadHorizontalPadding : 16))
                        .padding(.vertical, isTV ? 16 : (useGridLayout ? 22 : 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, useGridLayout ? 140 : 100) // Position below banner (140 on iPad, 100 on iPhone)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                // Load initial data only once
                await viewModel.loadInitial()
            }
            .onChange(of: notificationSermonId) { _, newId in
                guard let id = newId,
                      let sermon = viewModel.sermons.first(where: { $0.id == id }) else { return }
                selectedSermon = sermon
                notificationSermonId = nil
            }
            .navigationDestination(item: $selectedSermon) { sermon in
                SermonDetailView(sermon: sermon)
                    .onDisappear { hideTabBar = false }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Content based on state
                if viewModel.isLoading && viewModel.sermons.isEmpty {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if viewModel.sermons.isEmpty {
                    emptyView
                } else {
                    sermonsListContent
                }
            }
            .padding(.horizontal, isTV ? 60 : (useGridLayout ? iPadHorizontalPadding : 16))
            .padding(.top, isTV ? 24 : (useGridLayout ? 60 : 50)) // More top padding on iPad
            .padding(.bottom, isTV ? 32 : (useGridLayout ? 24 : 16))
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively) // Dismiss keyboard when scrolling
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView("Loading sermons...")
                .padding(.top, 40)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    @ViewBuilder
    private var sermonsListContent: some View {
        VStack(spacing: useGridLayout ? iPadGridSpacing : (isTV ? 32 : 16)) {
            // Continue Listening Card (if available, not on tvOS, and no active playback)
            if !isTV, audioManager.currentTrack == nil,
               let info = continueListeningInfo {
                ContinueListeningCardView(
                    result: info,
                    duration: nil, // Duration not available in list view
                    onCardTap: info.hasMatchingSermon ? {
                        selectedSermon = info.sermon
                    } : nil,
                    onResume: {
                        audioManager.resumeListening(from: info)
                    }
                )
                .padding(.top, useGridLayout ? 28 : 24)
                .padding(.bottom, useGridLayout ? -8 : 0)
            }
            
            // Sermons list
            if useGridLayout {
                // iPad: adaptive grid with larger cards (typically 2 columns)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: iPadGridMinWidth), spacing: iPadGridSpacing)],
                    spacing: iPadGridSpacing
                ) {
                    ForEach(listSermons) { sermon in
                        Button {
                            selectedSermon = sermon
                        } label: {
                            SermonCardView(sermon: sermon)
                        }
                        .buttonStyle(SermonCardButtonStyle())
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: sermon) }
                    }
                }
            } else {
                // iPhone / tvOS: single column list
                LazyVStack(spacing: isTV ? 32 : 16) {
                    ForEach(listSermons) { sermon in
                        Button {
                            selectedSermon = sermon
                        } label: {
                            SermonCardView(sermon: sermon)
                        }
                        .buttonStyle(SermonCardButtonStyle())
                        .onAppear { viewModel.loadMoreIfNeeded(currentItem: sermon) }
                    }
                }
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.amber)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Text("Retry")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No sermons found")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Try searching for something else.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Clear search button - only show if there's search text
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Text("Clear Search")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// Minimal amber color for error icon
extension Color {
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
}

// MARK: - Navigation Transitions
struct SermonCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

#Preview {
    SermonsView(hideTabBar: .constant(false), notificationSermonId: .constant(nil))
}
