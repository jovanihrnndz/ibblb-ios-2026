//
//  BannerView.swift
//  IBBLB
//
//  Created by jovani hernandez on 12/21/25.
//


import SwiftUI

struct BannerView: View {
    var body: some View {
        GeometryReader { geometry in
            Image("churchBanner")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: 100)
                .clipped()
        }
        .frame(height: 100)
    }
}

#Preview {
    BannerView()
}