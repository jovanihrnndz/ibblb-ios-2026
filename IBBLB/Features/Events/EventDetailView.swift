import SwiftUI

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                ZStack(alignment: .topLeading) {
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
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            labelValue(icon: "calendar", value: event.startDate.formatted(date: .long, time: .shortened))
                            if let location = event.location {
                                labelValue(icon: "mappin.and.ellipse", value: location)
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
        .edgesIgnoringSafeArea(.top)
        .navigationBarHidden(true)
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
