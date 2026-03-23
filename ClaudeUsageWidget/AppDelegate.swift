// AppDelegate.swift

import AppKit
import SwiftUI
import WidgetKit

class AppDelegate: NSObject, NSApplicationDelegate {

    // Direct reference to the setup window, captured at launch
    private weak var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncCredentials()
        WidgetCenter.shared.reloadAllTimelines()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Capture the setup window — it's the first window created (lowest windowNumber),
            // titled "Claude Usage Widget" by the SwiftUI Window scene.
            self.setupWindow = NSApplication.shared.windows
                .filter { !($0 is NSPanel) }
                .min(by: { $0.windowNumber < $1.windowNumber })

            if CommandLine.arguments.contains("--background") {
                NSApplication.shared.windows.forEach { $0.orderOut(nil) }
                NSApplication.shared.setActivationPolicy(.accessory)
            } else {
                self.configureAllWindows()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    // When user taps Done in "Edit Claude Usage" panel (openAppWhenRun = true), app activates here.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard CommandLine.arguments.contains("--background") else { return }
        NSApplication.shared.setActivationPolicy(.regular)
        showSetupWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSetupWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        if let win = setupWindow {
            win.makeKeyAndOrderFront(nil)
        } else {
            NSApplication.shared.windows
                .filter { !($0 is NSPanel) }
                .min(by: { $0.windowNumber < $1.windowNumber })?
                .makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func windowDidBecomeKey(_ note: Notification) {
        guard let window = note.object as? NSWindow else { return }
        configureWindow(window)
    }

    private func configureAllWindows() {
        for window in NSApp.windows { configureWindow(window) }
    }

    private func configureWindow(_ window: NSWindow) {
        guard window.identifier?.rawValue.contains("widget") == true
           || window.title.contains("Claude")
           || window.contentView?.subviews.isEmpty == false else { return }

        window.level = .floating
        window.titlebarAppearsTransparent = true
        window.titleVisibility            = .hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.resizable)
        window.isMovableByWindowBackground = true
        window.appearance      = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque        = false
        window.hasShadow       = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
    }

    func syncCredentials() {
        let shared = UserDefaults(suiteName: "YOUR_TEAM_ID.group.com.claude.usagewidget")
        let home = FileManager.default.homeDirectoryForCurrentUser

        for path in [".claude/.credentials.json", ".claude/credentials.json"] {
            let url = home.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String, !token.isEmpty else { continue }
            shared?.set(token, forKey: "claude_oauth_token")
            return
        }

        let envURL = home.appendingPathComponent(".claude-usage/.env")
        if let raw = try? String(contentsOf: envURL, encoding: .utf8) {
            for line in raw.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("sessionKey=") {
                    shared?.set(
                        String(t.dropFirst("sessionKey=".count)).trimmingCharacters(in: .init(charactersIn: ";, \t")),
                        forKey: "claude_session_key"
                    )
                }
                if t.hasPrefix("lastActiveOrg=") {
                    let id = String(t.dropFirst("lastActiveOrg=".count)).trimmingCharacters(in: .init(charactersIn: ";, \t"))
                    if id.count == 36 { shared?.set(id, forKey: "claude_org_id") }
                }
            }
        }
    }
}
