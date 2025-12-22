import SwiftUI
import Combine

struct EventsView: View {
    @StateObject private var viewModel = EventsViewModel()
    
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
                                .foregroundColor(.orange)
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
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.events) { event in
                                    NavigationLink(value: event) {
                                        eventCard(event: event)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding([.horizontal, .bottom])
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
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No hay eventos próximos")
                .font(.headline)
            
            Text("Vuelve pronto para ver nuestras próximas actividades.")
                .foregroundColor(.secondary)
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
