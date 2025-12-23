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

        // Enable JavaScript (required for YouTube embeds)
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

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
        let baseURL = URL(string: "https://www.youtube-nocookie.com")!
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

        // HTML with proper structure to fix error 153 (referrer/origin issues)
        // Using origin parameter to help YouTube verify the request
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
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
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var currentVideoID: String?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation including YouTube embeds
            decisionHandler(.allow)
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
