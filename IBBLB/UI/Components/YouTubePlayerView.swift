//
//  YouTubePlayerView.swift
//  IBBLB
//
//  SwiftUI YouTube player (WKWebView) that accepts a YouTube video ID
//

import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    var autoplay: Bool = false
    var startSeconds: Int = 0
    var mute: Bool = false
    var loop: Bool = false
    var controls: Bool = true
    var playsInline: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable Picture-in-Picture for video playback (iOS 15+)
        if #available(iOS 15.0, *) {
            config.allowsPictureInPictureMediaPlayback = true
        }

        // Enable JavaScript (required for YouTube embeds)
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        // SECURITY: Disable JavaScript from opening windows automatically
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Set data store to allow cookies and cache (important for YouTube to not think we're a bot)
        // Note: WKProcessPool is deprecated in iOS 15+ as it's now handled automatically
        if #available(iOS 14.0, *) {
            config.websiteDataStore = .default()
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear

        // ✅ Anti-bot measures: Use realistic Safari user agent
        // This makes YouTube think we're a real Safari browser, not a bot
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        // ✅ Set delegate to detect failures
        webView.navigationDelegate = context.coordinator

        // ✅ Set currentVideoID BEFORE loading to prevent duplicate load in updateUIView
        context.coordinator.currentVideoID = videoID
        load(videoID: videoID, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentVideoID != videoID {
            context.coordinator.currentVideoID = videoID
            load(videoID: videoID, into: webView)
        }
    }

    private func load(videoID: String, into webView: WKWebView) {
        #if DEBUG
        print("📺 Loading YouTube video: '\(videoID)'")
        #endif
        
        // Use HTML string method with proper base URL
        let html = htmlString(for: videoID)
        #if DEBUG
        print("▶️ [YouTube Embed HTML]:", html)
        #endif
        
        // Use base URL matching the embed domain (youtube-nocookie.com)
        // This helps with referrer handling
        guard let baseURL = URL(string: "https://www.youtube-nocookie.com") else {
            #if DEBUG
            print("❌ YouTubePlayerView: Failed to create base URL")
            #endif
            return
        }
        webView.loadHTMLString(html, baseURL: baseURL)
    }
    

    private func htmlString(for videoID: String) -> String {
        let auto = autoplay ? 1 : 0
        let c = controls ? 1 : 0
        let inline = playsInline ? 1 : 0
        let m = mute ? 1 : 0
        let s = max(0, startSeconds)
        let l = loop ? 1 : 0
        let playlistParam = loop ? "&playlist=\(videoID)" : ""

        // Use youtube-nocookie.com without origin parameter
        // Origin parameter can cause error 152 in WKWebView
        // enablejsapi=1 is required for YouTube embeds to work properly in WKWebView
        let src = """
        https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=\(auto)&controls=\(c)&playsinline=\(inline)&start=\(s)&mute=\(m)&loop=\(l)\(playlistParam)&rel=0&modestbranding=1&enablejsapi=1
        """
        
        #if DEBUG
        print("🎬 YouTube Embed: Video ID '\(videoID)' -> Embed URL: \(src)")
        #endif

        // HTML with proper structure and Content Security Policy
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline' https://www.youtube.com https://www.youtube-nocookie.com https://s.ytimg.com; frame-src 'self' https://www.youtube.com https://www.youtube-nocookie.com; style-src 'unsafe-inline'; img-src https://i.ytimg.com https://s.ytimg.com; connect-src https://www.youtube.com https://www.youtube-nocookie.com;">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                iframe { width: 100%; height: 100%; border: 0; }
            </style>
        </head>
        <body>
            <iframe
                src="\(src)"
                frameborder="0"
                sandbox="allow-scripts allow-same-origin allow-presentation"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var currentVideoID: String?

        // Whitelist of allowed hosts for YouTube player
        private let allowedHosts = [
            "www.youtube.com",
            "www.youtube-nocookie.com",
            "youtube.com",
            "youtube-nocookie.com",
            "m.youtube.com",
            "i.ytimg.com",  // For thumbnails
            "s.ytimg.com"   // For static resources
        ]

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // SECURITY: Validate navigation requests
            guard let url = navigationAction.request.url else {
                #if DEBUG
                print("⚠️ YouTube WebView: Blocked navigation - no URL")
                #endif
                decisionHandler(.cancel)
                return
            }

            // Allow about:blank and data URLs for initial load
            if url.scheme == "about" || url.absoluteString.isEmpty {
                decisionHandler(.allow)
                return
            }

            // Ensure HTTPS only (no HTTP, file://, javascript:, etc.)
            guard url.scheme?.lowercased() == "https" else {
                #if DEBUG
                print("⚠️ YouTube WebView: Blocked non-HTTPS navigation to \(url)")
                #endif
                decisionHandler(.cancel)
                return
            }

            // Check if host is in whitelist
            if let host = url.host?.lowercased(),
               allowedHosts.contains(host) || allowedHosts.contains(where: { host.hasSuffix($0) }) {
                decisionHandler(.allow)
            } else {
                #if DEBUG
                print("⚠️ YouTube WebView: Blocked navigation to unauthorized host: \(url.host ?? "unknown")")
                #endif
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            // SECURITY: Verify response is HTTPS
            if let url = navigationResponse.response.url,
               url.scheme?.lowercased() == "https" {
                decisionHandler(.allow)
            } else {
                #if DEBUG
                print("⚠️ YouTube WebView: Blocked non-HTTPS response")
                #endif
                decisionHandler(.cancel)
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            #if DEBUG
            print("🌐 YouTube WebView: Started loading")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            #if DEBUG
            print("✅ YouTube WebView: Finished loading")
            #endif
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ YouTube WebView navigation failed:", error.localizedDescription)
            if let urlError = error as? URLError {
                print("   URL Error Code: \(urlError.code.rawValue)")
                print("   URL Error Description: \(urlError.localizedDescription)")
            }
            #endif
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ YouTube WebView provisional load failed:", error.localizedDescription)
            if let urlError = error as? URLError {
                print("   URL Error Code: \(urlError.code.rawValue)")
                print("   URL Error Description: \(urlError.localizedDescription)")
            }
            #endif
        }
    }
}
