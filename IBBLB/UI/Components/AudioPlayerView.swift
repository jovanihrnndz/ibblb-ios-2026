import SwiftUI
import AVKit
import Combine

struct AudioPlayerView: View {
    let url: URL
    let title: String
    let subtitle: String?
    var showInfo: Bool = true
    
    @StateObject private var controller = AudioPlaybackController.shared
    
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
                Slider(value: Binding(
                    get: { controller.currentTime },
                    set: { newValue in
                        controller.currentTime = newValue
                    }
                ), in: 0...max(0, controller.duration)) { editing in
                    controller.isScrubbing = editing
                    if !editing {
                        controller.seek(to: controller.currentTime)
                    }
                }
                .tint(.accentColor)
                
                HStack {
                    Text(formatTime(controller.currentTime))
                    Spacer()
                    Text(formatTime(controller.duration))
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(.secondary)
            }
            
            // Controls
            HStack(spacing: 40) {
                Button(action: { controller.skip(by: -15) }) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                
                Button(action: togglePlayback) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .offset(x: controller.isPlaying ? 0 : 2)
                    }
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                
                Button(action: { controller.skip(by: 15) }) {
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
            controller.play(url: url)
        }
        .onDisappear {
            // Don't stop here - let controller manage lifecycle
            // Audio can continue playing when view disappears
        }
    }
    
    // MARK: - Helper Methods
    
    private func togglePlayback() {
        if controller.isPlaying {
            controller.pause()
        } else {
            controller.play(url: url)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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
