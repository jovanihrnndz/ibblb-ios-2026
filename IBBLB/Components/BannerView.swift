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
                        colors: [Color.black.opacity(0.55), Color.clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.35)
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
