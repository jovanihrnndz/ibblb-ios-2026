//
//  SermonsView.swift
//  ChurchApp
//
//  Created by jovani hernandez on 7/6/25.
//

import SwiftUI
import Combine

struct SermonsView: View {
    @StateObject private var viewModel = SermonsViewModel()
    @State private var selectedSermon: Sermon?
    @Binding var hideTabBar: Bool
    @Namespace private var animationNamespace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    
    // Search suggestions based on current sermons
    private var searchSuggestions: [String] {
        let query = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        let titles = listSermons.map { $0.title }
        let uniqueTitles = Array(Set(titles))
        return uniqueTitles
            .filter { $0.lowercased().contains(lowercasedQuery) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(5)
            .map { $0 }
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
                    
                    // Search suggestions
                    if !searchSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(searchSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    viewModel.searchText = suggestion
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                        Text(suggestion)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, isTV ? 60 : (useGridLayout ? iPadHorizontalPadding : 16))
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, useGridLayout ? 140 : 100) // Position below banner (140 on iPad, 100 on iPhone)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                // Load initial data only once
                await viewModel.loadInitial()
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
                    }
                }
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
    SermonsView(hideTabBar: .constant(false))
}
