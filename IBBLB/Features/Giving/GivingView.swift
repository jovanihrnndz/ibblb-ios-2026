//
//  GivingView.swift
//  IBBLB
//
//  Giving page view matching the design specification
//

import SwiftUI

struct GivingView: View {
    @StateObject private var viewModel = GivingViewModel()
    
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
                            Text(String(localized: "Trust God with your finances by giving your first 10% back to Him."))
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            // Total Given Box - Large display number
                            VStack(spacing: 8) {
                                Text("$\(Int(viewModel.totalGiven))")
                                    .font(.system(size: 48, weight: .bold, design: .rounded)) // Large display number - specific size for emphasis
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
                                        .font(.body.weight(.semibold))
                                        .accessibilityHidden(true)
                                    
                                    Text(String(localized: "Give with Sharefaith Giving"))
                                        .font(.body.weight(.bold))
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
                            .accessibilityLabel(String(localized: "Give with Sharefaith Giving"))
                            .accessibilityHint("Double tap to open the giving page")
                            .accessibilityAddTraits(.isButton)
                            
                            // Manage Account Link
                            Button(action: {
                                viewModel.openManageAccount()
                            }) {
                                Text(String(localized: "Manage Your Account & Scheduled Gifts."))
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            .accessibilityLabel(String(localized: "Manage Your Account & Scheduled Gifts."))
                            .accessibilityHint("Double tap to manage your giving account")
                            .accessibilityAddTraits(.isButton)
                            
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
}

#Preview {
    GivingView()
}
