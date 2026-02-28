//
//  BannerView.swift
//  IBBLB
//
//  Created by jovani hernandez on 12/21/25.
//


import SwiftUI

struct BannerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Banner height scales with size class
    private var bannerHeight: CGFloat {
        horizontalSizeClass == .regular ? 160 : 120
    }

    var body: some View {
        Image("churchBanner")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, minHeight: bannerHeight, maxHeight: bannerHeight)
            .clipped()
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.75), location: 0.0),
                        .init(color: .black.opacity(0.75), location: 0.3),
                        .init(color: .clear,               location: 0.6),
                        .init(color: Color(.systemBackground), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

#if canImport(UIKit)
#Preview {
    BannerView()
}
#endif
