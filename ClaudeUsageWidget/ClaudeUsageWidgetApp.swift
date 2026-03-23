// ClaudeUsageWidgetApp.swift
// Minimal host app — required for the Widget Extension to install.
// This app opens briefly to let the user configure credentials,
// then directs them to add the widget via macOS Widget Gallery.

import SwiftUI
import WidgetKit

@main
struct ClaudeUsageWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Claude Usage Widget", id: "setup") {
            SetupView()
                .frame(width: 440, height: 460)
                .onOpenURL { _ in
                    // claudewidget://setup → show this window
                    appDelegate.showSetupWindow()
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)

        Window("Style Showcase", id: "showcase") {
            ShowcaseView()
                .frame(minWidth: 600, idealWidth: 680, maxWidth: 900,
                       minHeight: 700, idealHeight: 860, maxHeight: 1200)
                .preferredColorScheme(.dark)
        }
        .defaultPosition(.center)
    }
}

struct SetupView: View {
    @State private var sessionKey: String = ""
    @State private var saved = false
    @AppStorage("claude_session_key") private var storedKey = ""
    @AppStorage("auto_poll_interval_minutes") private var pollIntervalMinutes: Int = 0

    var body: some View {
        ZStack {
            Color(red: 0.078, green: 0.067, blue: 0.055).ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent.badge.arrow.up")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [Color(red: 0.133, green: 0.773, blue: 0.369), Color(red: 0.788, green: 0.392, blue: 0.259)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )

                    Text("Claude Usage Widget")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    Text("Native macOS widget for your Claude.ai usage")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }

                Divider().background(Color.white.opacity(0.08))

                // Auth status
                if hasClaudeCodeCredentials() {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(Color(red: 0.133, green: 0.773, blue: 0.369))
                        Text("Claude Code OAuth detected — widget is ready!")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Session key input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SESSION KEY OR FULL COOKIE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                            .kerning(0.8)

                        Text("Paste the full cookie string OR just the sessionKey value")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))

                        HStack(spacing: 8) {
                            TextField("Paste full cookie or sk-ant-sid02-…", text: $sessionKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button("Save") {
                                let shared = UserDefaults(suiteName: "YOUR_TEAM_ID.group.com.claude.usagewidget")
                                let input = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)

                                // Smart parse: user might paste full cookie string OR just the key
                                if input.contains("sessionKey=") {
                                    // Full cookie string — extract sessionKey value
                                    let parts = input.components(separatedBy: ";")
                                    for part in parts {
                                        let t = part.trimmingCharacters(in: .whitespaces)
                                        if t.hasPrefix("sessionKey=") {
                                            let key = String(t.dropFirst("sessionKey=".count))
                                            shared?.set(key, forKey: "claude_session_key")
                                            storedKey = key
                                        }
                                        if t.hasPrefix("lastActiveOrg=") {
                                            let orgId = String(t.dropFirst("lastActiveOrg=".count))
                                            if orgId.count == 36 {
                                                shared?.set(orgId, forKey: "claude_org_id")
                                            }
                                        }
                                    }
                                } else {
                                    // Just the raw key value (sk-ant-sid02-...)
                                    shared?.set(input, forKey: "claude_session_key")
                                    storedKey = input
                                }

                                WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageNativeWidget")
                                saved = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.788, green: 0.392, blue: 0.259))
                            .disabled(sessionKey.isEmpty)
                        }

                        if saved {
                            Label("Saved — widget will refresh", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(red: 0.133, green: 0.773, blue: 0.369))
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Auto-poll interval
                VStack(alignment: .leading, spacing: 6) {
                    Text("AUTO-POLL INTERVAL")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .kerning(0.8)

                    Text("Automatically check usage at a set interval, or refresh manually")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))

                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { pollIntervalMinutes > 0 },
                            set: { on in pollIntervalMinutes = on ? 15 : 0 }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .tint(Color(red: 0.788, green: 0.392, blue: 0.259))

                        if pollIntervalMinutes > 0 {
                            Text("Every")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))

                            TextField("15", value: $pollIntervalMinutes, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .frame(width: 46)
                                .onChange(of: pollIntervalMinutes) { _, v in
                                    if v < 1 { pollIntervalMinutes = 1 }
                                    if v > 1440 { pollIntervalMinutes = 1440 }
                                }

                            Text("min")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()

                            ForEach([5, 15, 30, 60], id: \.self) { preset in
                                Button(preset < 60 ? "\(preset)m" : "1h") {
                                    pollIntervalMinutes = preset
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(pollIntervalMinutes == preset ? Color(red: 0.788, green: 0.392, blue: 0.259) : Color.white.opacity(0.35))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(pollIntervalMinutes == preset ? Color(red: 0.788, green: 0.392, blue: 0.259).opacity(0.15) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        } else {
                            Text("Off — click or ⌘R to refresh manually")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    instructionRow(num: "1", text: "Right-click your desktop → Edit Widgets")
                    instructionRow(num: "2", text: "Search for \"Claude Usage\"")
                    instructionRow(num: "3", text: "Drag it to your desktop or Notification Center")
                }

                Spacer()

                Text("You can close this app — the widget runs independently")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(28)
        }
        .onAppear { }
    }

    /// Loads credentials from CLI / .env and saves them to
    /// the shared App Group UserDefaults so the sandboxed
    /// widget extension can access them.
    private func syncCredentialsToSharedDefaults() {
        let shared = UserDefaults(suiteName: "YOUR_TEAM_ID.group.com.claude.usagewidget")
        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Try Claude Code CLI OAuth
        for path in [".claude/.credentials.json", ".claude/credentials.json"] {
            let url = home.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String, !token.isEmpty
            else { continue }

            shared?.set(token, forKey: "claude_oauth_token")
            WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageNativeWidget")
            return
        }

        // 2. Try .env file
        let envURL = home.appendingPathComponent(".claude-usage/.env")
        if let raw = try? String(contentsOf: envURL, encoding: .utf8) {
            for line in raw.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("sessionKey=") {
                    let key = String(t.dropFirst("sessionKey=".count)).trimmingCharacters(in: .init(charactersIn: ";, \t"))
                    shared?.set(key, forKey: "claude_session_key")
                }
                if t.hasPrefix("lastActiveOrg=") {
                    let id = String(t.dropFirst("lastActiveOrg=".count)).trimmingCharacters(in: .init(charactersIn: ";, \t"))
                    if id.count == 36 { shared?.set(id, forKey: "claude_org_id") }
                }
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeUsageNativeWidget")
        }
    }

    private func instructionRow(num: String, text: String) -> some View {
        HStack(spacing: 10) {
            Text(num)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.788, green: 0.392, blue: 0.259))
                .frame(width: 20, height: 20)
                .background(Color(red: 0.788, green: 0.392, blue: 0.259).opacity(0.15))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func hasClaudeCodeCredentials() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for path in [".claude/.credentials.json", ".claude/credentials.json"] {
            let url = home.appendingPathComponent(path)
            if let data = try? Data(contentsOf: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let oauth = json["claudeAiOauth"] as? [String: Any],
               let token = oauth["accessToken"] as? String, !token.isEmpty {
                return true
            }
        }
        return false
    }
}
