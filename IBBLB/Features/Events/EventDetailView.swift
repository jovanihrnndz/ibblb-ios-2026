import SwiftUI
import MapKit

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
                                labelValue(icon: "calendar", value: event.startDate.formattedEventDate())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Add event to calendar")
                            .accessibilityHint("Double tap to add this event to your calendar")
                            .accessibilityAddTraits(.isButton)

                            if let location = event.location {
                                Button(action: openInMaps) {
                                    labelValue(icon: "mappin.and.ellipse", value: location)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Open location in Maps: \(location)")
                                .accessibilityHint("Double tap to open the event location in Maps")
                                .accessibilityAddTraits(.isButton)
                            }
                        }
                    }

                    Divider()

                    // Description
                    if let description = event.description {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "Details"))
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
                            Text(String(localized: "Register for this event"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                        .accessibilityLabel("Register for this event")
                        .accessibilityHint("Double tap to register for this event")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(String(localized: "Event"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(isSuccess ? String(localized: "Success") : String(localized: "Error"), isPresented: $showingCalendarAlert) {
            Button(String(localized: "OK"), role: .cancel) { }
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
                alertMessage = String(localized: "The event has been added to your calendar.")
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
                    // Fallback: Open Maps with the address string
                    openMapsWithQuery(location)
                }
            } catch {
                // Fallback: Open Maps with the address string
                openMapsWithQuery(location)
            }
        }
    }

    private func openMapsWithQuery(_ query: String) {
        let encodedAddress = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }

    private func labelValue(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
