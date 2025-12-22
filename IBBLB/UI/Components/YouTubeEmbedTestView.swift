//
//  YouTubeEmbedTestView.swift
//  IBBLB
//
//  Test View to isolate YouTube embed issue
//

import SwiftUI

struct YouTubeEmbedTestView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("YouTube Embed Test")
                    .font(.title.bold())
                
                // Test with both direct ID and URL format
                VStack(spacing: 16) {
                    YouTubePlayerView(videoID: "dQw4w9WgXcQ") // Direct ID
                        .frame(height: 220)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    
                    Text("Direct ID Test")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let extractedID = YouTubeVideoIDExtractor.extractVideoID(from: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") {
                        YouTubePlayerView(videoID: extractedID) // Extracted from URL
                            .frame(height: 220)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        Text("URL Extraction Test (extracted: \(extractedID))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                    .frame(height: 220)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                
                Text("If this video loads, your embed setup is working.\nIf it fails, the issue is your code or headers.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
}

#Preview {
    YouTubeEmbedTestView()
}

