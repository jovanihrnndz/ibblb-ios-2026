import SwiftUI
import Combine

struct LiveView: View {
    @StateObject private var viewModel = LiveViewModel()
    @State private var activeVideoId: String? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Website-aligned dark blue/black color
    private let webDarkColor = Color(red: 22/255, green: 26/255, blue: 35/255)

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

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
                        Group {
                            if isRegularWidth {
                                // iPad: No-scroll layout
                                iPadLiveContent(status: status)
                            } else {
                                // iPhone: Scrollable layout
                                iPhoneLiveContent(status: status)
                            }
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
                                            .accessibilityLabel("Close video player")
                                            .accessibilityHint("Double tap to close the video overlay")
                                            .accessibilityAddTraits(.isButton)
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
                await viewModel.loadInitial()
            }
            .onAppear {
                viewModel.onAppear()
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
    }

    // MARK: - iPad Layout (No Scroll)

    @ViewBuilder
    private func iPadLiveContent(status: LivestreamStatus) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Únete a nosotros para servicios de adoración en vivo")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Main content - horizontal layout
                HStack(alignment: .top, spacing: 24) {
                    // Left: Countdown or Live status
                    VStack(alignment: .center, spacing: 12) {
                        Text(status.state == .live ? "En Vivo" : "Próximo Servicio")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)

                        if status.state == .live,
                           let rawVideoId = status.event?.youtubeVideoId,
                           let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
                            YouTubePlayerView(videoID: videoId)
                                .aspectRatio(16/9, contentMode: .fit)
                                .cornerRadius(12)
                        } else if status.state == .upcoming, status.event != nil {
                            WebStyleCountdownCard(status: status, viewModel: viewModel, darkColor: webDarkColor)
                        } else {
                            NoUpcomingServiceCard()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right: Previous service video
                    if let lastEvent = status.lastEvent {
                        VStack(alignment: .center, spacing: 12) {
                            Text("Servicio Anterior")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)

                            PreviousServiceVideoCard(event: lastEvent)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)

                // Service Info Card
                ServiceInfoCardView()
                    .frame(maxWidth: 900)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - iPhone Layout (Scrollable)

    @ViewBuilder
    private func iPhoneLiveContent(status: LivestreamStatus) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // 1. Header & Main Hero (Countdown or Live Stream)
                VStack(spacing: 24) {
                    Text("Únete a nosotros para\nservicios en vivo")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)

                    if status.state == .live,
                       let rawVideoId = status.event?.youtubeVideoId,
                       let videoId = YouTubeVideoIDExtractor.extractVideoID(from: rawVideoId) {
                        YouTubePlayerView(videoID: videoId)
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    } else if status.state == .upcoming, status.event != nil {
                        WebStyleCountdownCard(status: status, viewModel: viewModel, darkColor: webDarkColor)
                            .padding(.horizontal)
                    } else {
                        NoUpcomingServiceCard()
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

                // 3. Service Info Section
                ServiceInfoCardView()
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.refresh()
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
        ZStack {
            // 16:9 aspect ratio container
            Color.clear
                .aspectRatio(16/9, contentMode: .fit)

            // Card content centered in the container
            VStack(spacing: 24) {
                Text("COMIENZA EN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(1.5)

                // Countdown Digits
                HStack(spacing: 12) {
                    if timeComponents.d > 0 {
                        // >= 1 day: Show Days / Hours / Minutes
                        timeBlock(value: days, label: "DÍAS")
                        timeBlock(value: hours, label: "HORAS")
                        timeBlock(value: minutes, label: "MINUTOS")
                    } else {
                        // < 1 day: Show Hours / Minutes / Seconds
                        timeBlock(value: hours, label: "HORAS")
                        timeBlock(value: minutes, label: "MINUTOS")
                        timeBlock(value: seconds, label: "SEGUNDOS")
                    }
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
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
    }

    // Time Parsing
    private var timeComponents: (d: Int, h: Int, m: Int, s: Int) {
        guard let timeRemaining = viewModel.timeRemaining else { return (0, 0, 0, 0) }
        let totalSeconds = Int(timeRemaining)
        let d = totalSeconds / 86400  // Days
        let h = (totalSeconds % 86400) / 3600  // Hours within day (0-23)
        let m = (totalSeconds % 3600) / 60  // Minutes within hour (0-59)
        let s = totalSeconds % 60  // Seconds within minute (0-59)
        return (d, h, m, s)
    }

    private var days: String { String(format: "%02d", timeComponents.d) }
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
                    .font(.system(size: 36, weight: .bold, design: .rounded)) // Large display numbers - kept specific size for countdown timer
                    .foregroundColor(Color(red: 140/255, green: 130/255, blue: 255/255))
            }

            Text(label)
                .font(.caption2.weight(.bold))
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
                            .font(.largeTitle) // Decorative placeholder icon
                            .foregroundColor(Color(.systemGray3))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct NoUpcomingServiceCard: View {
    var body: some View {
        ZStack {
            // 16:9 aspect ratio container
            Color.clear
                .aspectRatio(16/9, contentMode: .fit)

            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.clock")
                    .font(.largeTitle) // Decorative icon
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                Text("No hay servicio programado")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text("Consulta los horarios de servicio abajo")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
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
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.black)
                Text(label)
                    .font(.footnote)
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
                .accessibilityHidden(true)

            Text("Connection Error")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .accessibilityLabel("Error message: \(error)")

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry loading live stream")
            .accessibilityHint("Double tap to attempt loading live stream information again")
            .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    LiveView()
}
