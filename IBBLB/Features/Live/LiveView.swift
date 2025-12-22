import SwiftUI
import Combine

struct LiveView: View {
    @StateObject private var viewModel = LiveViewModel()
    @State private var activeVideoId: String? = nil

    // Website-aligned dark blue/black color
    private let webDarkColor = Color(red: 22/255, green: 26/255, blue: 35/255)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerView()
                    .frame(maxWidth: .infinity)

                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    if viewModel.isLoading && viewModel.status == nil {
                        ProgressView()
                    } else if let status = viewModel.status {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 32) {
                                // 1. Header & Main Hero (Countdown or Live Stream)
                                VStack(spacing: 24) {
                                    Text("Únete a nosotros para servicios de\nadoración en vivo")
                                        .font(.system(size: 24, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)

                                    if status.state == .live,
                                       let rawVideoId = status.event?.youtubeVideoId,
                                       let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
                                        // LIVE: Show Video Player Directly (matching SermonDetailView styling)
                                        YouTubePlayerView(videoID: videoId)
                                            .aspectRatio(16/9, contentMode: .fit)
                                            .cornerRadius(12)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal)
                                    } else {
                                        // UPCOMING/OFFLINE: Show Countdown Card
                                        WebStyleCountdownCard(status: status, viewModel: viewModel, darkColor: webDarkColor)
                                            .padding(.horizontal)
                                    }
                                }

                                // 2. Previous Service Section
                                if let lastEvent = status.lastEvent {
                                    VStack(spacing: 16) {
                                        Text("Servicio Anterior")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.black)

                                        PreviousServiceVideoCard(event: lastEvent)
                                    }
                                    .padding(.horizontal)
                                }

                                // 3. Info Section (Service Times)
                                ServiceTimesCard()
                                    .padding(.horizontal)
                                    .padding(.bottom, 40)
                            }
                            .padding(.top, 8)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                        // Inline Video Player Overlay (matching SermonDetailView player styling)
                        .overlay {
                            if let rawVideoId = activeVideoId,
                               let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId),
                               status.state != .live {
                                ZStack {
                                    Color.black.opacity(0.9).ignoresSafeArea()

                                    VStack(spacing: 0) {
                                        HStack {
                                            Spacer()
                                            Button {
                                                activeVideoId = nil
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.white)
                                            }
                                            .padding()
                                        }

                                        // YouTube player matching SermonDetailView styling
                                        YouTubePlayerView(videoID: videoId)
                                            .aspectRatio(16/9, contentMode: .fit)
                                            .cornerRadius(12)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 16)

                                        Spacer()
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                    } else if let error = viewModel.errorMessage {
                        ElevationErrorView(error: error, onRetry: {
                            Task { await viewModel.refresh() }
                        })
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Components



// MARK: - New Web-Style Components

struct WebStyleCountdownCard: View {
    let status: LivestreamStatus
    @ObservedObject var viewModel: LiveViewModel
    let darkColor: Color

    var body: some View {
        VStack(spacing: 24) {
            Text("COMIENZA EN")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .tracking(1.5)

            // Countdown Digits
            HStack(spacing: 12) {
                timeBlock(value: hours, label: "HORAS")
                timeBlock(value: minutes, label: "MINUTOS")
                timeBlock(value: seconds, label: "SEGUNDOS")
            }

            Divider()
                .padding(.horizontal, 20)

            // Detailed Date
            if let date = status.event?.startsAt {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(date.formatted(date: .long, time: .shortened))
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.black)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
    }

    // Time Parsing
    private var timeComponents: (h: Int, m: Int, s: Int) {
        guard let timeRemaining = viewModel.timeRemaining else { return (0, 0, 0) }
        let h = Int(timeRemaining) / 3600
        let m = (Int(timeRemaining) % 3600) / 60
        let s = Int(timeRemaining) % 60
        return (h, m, s)
    }

    private var hours: String { String(format: "%02d", timeComponents.h) }
    private var minutes: String { String(format: "%02d", timeComponents.m) }
    private var seconds: String { String(format: "%02d", timeComponents.s) }

    @ViewBuilder
    private func timeBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(darkColor)
                    .frame(width: 80, height: 80)

                Text(value)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 140/255, green: 130/255, blue: 255/255))
            }

            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
        }
    }
}

struct PreviousServiceVideoCard: View {
    let event: LivestreamEvent

    var body: some View {
        Group {
            if let rawVideoId = event.youtubeVideoId,
               let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
                // YouTube player shown directly - one tap to play
                YouTubePlayerView(videoID: videoId)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity)
            } else {
                // Fallback placeholder when no video ID
                Rectangle()
                    .fill(Color(.systemGray6))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(.systemGray3))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct ServiceTimesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                Spacer()
            }

            Text("Horarios de Servicio")
                .font(.headline)
                .foregroundColor(.black)

            VStack(alignment: .leading, spacing: 12) {
                serviceLine(day: "Jueves", time: "7:30 PM", label: "Estudio Bíblico")
                serviceLine(day: "Domingo", time: "11:00 AM", label: "Escuela Dominical")
                serviceLine(day: "Domingo", time: "12:00 PM", label: "Servicio de Predicación")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private func serviceLine(day: String, time: String, label: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Circle().fill(Color.gray).frame(width: 4, height: 4).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(day) \(time)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
    }
}



struct ElevationErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("Connection Error")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    LiveView()
}
