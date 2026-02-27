import SwiftUI
#if canImport(AVKit)
import AVKit
#endif
#if canImport(Combine)
import Combine
#endif

struct AudioPlayerView: View {
    let url: URL
    let title: String
    let subtitle: String?
    var showInfo: Bool = true
    
    @ObservedObject private var audioManager = AudioPlayerManager.shared
    @State private var sliderValue: Double = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Content Info
            if showInfo {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
            
            // Progress Slider
            VStack(spacing: 4) {
                Slider(value: $sliderValue, in: 0...max(1, audioManager.duration)) { editing in
                    isDragging = editing
                    audioManager.isScrubbing = editing
                    if !editing {
                        audioManager.seek(to: sliderValue)
                    }
                }
                .tint(.accentColor)
                .onChange(of: audioManager.currentTime) { _, newValue in
                    if !isDragging {
                        sliderValue = newValue
                    }
                }
                .onAppear {
                    sliderValue = audioManager.currentTime
                }
                
                HStack {
                    Text(formatTime(isDragging ? sliderValue : audioManager.currentTime))
                    Spacer()
                    Text(formatTime(audioManager.duration))
                }
                .font(.caption2)
                #if canImport(UIKit)
                .monospacedDigit()
                #endif
                .foregroundColor(.secondary)
            }
            
            // Controls
            HStack(spacing: 40) {
                Button(action: { audioManager.skip(by: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .offset(x: audioManager.isPlaying ? 0 : 2)
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: { audioManager.skip(by: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
            }
            .padding(.bottom)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .onAppear {
            audioManager.play(url: url, title: title, artworkURL: nil)
        }
        .onDisappear {
            // Don't stop here - let audioManager manage lifecycle
            // Audio can continue playing when view disappears
        }
    }
    
    // MARK: - Helper Methods
    
    private func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.resume()
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        return AudioPlayerManager.formatTime(seconds)
    }
}

#if canImport(UIKit)
    #Preview {
        AudioPlayerView(
            url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!,
            title: "The Prodigal Son Returns",
            subtitle: "Pastor John Doe"
        )
        .padding()
        .background(Color(.systemGray6))
    }
#endif
