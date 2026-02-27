import SwiftUI
#if canImport(MapKit)
import MapKit
#endif

struct EventDetailView: View {
    let event: Event
    @State private var showingCalendarAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                if let imageUrl = event.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image.resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    Color.accentColor.opacity(0.1)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fill)
                }

                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack(spacing: 16) {
                            Button(action: addToCalendar) {
                                labelValue(icon: "calendar", value: event.startDate.formatted(date: .long, time: .shortened))
                            }
                            .buttonStyle(PlainButtonStyle())

                            if let location = event.location {
                                Button(action: openInMaps) {
                                    labelValue(icon: "mappin.and.ellipse", value: location)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    Divider()

                    // Description
                    if let description = event.description {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Detalles")
                                .font(.headline)

                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    Spacer(minLength: 40)

                    // Registration
                    if event.registrationEnabled == true {
                        Button(action: {
                            // Registration action
                        }) {
                            Text("Registrarse para este evento")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Evento")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isSuccess ? "Éxito" : "Error", isPresented: $showingCalendarAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func addToCalendar() {
        Task {
            do {
                try await CalendarManager.shared.addEvent(
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    notes: event.description
                )
                isSuccess = true
                alertMessage = "El evento se ha agregado a tu calendario."
                showingCalendarAlert = true
            } catch {
                isSuccess = false
                alertMessage = error.localizedDescription
                showingCalendarAlert = true
            }
        }
    }

    private func openInMaps() {
        guard let location = event.location else { return }

        #if canImport(MapKit)
            Task {
                do {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = location

                    let search = MKLocalSearch(request: request)
                    let response = try await search.start()

                    if let mapItem = response.mapItems.first {
                        mapItem.name = event.title
                        mapItem.openInMaps(launchOptions: [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                        ])
                    } else {
                        openMapsWithQuery(location)
                    }
                } catch {
                    openMapsWithQuery(location)
                }
            }
        #else
            openMapsWithQuery(location)
        #endif
    }

    private func openMapsWithQuery(_ query: String) {
        let encodedAddress = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        #if canImport(UIKit)
            if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
                Task { @MainActor in
                    await UIApplication.shared.open(url)
                }
            }
        #else
            if let url = URL(string: "https://maps.google.com/?q=\(encodedAddress)") {
                _ = url
            }
        #endif
    }

    private func labelValue(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
