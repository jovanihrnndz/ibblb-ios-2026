import SwiftUI
import Combine

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
                            .font(.system(size: 50)) // Large decorative error icon - size appropriate for error state
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .accessibilityLabel("Error message: \(error)")
                            Button("Reintentar") {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Retry loading events")
                            .accessibilityHint("Double tap to attempt loading events again")
                            .accessibilityAddTraits(.isButton)
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
                        eventCard(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Event: \(event.title)")
                    .accessibilityHint("Double tap to view event details")
                    .accessibilityAddTraits(.isButton)
                }
            }
        } else {
            // iPhone: single column list
            LazyVStack(spacing: 20) {
                ForEach(viewModel.events) { event in
                    NavigationLink(value: event) {
                        eventCard(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Event: \(event.title)")
                    .accessibilityHint("Double tap to view event details")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60)) // Large decorative empty state icon - size appropriate for empty state
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("No hay eventos próximos")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Text("Vuelve pronto para ver nuestras próximas actividades.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Actualizar") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Refresh events")
            .accessibilityHint("Double tap to refresh the events list")
            .accessibilityAddTraits(.isButton)
        }
        .padding()
    }
    
    @ViewBuilder
    private func eventCard(event: Event) -> some View {
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
                        .foregroundColor(.secondary)
                        
                        if let location = event.location {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                Text(location)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Date Badge
                    VStack(spacing: 0) {
                        Text(event.startDate.formatted(.dateTime.day()))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                        Text(event.startDate.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top, 12)
                    .accessibilityLabel("Register for event")
                    .accessibilityHint("Double tap to register for this event")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

#if DEBUG
struct EventsView_Previews: PreviewProvider {
    static var previews: some View {
        EventsView()
    }
}
#endif
