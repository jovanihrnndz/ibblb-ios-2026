//
//  GivingView.swift
//  IBBLB
//
//  Giving page view matching the design specification
//

import SwiftUI

struct GivingView: View {
    @StateObject private var viewModel = GivingViewModel()
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BannerView()
                    .frame(maxWidth: .infinity)
                
                ZStack {
                    Color.white
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Subtitle
                            Text("Trust God with your finances by giving your first 10% back to Him.")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            // Total Given Box
                            VStack(spacing: 8) {
                                Text("$\(Int(viewModel.totalGiven))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                            )
                            .padding(.horizontal, 32)
                            
                            // Give Button
                            Button(action: {
                                viewModel.openGivingURL()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    
                                    Text("Give with Sharefaith Giving")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.0, green: 0.48, blue: 1.0)) // iOS blue
                                )
                            }
                            .padding(.horizontal, 32)
                            
                            // Manage Account Link
                            Button(action: {
                                viewModel.openManageAccount()
                            }) {
                                Text("Manage Your Account & Scheduled Gifts.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer().frame(height: 20)
                            notificationsSection
                                .task {
                                    await notificationManager.refreshAuthorizationStatus()
                                }
                            Spacer().frame(height: 20)
                        }
                        .padding(.top, 8)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .task {
                        await viewModel.loadGivingPage()
                    }
                }
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Sermons")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text("Get notified when a new sermon is posted.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if notificationManager.authorizationStatus == .denied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { notificationManager.isOptedIn },
                            set: { newValue in
                                Task {
                                    if newValue {
                                        await notificationManager.optIn()
                                    } else {
                                        notificationManager.optOut()
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    GivingView()
}
