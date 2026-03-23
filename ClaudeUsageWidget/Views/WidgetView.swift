// WidgetView.swift
// The main widget — wraps Style4_NeonArc with:
//   • Double-tap to refresh
//   • Swipe-down to refresh (drag gesture)
//   • ⌘R keyboard shortcut
//   • Right-click context menu (settings, quit)
//   • Auto-refresh every 15 minutes
//   • Smooth pull-to-refresh animation
//   • Draggable by background

import SwiftUI

struct WidgetView: View {
    @StateObject private var api = APIService()
    @State private var showSettings = false
    @State private var pullOffset: CGFloat = 0
    @State private var isPulling = false
    @State private var refreshFlash = false
    @State private var countdownTick = Date()

    // Auto-poll interval in minutes; 0 = off (manual only)
    @AppStorage("auto_poll_interval_minutes") private var pollIntervalMinutes: Int = 0
    // Countdown update every 30 seconds
    private let countdownTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var displayData: UsageData {
        api.usageData ?? .placeholder
    }

    var body: some View {
        ZStack {
            // ── The widget itself ──────────────────────────────────────
            Style4_NeonArc(
                data: displayData,
                onRefresh: { doRefresh() },
                isLoading: api.isLoading,
                lastFetched: api.lastFetched
            )
            .offset(y: pullOffset)

            // ── Pull indicator ─────────────────────────────────────────
            if isPulling {
                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(pullOffset * 4))
                    Spacer()
                }
                .padding(.top, 10)
                .transition(.opacity)
            }

            // ── Error banner ───────────────────────────────────────────
            if let err = api.errorMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "#F59E0B"))
                        Text(err)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1A1714").opacity(0.95))
                    .clipShape(Capsule())
                    .padding(.bottom, 6)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Refresh flash overlay ─────────────────────────────────
            if refreshFlash {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // ── Auth mode indicator ──────────────────────────────────
            if api.usageData == nil && !api.isLoading {
                VStack {
                    Spacer()
                    authBadge()
                        .padding(.bottom, 44)
                }
            }
        }
        .frame(width: 320, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

        // ── Gestures ──────────────────────────────────────────────────

        // Double-tap → refresh
        .onTapGesture(count: 2) { doRefresh() }

        // Swipe-down → pull to refresh
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    let dy = value.translation.height
                    guard dy > 0 else { return }
                    withAnimation(.interactiveSpring()) {
                        pullOffset = min(dy * 0.4, 40)
                        isPulling  = true
                    }
                }
                .onEnded { value in
                    let dy = value.translation.height
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        pullOffset = 0
                        isPulling  = false
                    }
                    if dy > 50 { doRefresh() }
                }
        )

        // ⌘R → refresh
        .keyboardShortcut("r", modifiers: .command)

        // Right-click context menu
        .contextMenu { contextMenuItems() }

        // ── Lifecycle ─────────────────────────────────────────────────
        .onAppear { api.refresh() }
        .onReceive(countdownTimer) { _ in countdownTick = Date() }
        // Dynamic auto-poll: restarts automatically when pollIntervalMinutes changes
        .task(id: pollIntervalMinutes) {
            guard pollIntervalMinutes > 0 else { return }
            let minutes = max(1, min(pollIntervalMinutes, 1440))
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                api.refresh()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(api: api, isPresented: $showSettings)
        }
    }

    // MARK: - Refresh action with flash

    private func doRefresh() {
        api.refresh()
        withAnimation(.easeIn(duration: 0.1)) { refreshFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.3)) { refreshFlash = false }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuItems() -> some View {
        Button("Refresh  ⌘R") { doRefresh() }

        Divider()

        Button("Settings…") { showSettings = true }

        Divider()

        switch api.authMode {
        case .cliOAuth:
            Text("Auth: Claude Code OAuth")
        case .sessionKey:
            Text("Auth: Session Key")
        case .none:
            Text("Auth: Not configured")
        }

        if let d = api.lastFetched {
            Text("Last: \(d, format: .dateTime.hour().minute())")
        }

        Divider()

        Button("Quit") { NSApp.terminate(nil) }
    }

    // MARK: - Auth badge

    @ViewBuilder
    private func authBadge() -> some View {
        HStack(spacing: 5) {
            Image(systemName: api.authMode == .none ? "key.slash" : "key.fill")
                .font(.system(size: 9))
                .foregroundColor(api.authMode == .none ? Color(hex: "#F59E0B") : Color(hex: "#22C55E"))

            Text(api.authMode == .none
                 ? "Right-click → Settings to add credentials"
                 : "Fetching…")
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(hex: "#1A1714").opacity(0.9))
        .clipShape(Capsule())
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var api: APIService
    @Binding var isPresented: Bool
    @State private var keyInput: String = ""
    @AppStorage("auto_poll_interval_minutes") private var pollIntervalMinutes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                Text("Widget Settings")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.white.opacity(0.08))

            // Auth status
            HStack(spacing: 8) {
                Image(systemName: authIcon)
                    .font(.system(size: 13))
                    .foregroundColor(authColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(authTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text(authSubtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(authColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(authColor.opacity(0.3), lineWidth: 0.8)
            )

            // Session key input
            VStack(alignment: .leading, spacing: 6) {
                Text("SESSION KEY")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(0.8)

                Text("From claude.ai → DevTools → Application → Cookies → sessionKey")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))

                HStack(spacing: 8) {
                    TextField("sk-ant-sid02-…", text: $keyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.7)
                        )

                    Button("Save") {
                        api.saveSessionKey(keyInput)
                        api.refresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#C96442"))
                    .controlSize(.small)
                    .disabled(keyInput.isEmpty)
                }
            }

            Divider().background(Color.white.opacity(0.08))

            // Auto-poll interval
            VStack(alignment: .leading, spacing: 6) {
                Text("AUTO-POLL INTERVAL")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(0.8)

                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { pollIntervalMinutes > 0 },
                        set: { on in pollIntervalMinutes = on ? 15 : 0 }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .tint(Color(hex: "#C96442"))

                    if pollIntervalMinutes > 0 {
                        Text("Every")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
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
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.7))
                            .frame(width: 46)
                            .onChange(of: pollIntervalMinutes) { _, v in
                                if v < 1 { pollIntervalMinutes = 1 }
                                if v > 1440 { pollIntervalMinutes = 1440 }
                            }

                        Text("min")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        ForEach([5, 15, 30, 60], id: \.self) { preset in
                            Button(preset < 60 ? "\(preset)m" : "1h") {
                                pollIntervalMinutes = preset
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(pollIntervalMinutes == preset ? Color(hex: "#C96442") : .white.opacity(0.35))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(pollIntervalMinutes == preset ? Color(hex: "#C96442").opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    } else {
                        Text("Off — click or ⌘R to refresh manually")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                }
            }

            // Info text
            VStack(alignment: .leading, spacing: 4) {
                Label("If Claude Code is installed, credentials are loaded automatically", systemImage: "sparkles")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))

                Label("Double-tap or ⌘R to refresh · Swipe down to pull-refresh", systemImage: "hand.tap")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))

                Label(
                    pollIntervalMinutes > 0
                        ? "Auto-polls every \(pollIntervalMinutes) min"
                        : "Manual refresh only — auto-poll is off",
                    systemImage: "timer"
                )
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 420)
        .background(Color(hex: "#141210"))
    }

    // MARK: - Auth status display

    private var authIcon: String {
        switch api.authMode {
        case .cliOAuth:   return "checkmark.shield.fill"
        case .sessionKey: return "key.fill"
        case .none:       return "key.slash"
        }
    }

    private var authColor: Color {
        switch api.authMode {
        case .cliOAuth:   return Color(hex: "#22C55E")
        case .sessionKey: return Color(hex: "#38BDF8")
        case .none:       return Color(hex: "#F59E0B")
        }
    }

    private var authTitle: String {
        switch api.authMode {
        case .cliOAuth:   return "Claude Code OAuth"
        case .sessionKey: return "Session Key"
        case .none:       return "Not Configured"
        }
    }

    private var authSubtitle: String {
        switch api.authMode {
        case .cliOAuth(let expires):
            if let e = expires {
                return "Token expires: \(e.formatted(.dateTime.month().day().hour().minute()))"
            }
            return "Auto-refreshed by Claude Code"
        case .sessionKey: return "Loaded from .env or manual entry"
        case .none:       return "Paste a sessionKey or install Claude Code"
        }
    }
}

#Preview {
    WidgetView()
        .preferredColorScheme(.dark)
}
