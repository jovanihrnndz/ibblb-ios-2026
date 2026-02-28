//
//  FallbackAsyncImage.swift
//  IBBLB
//
//  SwiftUI component that loads images from multiple URLs sequentially, falling back to the next URL if one fails
//

import SwiftUI

/// A view that attempts to load an image from a list of URLs sequentially,
/// falling back to the next URL if the current one fails to load.
struct FallbackAsyncImage<Content: View, Placeholder: View>: View {
    let urls: [URL]
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var currentIndex: Int = 0
    @State private var successfulImage: Image?
    @State private var currentPhase: AsyncImagePhase?
    
    /// Creates a FallbackAsyncImage that attempts to load from URLs in sequence
    /// - Parameters:
    ///   - urls: Array of URLs to try, in order of preference
    ///   - content: Closure that receives the loaded image and returns a view
    ///   - placeholder: Closure that returns a placeholder view while loading or if all URLs fail
    init(
        urls: [URL],
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = urls
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = successfulImage {
                content(image)
            } else if currentIndex < urls.count {
                AsyncImage(url: urls[currentIndex]) { phase in
                    handlePhase(phase)
                }
                .id(currentIndex) // Force recreation when URL changes
            } else {
                placeholder()
            }
        }
        .onChange(of: currentIndex) { _, _ in
            successfulImage = nil
            currentPhase = nil
        }
        .onChange(of: urls) { _, _ in
            currentIndex = 0
            successfulImage = nil
            currentPhase = nil
        }
    }
    
    @ViewBuilder
    private func handlePhase(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            image
                .onAppear {
                    successfulImage = image
                }
                
        case .failure:
            placeholder()
                .onAppear {
                    tryNextURL()
                }
                
        case .empty:
            placeholder()
            
        @unknown default:
            placeholder()
        }
    }
    
    private func tryNextURL() {
        guard currentIndex < urls.count - 1 else {
            return
        }
        currentIndex += 1
    }
}

// MARK: - Convenience Initializers

#if canImport(UIKit)
extension FallbackAsyncImage where Content == Image, Placeholder == Color {
    /// Simplified initializer that returns the image directly with a clear placeholder
    init(urls: [URL], contentMode: ContentMode = .fill) {
        self.urls = urls
        self.content = { $0.resizable() }
        self.placeholder = { Color.clear }
    }
}
#endif

// MARK: - Preview

#if canImport(UIKit)
    #Preview {
        VStack(spacing: 20) {
            // Example with multiple URLs
            FallbackAsyncImage(
                urls: [
                    URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg")!,
                    URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/sddefault.jpg")!,
                    URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")!
                ]
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                ProgressView()
                    .frame(width: 200, height: 200)
            }
        }
        .padding()
    }
#endif
