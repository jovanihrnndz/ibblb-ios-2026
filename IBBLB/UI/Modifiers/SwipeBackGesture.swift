//
//  SwipeBackGesture.swift
//  IBBLB
//
//  Re-enables swipe-back gesture when navigation bar back button is hidden.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A view modifier that enables the interactive pop gesture even when the back button is hidden.
struct SwipeBackGestureModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit)
            content
                .background(SwipeBackGestureEnabler())
        #else
            content
        #endif
    }
}

/// UIViewControllerRepresentable that enables the interactive pop gesture.
#if canImport(UIKit)
    private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIViewController {
            SwipeBackGestureController()
        }

        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    }

    /// Controller that enables the interactive pop gesture on its navigation controller.
    private final class SwipeBackGestureController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
#endif

extension View {
    /// Enables swipe-back gesture even when the navigation bar back button is hidden.
    func enableSwipeBack() -> some View {
        modifier(SwipeBackGestureModifier())
    }
}
