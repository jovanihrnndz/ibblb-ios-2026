import SwiftUI

struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOffset: CGFloat = 10

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("logo_long_smaller icon BLACK")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .offset(y: logoOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
                logoScale = 1
                logoOffset = 0
            }
        }
    }
}

#if canImport(UIKit)
#Preview {
    SplashView()
}
#endif
