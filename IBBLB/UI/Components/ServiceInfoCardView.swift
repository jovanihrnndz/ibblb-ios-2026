//
//  ServiceInfoCardView.swift
//  IBBLB
//
//  Church service info card with address, times, and contact.
//

import SwiftUI
import MapKit

struct ServiceInfoCardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Church Info Constants

    private let churchName = "Iglesia Bautista Bíblica de Long Beach"
    private let address = "3824 Woodruff Ave, Long Beach, CA 90808"
    private let sundayTime = "Domingo 12:00 PM"
    private let thursdayTime = "Jueves 7:30 PM"
    private let phone = "(562) 912-7107"
    private let email = "info@ibblb.org"

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Información de la Iglesia")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
            }

            Divider()

            // Address Row (Tappable)
            Button(action: openDirections) {
                infoRow(
                    icon: "mappin.and.ellipse",
                    title: "Dirección",
                    value: address,
                    tappable: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Service Times
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .frame(width: 24)

                    Text("Horarios de Servicio")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    timeRow(day: "Domingo", time: "12:00 PM", label: "Servicio de Predicación")
                    timeRow(day: "Domingo", time: "11:00 AM", label: "Escuela Dominical")
                    timeRow(day: "Jueves", time: "7:30 PM", label: "Estudio Bíblico")
                }
                .padding(.leading, 34)
            }

            // Contact Section
            VStack(alignment: .leading, spacing: 12) {
                // Phone
                Button(action: callPhone) {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .font(.body)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Teléfono")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(phone)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Email
                Button(action: sendEmail) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .font(.body)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Correo Electrónico")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Subviews

    private func infoRow(icon: String, title: String, value: String, tappable: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(tappable ? .accentColor : .secondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            if tappable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func timeRow(day: String, time: String, label: String) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 6, height: 6)
                .padding(.trailing, 8)

            Text("\(day) \(time)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(" — ")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func openDirections() {
        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = address

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                if let mapItem = response.mapItems.first {
                    mapItem.name = churchName
                    mapItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                } else {
                    openMapsWithQuery(address)
                }
            } catch {
                openMapsWithQuery(address)
            }
        }
    }

    private func openMapsWithQuery(_ query: String) {
        let encodedAddress = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }

    private func callPhone() {
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleanedPhone)") {
            UIApplication.shared.open(url)
        }
    }

    private func sendEmail() {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ServiceInfoCardView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
