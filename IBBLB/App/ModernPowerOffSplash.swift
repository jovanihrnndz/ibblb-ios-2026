import SwiftUI

/// A modern "retro CRT TV power-off" splash screen effect with two phases:
/// 1. **Loading Phase**: Logo fades in and stays visible while app loads
/// 2. **Power-Off Phase**: Background collapses while logo fades out gracefully
///
/// Respects `UIAccessibility.isReduceMotionEnabled` for accessibility.
struct ModernPowerOffSplash: View {
    @Binding var isPresented: Bool

    // MARK: - Configuration

    /// Logo image name in asset catalog
    var logoImageName: String = "logo_long_smaller icon BLACK"

    /// Maximum width for the logo
    var logoMaxWidth: CGFloat = 280

    /// Background color (typically matches your app's launch screen)
    var backgroundColor: Color = .white

    // MARK: - Timing Configuration

    /// Duration for logo fade-in at start
    private let logoFadeInDuration: TimeInterval = 0.5

    /// Minimum time logo stays visible before power-off can begin
    private let minimumLoadingTime: TimeInterval = 2.2

    /// Duration of the vertical collapse animation
    private let collapseDuration: TimeInterval = 0.28

    /// Duration the electron line persists
    private let electronLineDuration: TimeInterval = 0.18

    // MARK: - Animation State

    @State private var phase: AnimationPhase = .loading
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.96
    @State private var logoParallaxScale: CGFloat = 1.0
    @State private var backgroundVerticalScale: CGFloat = 1.0
    @State private var electronLineOpacity: Double = 0
    @State private var electronLineScale: CGFloat = 1.0
    @State private var canTriggerPowerOff: Bool = false

    #if canImport(UIKit)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    #else
    private var reduceMotion: Bool = false
    #endif

    private enum AnimationPhase {
        case loading
        case poweringOff
        case complete
    }

    var body: some View {
        ZStack {
            // Layer 1: Collapsing white background
            collapsingBackground

            // Layer 2: Logo (stays in place, fades out)
            logoView

            // Layer 3: Electron line flash
            electronLine
        }
        .ignoresSafeArea()
        .onAppear {
            startLoadingPhase()
        }
    }

    // MARK: - Subviews

    /// The white background that collapses vertically
    private var collapsingBackground: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor

                // Subtle vignette for depth
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.04)
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: geometry.size.height * 0.7
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(x: 1.0, y: backgroundVerticalScale)
        }
        .ignoresSafeArea()
    }

    /// Logo that stays centered with parallax zoom effect
    private var logoView: some View {
        Image(logoImageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: logoMaxWidth)
            .opacity(logoOpacity)
            .scaleEffect(logoScale * logoParallaxScale)
    }

    /// Electron line with glow effect
    private var electronLine: some View {
        ZStack {
            // Outer glow
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(height: 6)
                .blur(radius: 8)

            // Inner bright line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.8),
                            Color.white,
                            Color.white.opacity(0.8),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)

            // Core bright center
            Rectangle()
                .fill(Color.white)
                .frame(width: 200, height: 1)
                .blur(radius: 0.5)
        }
        .opacity(electronLineOpacity)
        .scaleEffect(x: electronLineScale, y: 1.0)
    }

    // MARK: - Animation Logic

    private func startLoadingPhase() {
        if reduceMotion {
            logoOpacity = 1
            logoScale = 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.3)) {
                    logoOpacity = 0
                    backgroundVerticalScale = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isPresented = false
                }
            }
            return
        }

        // Fade in the logo with subtle scale
        withAnimation(.easeOut(duration: logoFadeInDuration)) {
            logoOpacity = 1
            logoScale = 1.0
        }

        // After hold time, trigger power-off
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumLoadingTime) {
            canTriggerPowerOff = true
            triggerPowerOff()
        }
    }

    private func triggerPowerOff() {
        guard canTriggerPowerOff, phase == .loading else { return }
        phase = .poweringOff

        // Parallax zoom in - logo comes toward you as CRT collapses
        withAnimation(.easeOut(duration: collapseDuration * 0.9)) {
            logoParallaxScale = 1.15
        }

        // Fade out logo
        withAnimation(.easeOut(duration: collapseDuration * 0.6)) {
            logoOpacity = 0
        }

        // Collapse background with custom curve (fast start, smooth end)
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: collapseDuration)) {
            backgroundVerticalScale = 0.0
        }

        // Flash electron line as background finishes collapsing
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration * 0.6) {
            // Electron line appears
            withAnimation(.easeOut(duration: 0.06)) {
                electronLineOpacity = 1.0
            }
        }

        // Electron line fades and shrinks
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration + 0.08) {
            withAnimation(.easeOut(duration: electronLineDuration)) {
                electronLineOpacity = 0
                electronLineScale = 0.3
            }
        }

        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration + electronLineDuration + 0.1) {
            phase = .complete
            isPresented = false
        }
    }
}

// MARK: - Preview

#if canImport(UIKit)
#Preview("Power Off Effect") {
    struct PreviewWrapper: View {
        @State private var showSplash = true

        var body: some View {
            ZStack {
                // Simulated app content
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    Text("App Content")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Visible after splash")
                        .foregroundStyle(.secondary)
                }

                if showSplash {
                    ModernPowerOffSplash(isPresented: $showSplash)
                        .zIndex(100)
                }
            }
        }
    }

    return PreviewWrapper()
}

#Preview("Reduced Motion") {
    struct ReducedMotionWrapper: View {
        @State private var showSplash = true

        var body: some View {
            ZStack {
                Color.green.opacity(0.3)
                    .ignoresSafeArea()
                Text("Enable Reduce Motion in Settings to test")
                    .multilineTextAlignment(.center)
                    .padding()

                if showSplash {
                    ModernPowerOffSplash(isPresented: $showSplash)
                        .zIndex(100)
                }
            }
        }
    }

    return ReducedMotionWrapper()
}
#endif
