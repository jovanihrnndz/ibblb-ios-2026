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
                .accessibilityLabel("Church banner")
                .accessibilityHidden(false)
        }
        .frame(height: bannerHeight)
    }
}

#Preview {
    BannerView()
}
