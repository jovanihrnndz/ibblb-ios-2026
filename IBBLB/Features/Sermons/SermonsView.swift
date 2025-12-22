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
    
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }
    
    // All sermons for the list
    private var listSermons: [Sermon] {
        return viewModel.sermons
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerView()
                    .frame(maxWidth: .infinity)
                
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    contentView
                }
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
                // SearchBar at the top - scrolls with content
                SearchBar(text: $viewModel.searchText, placeholder: "Search sermons")
                    .padding(.horizontal, isTV ? 60 : 16)
                    .padding(.top, isTV ? 24 : 12)
                    .background(
                        RoundedRectangle(cornerRadius: isTV ? 24 : 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: isTV ? 24 : 16)
                                    .stroke(Color.white.opacity(0.12), lineWidth: isTV ? 2 : 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: isTV ? 12 : 8, x: 0, y: 2)
                    )
                    .padding(.top, isTV ? 16 : 8)
                
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
            .padding(.horizontal, isTV ? 60 : 16)
            .padding(.bottom, isTV ? 32 : 16)
        }
        .scrollIndicators(.hidden)
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
    
    private var sermonsListContent: some View {
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
