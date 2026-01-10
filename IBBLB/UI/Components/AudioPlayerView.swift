import SwiftUI
import AVKit
import Combine

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
                .accessibilityLabel("Audio progress")
                .accessibilityValue("\(formatTime(isDragging ? sliderValue : audioManager.currentTime)) of \(formatTime(audioManager.duration))")
                .accessibilityHint("Swipe up or down to adjust playback position")
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
                .monospacedDigit()
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            }
            
            // Controls
            HStack(spacing: 40) {
                Button(action: { audioManager.skip(by: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Skip backward 15 seconds")
                .accessibilityHint("Double tap to skip backward 15 seconds")
                .accessibilityAddTraits(.isButton)
                
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .offset(x: audioManager.isPlaying ? 0 : 2)
                            .accessibilityHidden(true)
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
                .accessibilityHint("Double tap to \(audioManager.isPlaying ? "pause" : "play") audio")
                .accessibilityAddTraits(.isButton)
                
                Button(action: { audioManager.skip(by: 15) }) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Skip forward 15 seconds")
                .accessibilityHint("Double tap to skip forward 15 seconds")
                .accessibilityAddTraits(.isButton)
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

#Preview {
    AudioPlayerView(
        url: URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!,
        title: "The Prodigal Son Returns",
        subtitle: "Pastor John Doe"
    )
    .padding()
    .background(Color(.systemGray6))
}
