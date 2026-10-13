// SPDX-License-Identifier: AGPL-3.0-only
//
//  SpotifyLoginWindow.swift
//  Copied from Sapphire's SpotifyLogin.swift (cookie harvest, login page
//  detection) and AuthLoginWebView.swift (web view setup, social login popups).
//  Sapphire, created by Shariq Charolia on 2026-08-21 and 2026-09-13.
//  Copyright (C) Shariq Charolia. Sapphire is licensed AGPL-3.0.
//  Copied into Vorssaint (GPL-3.0-or-later, combined under GPL-3 section 13).
//  Changes: an AppKit window instead of a SwiftUI sheet, one class instead of
//  a base coordinator plus subclass, no debug prints.

import AppKit
import WebKit

/// A normal Spotify login page in its own window. When the session cookies
/// appear, they are handed back and the window closes.
@MainActor
final class SpotifyLoginWindow: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    private static var current: SpotifyLoginWindow?
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    private let window: NSWindow
    private let webView: WKWebView
    private let onComplete: ([HTTPCookie]) -> Void
    private var popupWindows: [WKWebView: NSWindow] = [:]
    private var isCompleting = false

    static func present(onComplete: @escaping ([HTTPCookie]) -> Void) {
        if let current {
            current.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let login = SpotifyLoginWindow(onComplete: onComplete)
        current = login
        login.show()
    }

    private init(onComplete: @escaping ([HTTPCookie]) -> Void) {
        self.onComplete = onComplete
        let configuration = WKWebViewConfiguration()
        // A fresh, throwaway store: a revoked old session can never auto-complete.
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = Self.desktopUserAgent
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window.title = SpotifyQueueStrings.current.connect
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.delegate = self
    }

    private func show() {
        configurationCookieStore.add(self)
        let url = URL(string: "https://accounts.spotify.com/en/login?continue=https%3A%2F%2Fopen.spotify.com%2F")!
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var configurationCookieStore: WKHTTPCookieStore {
        webView.configuration.websiteDataStore.httpCookieStore
    }

    private func tearDown() {
        configurationCookieStore.remove(self)
        for (_, popup) in popupWindows { popup.close() }
        popupWindows.removeAll()
        window.delegate = nil
        window.close()
        Self.current = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard !isCompleting else { return }
        configurationCookieStore.remove(self)
        for (_, popup) in popupWindows { popup.close() }
        popupWindows.removeAll()
        Self.current = nil
    }

    // MARK: Cookie harvest (Sapphire's checkForFreshSessionCookies)

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in self.checkForFreshSessionCookies() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkForFreshSessionCookies()
    }

    private func checkForFreshSessionCookies() {
        guard !isCompleting else { return }
        configurationCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.isCompleting else { return }
            let spotify = cookies.filter {
                let domain = $0.domain.lowercased()
                return ["sp_dc", "sp_key", "sp_t"].contains($0.name)
                    && (domain == "spotify.com" || domain.hasSuffix(".spotify.com"))
            }
            let hasDC = spotify.contains { $0.name == "sp_dc" }
            let hasKey = spotify.contains { $0.name == "sp_key" }
            let hasT = spotify.contains { $0.name == "sp_t" }
            guard hasDC, hasKey else { return }
            let url = self.webView.url
            let leftLogin = url.map { !Self.looksLikeLoginPage($0) } ?? false
            guard hasT || leftLogin || Self.looksLikeAuthenticatedDestination(url) else { return }
            self.isCompleting = true
            self.tearDown()
            self.onComplete(spotify)
        }
    }

    private static func looksLikeLoginPage(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased(), host.contains("accounts.spotify.com") else { return false }
        let path = url.path.lowercased()
        return path.contains("/login") || path.contains("/signin") || path == "/" || path.isEmpty
    }

    private static func looksLikeAuthenticatedDestination(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased() else { return false }
        if host.contains("open.spotify.com") { return true }
        if host.contains("accounts.spotify.com") {
            let path = url.path.lowercased()
            return path.contains("/status") || path.contains("/login/ok") || path.contains("/oauth")
        }
        return false
    }

    // MARK: Social login popups (Sapphire's AuthLoginCoordinator)

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = Self.desktopUserAgent
        popup.navigationDelegate = self
        popup.uiDelegate = self
        let width = CGFloat(windowFeatures.width?.doubleValue ?? 520)
        let height = CGFloat(windowFeatures.height?.doubleValue ?? 720)
        let popupWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: max(width, 480), height: max(height, 640)),
                                   styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        popupWindow.title = SpotifyQueueStrings.current.connect
        popupWindow.contentView = popup
        popupWindow.isReleasedWhenClosed = false
        popupWindow.center()
        popupWindow.makeKeyAndOrderFront(nil)
        popupWindows[popup] = popupWindow
        popup.load(navigationAction.request)
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        popupWindows.removeValue(forKey: webView)?.close()
    }
}
