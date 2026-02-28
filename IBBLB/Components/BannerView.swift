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
        horizontalSizeClass == .regular ? 140 : 100
    }

    var body: some View {
        GeometryReader { geometry in
            Image("churchBanner")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: bannerHeight)
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
        .frame(height: bannerHeight)
    }
}

#if canImport(UIKit)
#Preview {
    BannerView()
}
#endif
