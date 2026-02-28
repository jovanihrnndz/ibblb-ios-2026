import SwiftUI
#if canImport(Combine)
import Combine
#endif

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// True when on iPad or wide split-screen
    private var useGridLayout: Bool {
        horizontalSizeClass == .regular
    }

    /// iPad grid configuration
    private var iPadGridMinWidth: CGFloat { 400 }
    private var iPadGridSpacing: CGFloat { 24 }
    private var iPadHorizontalPadding: CGFloat { 24 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerView()
                    .frame(maxWidth: .infinity)

                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    if viewModel.isLoading && viewModel.events.isEmpty {
                        ProgressView()
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                            Text(error)
                                .multilineTextAlignment(.center)
                            Button("Reintentar") {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if viewModel.events.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            eventsListContent
                                .padding(.horizontal, useGridLayout ? iPadHorizontalPadding : 16)
                                .padding(.bottom, 16)
                                .padding(.top, 8)
                        }
                        .navigationDestination(for: Event.self) { event in
                            EventDetailView(event: event)
                        }
                    }
                }
                // Hide navigation bar to allow content to flow under global banner
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    await viewModel.refresh()
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private var eventsListContent: some View {
        if useGridLayout {
            // iPad: adaptive grid with larger cards
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: iPadGridMinWidth), spacing: iPadGridSpacing)],
                spacing: iPadGridSpacing
            ) {
                ForEach(viewModel.events) { event in
                    NavigationLink(value: event) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        } else {
            // iPhone: single column list
            LazyVStack(spacing: 20) {
                ForEach(viewModel.events) { event in
                    NavigationLink(value: event) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No hay eventos próximos")
                .font(.headline)
            
            Text("Vuelve pronto para ver nuestras próximas actividades.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Actualizar") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Date Formatting Helpers

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    static func dayString(from date: Date) -> String {
        return dayFormatter.string(from: date)
    }

    static func monthString(from date: Date) -> String {
        return monthFormatter.string(from: date).uppercased()
    }
}

private struct EventCardView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageUrl = event.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .aspectRatio(16/9, contentMode: .fill)
                }
                .frame(maxHeight: 180)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(event.startDate.formatted(date: .long, time: .shortened))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let location = event.location {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Date Badge
                    VStack(spacing: 0) {
                        Text(EventsView.dayString(from: event.startDate))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.accentColor)
                        Text(EventsView.monthString(from: event.startDate))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(event.startDate, format: .dateTime.day().month(.wide)))
                }

                if let description = event.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }

                if event.registrationEnabled == true {
                    Button(action: {
                        // Registration action
                    }) {
                        Text("Registrarse")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 12)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

#if DEBUG && canImport(UIKit)
    struct EventsView_Previews: PreviewProvider {
        static var previews: some View {
            EventsView()
        }
    }
#endif
