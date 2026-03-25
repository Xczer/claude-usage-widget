// ClaudeUsageWidget.swift
// macOS native WidgetKit extension — Neon Arc style.
//
// Adapts the Neon Arc gauge for WidgetKit's static rendering:
//   • No custom animations (WidgetKit limitation)
//   • Uses Text(date, style: .timer) for live countdown
//   • Button(intent:) for manual refresh
//   • .containerBackground for the dark + neon aesthetic
//   • Supports: systemSmall, systemMedium, systemLarge

import WidgetKit
import SwiftUI
import AppIntents
import UserNotifications

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Timeline Entry
// ═══════════════════════════════════════════════════════════════════════

struct UsageEntry: TimelineEntry {
    let date: Date

    let fiveHourUtilization: Double    // 0–100
    let fiveHourResetsAt: Date
    let sevenDayUtilization: Double
    let sevenDayResetsAt: Date
    let sonnetUtilization: Double?     // nil = not Pro
    let sonnetResetsAt: Date?

    let isError: Bool
    let errorMessage: String?

    /// Returns "Xh Xm" or "Xm" — no seconds ticking
    func timeRemaining(to date: Date) -> String {
        let secs = max(0, date.timeIntervalSinceNow)
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var fiveHourLevel: Level {
        switch fiveHourUtilization {
        case ..<50:  return .healthy
        case 50..<75: return .moderate
        case 75..<90: return .high
        default:      return .critical
        }
    }

    var sevenDayLevel: Level {
        switch sevenDayUtilization {
        case ..<50:  return .healthy
        case 50..<75: return .moderate
        case 75..<90: return .high
        default:      return .critical
        }
    }

    enum Level {
        case healthy, moderate, high, critical

        var color: Color {
            switch self {
            case .healthy:  return Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
            case .moderate: return Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
            case .high:     return Color(red: 0.976, green: 0.451, blue: 0.086) // #F97316
            case .critical: return Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
            }
        }

        var label: String {
            switch self {
            case .healthy:  return "HEALTHY"
            case .moderate: return "MODERATE"
            case .high:     return "HIGH"
            case .critical: return "NEAR LIMIT"
            }
        }

        var icon: String {
            switch self {
            case .healthy:  return "checkmark.circle.fill"
            case .moderate: return "minus.circle.fill"
            case .high:     return "exclamationmark.circle.fill"
            case .critical: return "xmark.circle.fill"
            }
        }
    }

    // ── Placeholder / preview data ──

    static let placeholder = UsageEntry(
        date: .now,
        fiveHourUtilization: 43,
        fiveHourResetsAt: Date().addingTimeInterval(2 * 3600),
        sevenDayUtilization: 28,
        sevenDayResetsAt: Date().addingTimeInterval(3 * 86400),
        sonnetUtilization: 14,
        sonnetResetsAt: Date().addingTimeInterval(3 * 86400),
        isError: false,
        errorMessage: nil
    )

    static let error = UsageEntry(
        date: .now,
        fiveHourUtilization: 0,
        fiveHourResetsAt: .now,
        sevenDayUtilization: 0,
        sevenDayResetsAt: .now,
        sonnetUtilization: nil,
        sonnetResetsAt: nil,
        isError: true,
        errorMessage: "Check credentials"
    )
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Intents
// ═══════════════════════════════════════════════════════════════════════

struct RefreshUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Usage"
    static var description = IntentDescription("Fetches the latest Claude usage data.")
    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// Widget configuration intent — session key can be pasted directly in the Edit popup
struct ClaudeWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Claude Usage"
    static var description = IntentDescription(
        "Paste your session key below — or tap Done to open the full setup window.\n\nGet it from claude.ai → DevTools → Application → Cookies → sessionKey"
    )
    static var openAppWhenRun: Bool { get { true } }

    @Parameter(
        title: "Session Key",
        description: "Your sk-ant-sid02-… value from claude.ai cookies",
        inputOptions: String.IntentInputOptions(capitalizationType: .none, autocorrect: false, smartQuotes: false, smartDashes: false)
    )
    var sessionKey: String?

    @Parameter(
        title: "Org ID (optional)",
        description: "lastActiveOrg UUID — auto-detected if blank",
        inputOptions: String.IntentInputOptions(capitalizationType: .none, autocorrect: false, smartQuotes: false, smartDashes: false)
    )
    var orgId: String?
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Timeline Provider
// ═══════════════════════════════════════════════════════════════════════

struct UsageProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsageEntry { .placeholder }

    func snapshot(for configuration: ClaudeWidgetConfiguration, in context: Context) async -> UsageEntry {
        .placeholder
    }

    func timeline(for configuration: ClaudeWidgetConfiguration, in context: Context) async -> Timeline<UsageEntry> {
        // Persist any credentials entered via the Edit popup
        let shared = UserDefaults(suiteName: "YOUR_TEAM_ID.group.com.claude.usagewidget")
        if let key = configuration.sessionKey, !key.isEmpty {
            // Smart parse: user might paste full cookie string or just the key
            if key.contains("sessionKey=") {
                for part in key.components(separatedBy: ";") {
                    let t = part.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("sessionKey=") {
                        shared?.set(String(t.dropFirst("sessionKey=".count)), forKey: "claude_session_key")
                    }
                    if t.hasPrefix("lastActiveOrg=") {
                        let id = String(t.dropFirst("lastActiveOrg=".count))
                        if id.count == 36 { shared?.set(id, forKey: "claude_org_id") }
                    }
                }
            } else {
                shared?.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "claude_session_key")
            }
        }
        if let org = configuration.orgId, org.count == 36 {
            shared?.set(org, forKey: "claude_org_id")
        }

        let entry = await fetchEntry()

        if !entry.isError { UsageNotifier.checkAndNotify(entry: entry) }

        return Timeline(entries: [entry], policy: .never)
    }

    // ── Network fetch ──

    private func fetchEntry() async -> UsageEntry {
        let creds = loadCredentials()

        guard let authHeader = creds.authHeader, let authValue = creds.authValue else {
            NSLog("[ClaudeWidget] ERROR: No credentials found")
            return UsageEntry(
                date: .now,
                fiveHourUtilization: 0, fiveHourResetsAt: .now,
                sevenDayUtilization: 0, sevenDayResetsAt: .now,
                sonnetUtilization: nil, sonnetResetsAt: nil,
                isError: true, errorMessage: "No credentials"
            )
        }

        // Resolve org ID
        let orgId: String
        if let cached = creds.orgId, !cached.isEmpty {
            orgId = cached
        } else if let bootstrapped = await bootstrapOrgId(authHeader: authHeader, authValue: authValue) {
            orgId = bootstrapped
        } else {
            NSLog("[ClaudeWidget] ERROR: Could not resolve orgId")
            return UsageEntry(
                date: .now,
                fiveHourUtilization: 0, fiveHourResetsAt: .now,
                sevenDayUtilization: 0, sevenDayResetsAt: .now,
                sonnetUtilization: nil, sonnetResetsAt: nil,
                isError: true, errorMessage: "No org ID"
            )
        }

        // Fetch usage
        let urlStr = "https://claude.ai/api/organizations/\(orgId)/usage"
        guard let url = URL(string: urlStr) else { return .error }

        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue(authValue, forHTTPHeaderField: authHeader)
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authHeader == "Cookie" {
            req.setValue("https://claude.ai",  forHTTPHeaderField: "Origin")
            req.setValue("https://claude.ai/",  forHTTPHeaderField: "Referer")
            req.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        } else {
            req.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
            req.setValue("oauth-2025-04-20",  forHTTPHeaderField: "anthropic-beta")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let http = response as? HTTPURLResponse

            guard let http = http, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                NSLog("[ClaudeWidget] ERROR: HTTP %d", code)
                return UsageEntry(
                    date: .now,
                    fiveHourUtilization: 0, fiveHourResetsAt: .now,
                    sevenDayUtilization: 0, sevenDayResetsAt: .now,
                    sonnetUtilization: nil, sonnetResetsAt: nil,
                    isError: true, errorMessage: "HTTP \(code)"
                )
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[ClaudeWidget] ERROR: Could not parse JSON response")
                return UsageEntry(
                    date: .now,
                    fiveHourUtilization: 0, fiveHourResetsAt: .now,
                    sevenDayUtilization: 0, sevenDayResetsAt: .now,
                    sonnetUtilization: nil, sonnetResetsAt: nil,
                    isError: true, errorMessage: "Parse error"
                )
            }

            NSLog("[ClaudeWidget] SUCCESS: keys=%@", json.keys.joined(separator: ", "))
            return parseUsage(json)
        } catch {
            NSLog("[ClaudeWidget] NETWORK ERROR: %@", error.localizedDescription)
            return UsageEntry(
                date: .now,
                fiveHourUtilization: 0, fiveHourResetsAt: .now,
                sevenDayUtilization: 0, sevenDayResetsAt: .now,
                sonnetUtilization: nil, sonnetResetsAt: nil,
                isError: true, errorMessage: error.localizedDescription
            )
        }
    }

    // ── Bootstrap ──

    private func bootstrapOrgId(authHeader: String, authValue: String) async -> String? {
        guard let url = URL(string: "https://claude.ai/api/bootstrap") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(authValue, forHTTPHeaderField: authHeader)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authHeader == "Cookie" {
            req.setValue(Self.ua, forHTTPHeaderField: "User-Agent")
        } else {
            req.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        }
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              let id      = account["lastActiveOrgId"] as? String else { return nil }
        return id
    }

    // ── Credential loading ──

    private struct Credentials {
        var authHeader: String?   // "Authorization" or "Cookie"
        var authValue: String?    // "Bearer ..." or "sessionKey=..."
        var orgId: String?
    }

    private func loadCredentials() -> Credentials {
        var creds = Credentials()
        let shared = UserDefaults(suiteName: "YOUR_TEAM_ID.group.com.claude.usagewidget")

        // 1. OAuth token from host app (Claude Code) — highest priority
        if let token = shared?.string(forKey: "claude_oauth_token"), !token.isEmpty {
            creds.authHeader = "Authorization"
            creds.authValue  = "Bearer \(token)"
            creds.orgId      = shared?.string(forKey: "claude_org_id")
            return creds
        }

        // 2. Session key from shared UserDefaults (set by host app setup window)
        if let key = shared?.string(forKey: "claude_session_key"), !key.isEmpty {
            creds.authHeader = "Cookie"
            creds.authValue  = "sessionKey=\(key)"
            creds.orgId      = shared?.string(forKey: "claude_org_id")
            return creds
        }

        return creds
    }

    /// Extracts the raw key from either a full cookie string or a bare sk-ant-... value.
    private func extractSessionKey(from input: String) -> String {
        guard input.contains("sessionKey=") else { return input }
        for part in input.components(separatedBy: ";") {
            let t = part.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("sessionKey=") { return String(t.dropFirst("sessionKey=".count)) }
        }
        return input
    }

    // ── JSON parsing ──

    private func parseUsage(_ json: [String: Any]) -> UsageEntry {
        func window(_ key: String) -> (util: Double, resets: Date)? {
            guard let obj  = json[key] as? [String: Any],
                  let util = obj["utilization"] as? Double,
                  let str  = obj["resets_at"]   as? String else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = iso.date(from: str) ?? ISO8601DateFormatter().date(from: str) ?? Date()
            return (util, date)
        }

        let fh = window("five_hour") ?? (0, .now)
        let sd = window("seven_day") ?? (0, .now)
        let sn = window("seven_day_sonnet")

        return UsageEntry(
            date: .now,
            fiveHourUtilization: fh.util,
            fiveHourResetsAt: fh.resets,
            sevenDayUtilization: sd.util,
            sevenDayResetsAt: sd.resets,
            sonnetUtilization: sn?.util,
            sonnetResetsAt: sn?.resets,
            isError: false,
            errorMessage: nil
        )
    }

    private static let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Widget Views
// ═══════════════════════════════════════════════════════════════════════

// ── Invisible button style — strips all system highlight/glass treatments ──

struct InvisibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// ── Shared colors ──

extension Color {
    static let neonDark   = Color(red: 0.039, green: 0.035, blue: 0.027)  // #0A0907
    static let claudeOrng = Color(red: 0.788, green: 0.392, blue: 0.259)  // #C96442
    static let skyBlue    = Color(red: 0.220, green: 0.741, blue: 0.973)  // #38BDF8
    static let violet     = Color(red: 0.655, green: 0.545, blue: 0.980)  // #A78BFA
}

// ── Custom Neon Arc Gauge (Path-based, WidgetKit-safe) ──
// Matches exactly the Style4_NeonArc showcase design.

struct NeonArcGaugeView: View {
    let progress: Double     // 0–1
    let levelColor: Color
    let percent: Int
    let statusLabel: String

    // Arc geometry — same params as showcase
    private let lineWidth: CGFloat = 14
    private let startDeg:  Double  = 145
    private let sweepDeg:  Double  = 250
    private let size:      CGFloat = 225

    private var arcColors: [Color] {
        switch progress {
        case ..<0.50: return [Color(red: 0.133, green: 0.773, blue: 0.369),
                              Color(red: 0.639, green: 0.894, blue: 0.208)]
        case 0.50..<0.75: return [Color(red: 0.639, green: 0.894, blue: 0.208),
                                  Color(red: 0.961, green: 0.620, blue: 0.043)]
        case 0.75..<0.90: return [Color(red: 0.961, green: 0.620, blue: 0.043),
                                  Color(red: 0.976, green: 0.451, blue: 0.086)]
        default:          return [Color(red: 0.976, green: 0.451, blue: 0.086),
                                  Color(red: 0.937, green: 0.267, blue: 0.267)]
        }
    }

    var body: some View {
        ZStack {
            arcCanvas
            tickLabels
            centerContent
        }
    }

    // Draws the arc using GeometryReader + Path (no Canvas, simpler type inference)
    private var arcCanvas: some View {
        GeometryReader { geo in
            let cx  = geo.size.width  / 2
            let cy  = geo.size.height / 2
            let r   = (min(geo.size.width, geo.size.height) - lineWidth) / 2
            let end = startDeg + sweepDeg * progress
            let center = CGPoint(x: cx, y: cy)

            ZStack {
                // Track
                Path { p in
                    p.addArc(center: center, radius: r,
                             startAngle: .degrees(startDeg),
                             endAngle:   .degrees(startDeg + sweepDeg),
                             clockwise: false)
                }
                .stroke(Color.white.opacity(0.07),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Glow
                if progress > 0.005 {
                    Path { p in
                        p.addArc(center: center, radius: r,
                                 startAngle: .degrees(startDeg),
                                 endAngle:   .degrees(end),
                                 clockwise: false)
                    }
                    .stroke(levelColor.opacity(0.35),
                            style: StrokeStyle(lineWidth: lineWidth * 2, lineCap: .round))
                    .blur(radius: 6)
                }

                // Filled arc
                if progress > 0.005 {
                    Path { p in
                        p.addArc(center: center, radius: r,
                                 startAngle: .degrees(startDeg),
                                 endAngle:   .degrees(end),
                                 clockwise: false)
                    }
                    .stroke(
                        LinearGradient(colors: arcColors,
                                       startPoint: .leading,
                                       endPoint: .trailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }

                // Tick marks at 25 / 50 / 75
                ForEach([0.25, 0.50, 0.75], id: \.self) { frac in
                    let ang   = (startDeg + sweepDeg * frac) * .pi / 180
                    let inner = r - lineWidth * 0.8
                    let outer = r + lineWidth * 0.38
                    Path { p in
                        p.move(to:    CGPoint(x: cx + inner * cos(ang), y: cy + inner * sin(ang)))
                        p.addLine(to: CGPoint(x: cx + outer * cos(ang), y: cy + outer * sin(ang)))
                    }
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var tickLabels: some View {
        // labelR: just inside the inner edge of the arc stroke (inner edge = r - lineWidth/2)
        // 0.83 keeps labels ~5pt clear of the stroke without drifting into center
        let labelR = (size - lineWidth) / 2 * 0.83
        let cx     = size / 2
        let cy     = size / 2
        let ticks: [(Int, Double)] = [(0, 0), (25, 0.25), (50, 0.5), (75, 0.75), (100, 1)]
        return ZStack {
            ForEach(ticks, id: \.0) { tick, frac in
                let ang = (startDeg + sweepDeg * frac) * .pi / 180
                Text("\(tick)")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.22))
                    .position(x: cx + labelR * cos(ang), y: cy + labelR * sin(ang))
            }
        }
        .frame(width: size, height: size)
    }

    private var centerContent: some View {
        VStack(spacing: 3) {
            Text("\(percent)%")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .shadow(color: levelColor.opacity(0.5), radius: 10)

            Text(statusLabel)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(levelColor)
                .kerning(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(levelColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .offset(y: 12)
    }
}

// ── Small Widget ──

struct SmallWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.isError {
            errorView(entry.errorMessage)
        } else {
            VStack(spacing: 6) {
                // Mini arc + center content
                ZStack {
                    Canvas { ctx, sz in
                        let lw: CGFloat = 8
                        let cx = sz.width / 2; let cy = sz.height / 2
                        let r  = (min(sz.width, sz.height) - lw) / 2
                        var track = Path()
                        track.addArc(center: .init(x: cx, y: cy), radius: r,
                                     startAngle: .degrees(145), endAngle: .degrees(395), clockwise: false)
                        ctx.stroke(track, with: .color(.white.opacity(0.07)),
                                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
                        guard entry.fiveHourUtilization > 0 else { return }
                        var fill = Path()
                        fill.addArc(center: .init(x: cx, y: cy), radius: r,
                                    startAngle: .degrees(145),
                                    endAngle: .degrees(145 + 250 * entry.fiveHourUtilization / 100),
                                    clockwise: false)
                        ctx.stroke(fill, with: .color(entry.fiveHourLevel.color),
                                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    }
                    .frame(width: 90, height: 90)

                    VStack(spacing: 1) {
                        Text("\(Int(entry.fiveHourUtilization))%")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        Text(entry.fiveHourLevel.label)
                            .font(.system(size: 6, weight: .black, design: .rounded))
                            .foregroundColor(entry.fiveHourLevel.color)
                    }
                    .offset(y: 6)
                }

                Text(entry.timeRemaining(to: entry.fiveHourResetsAt))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(entry.fiveHourLevel.color)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// ── Medium Widget ──

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.isError {
            errorView(entry.errorMessage)
        } else {
            HStack(spacing: 12) {
                // Left: mini arc gauge
                ZStack {
                    Canvas { ctx, sz in
                        let lw: CGFloat = 9
                        let cx = sz.width / 2; let cy = sz.height / 2
                        let r  = (min(sz.width, sz.height) - lw) / 2
                        var track = Path()
                        track.addArc(center: .init(x: cx, y: cy), radius: r,
                                     startAngle: .degrees(145), endAngle: .degrees(395), clockwise: false)
                        ctx.stroke(track, with: .color(.white.opacity(0.07)),
                                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
                        guard entry.fiveHourUtilization > 0 else { return }
                        ctx.drawLayer { gc in
                            gc.addFilter(.blur(radius: 4))
                            var glow = Path()
                            glow.addArc(center: .init(x: cx, y: cy), radius: r,
                                        startAngle: .degrees(145),
                                        endAngle: .degrees(145 + 250 * entry.fiveHourUtilization / 100),
                                        clockwise: false)
                            gc.stroke(glow, with: .color(entry.fiveHourLevel.color.opacity(0.4)),
                                      style: StrokeStyle(lineWidth: lw * 1.8, lineCap: .round))
                        }
                        var fill = Path()
                        fill.addArc(center: .init(x: cx, y: cy), radius: r,
                                    startAngle: .degrees(145),
                                    endAngle: .degrees(145 + 250 * entry.fiveHourUtilization / 100),
                                    clockwise: false)
                        ctx.stroke(fill, with: .color(entry.fiveHourLevel.color),
                                   style: StrokeStyle(lineWidth: lw, lineCap: .round))
                    }
                    .frame(width: 100, height: 100)

                    VStack(spacing: 2) {
                        Text("\(Int(entry.fiveHourUtilization))%")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        Text(entry.fiveHourLevel.label)
                            .font(.system(size: 6.5, weight: .black, design: .rounded))
                            .foregroundColor(entry.fiveHourLevel.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(entry.fiveHourLevel.color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .offset(y: 7)
                }

                // Right: stats
                VStack(alignment: .leading, spacing: 0) {
                    Text("5-HOUR SESSION")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                        .kerning(0.8)
                    Text("Usage Rate")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.bottom, 12)

                    statRow(label: "RESETS IN", color: entry.fiveHourLevel.color) {
                        Text(entry.timeRemaining(to: entry.fiveHourResetsAt))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(entry.fiveHourLevel.color)
                    }

                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.6).padding(.vertical, 6)

                    statRow(label: "7D USAGE", color: .skyBlue) {
                        Text("\(Int(entry.sevenDayUtilization))%")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.skyBlue)
                    }

                    if let sonnet = entry.sonnetUtilization {
                        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 0.6).padding(.vertical, 6)
                        statRow(label: "SONNET 7D", color: .violet) {
                            Text("\(Int(sonnet))%")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.violet)
                        }
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text(entry.date, style: .relative)
                            .font(.system(size: 7.5, design: .rounded))
                            .foregroundColor(.white.opacity(0.22))
                        Spacer()
                    }
                }
            }
        }
    }

    private func statRow<V: View>(label: String, color: Color, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.28))
                .kerning(0.4)
            Spacer()
            value()
        }
    }
}

// ── Large Widget — Neon Arc Style4 exact layout ──

struct LargeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.isError {
            errorView(entry.errorMessage)
        } else {
            VStack(spacing: 0) {
                // ── Header ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("5-HOUR SESSION")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.28))
                            .kerning(1.0)
                        Text("Usage Rate")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                }

                Spacer(minLength: 0)

                // ── Neon arc gauge — sits closer to the stats row ──
                NeonArcGaugeView(
                    progress: entry.fiveHourUtilization / 100,
                    levelColor: entry.fiveHourLevel.color,
                    percent: Int(entry.fiveHourUtilization),
                    statusLabel: entry.fiveHourLevel.label
                )
                .padding(.bottom, 6)

                // ── Bottom stat row ──
                HStack(spacing: 0) {
                    statCell(
                        label: "RESETS IN",
                        color: entry.fiveHourLevel.color
                    ) {
                        Text(entry.timeRemaining(to: entry.fiveHourResetsAt))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(entry.fiveHourLevel.color)
                            .shadow(color: entry.fiveHourLevel.color.opacity(0.5), radius: 4)
                    }

                    statDivider()

                    statCell(
                        label: "7D USAGE",
                        color: .skyBlue
                    ) {
                        Text("\(Int(entry.sevenDayUtilization))%")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.skyBlue)
                            .shadow(color: Color.skyBlue.opacity(0.5), radius: 4)
                    }

                    if let sonnet = entry.sonnetUtilization {
                        statDivider()

                        statCell(
                            label: "SONNET 7D",
                            color: .violet
                        ) {
                            Text("\(Int(sonnet))%")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.violet)
                                .shadow(color: Color.violet.opacity(0.5), radius: 4)
                        }
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, 0)
            }
        }
    }

    private func statCell<V: View>(label: String, color: Color, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 7.5, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.28))
                .kerning(0.5)
            value()
        }
        .frame(maxWidth: .infinity)
    }

    private func statDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.8, height: 28)
    }
}

// ── Shared error view ──

private func errorView(_ message: String?) -> some View {
    VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 20))
            .foregroundColor(Color(red: 0.961, green: 0.620, blue: 0.043))

        Text(message ?? "Failed to load")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)

        Button(intent: RefreshUsageIntent()) {
            Label("Retry", systemImage: "arrow.clockwise")
                .font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundColor(.claudeOrng)
    }
}

// ── Adaptive entry view ──

struct UsageWidgetEntryView: View {
    var entry: UsageEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Button(intent: RefreshUsageIntent()) {
            Group {
                switch family {
                case .systemSmall:
                    SmallWidgetView(entry: entry)
                case .systemMedium:
                    MediumWidgetView(entry: entry)
                case .systemLarge, .systemExtraLarge:
                    LargeWidgetView(entry: entry)
                default:
                    MediumWidgetView(entry: entry)
                }
            }
        }
        .buttonStyle(InvisibleButtonStyle())
        .containerBackground(for: .widget) {
            ZStack {
                Color.neonDark
                RadialGradient(
                    colors: [entry.fiveHourLevel.color.opacity(0.15), Color.clear],
                    center: .center, startRadius: 0, endRadius: 200
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Widget Definition
// ═══════════════════════════════════════════════════════════════════════

@main
struct ClaudeUsageNativeWidget: Widget {
    let kind = "ClaudeUsageNativeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ClaudeWidgetConfiguration.self, provider: UsageProvider()) { entry in
            UsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Shows your Claude.ai usage — session limit, weekly limit, and reset countdown.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Usage Notifier (fires macOS notifications at thresholds)
// ═══════════════════════════════════════════════════════════════════════

struct UsageNotifier {
    // Cooldown: don't re-fire same threshold within 30 minutes
    private static let cooldown: TimeInterval = 30 * 60

    /// 5-hour thresholds — descending so highest match wins
    private static let fiveHourThresholds: [(level: Double, title: String, critical: Bool)] = [
        (95, "Almost Exhausted",  true),
        (90, "Near Limit",        false),
        (75, "High Usage",        false),
    ]

    static func checkAndNotify(entry: UsageEntry) {
        // Request permission on first run (no-op if already granted)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        // ── 5-hour notifications ──
        for t in fiveHourThresholds {
            if entry.fiveHourUtilization >= t.level {
                let key = "notif_5h_\(Int(t.level))"
                guard shouldFire(key: key) else { break }

                let resetStr = formatInterval(entry.fiveHourResetsAt.timeIntervalSinceNow)

                fire(
                    id: key,
                    title: "5H Session: \(t.title)",
                    body: "Usage at \(Int(entry.fiveHourUtilization))% — resets in \(resetStr)",
                    isCritical: t.critical
                )
                break  // Only fire the highest threshold
            }
        }

        // ── 7-day notification ──
        if entry.sevenDayUtilization >= 85 {
            let key = "notif_7d_85"
            if shouldFire(key: key) {
                fire(
                    id: key,
                    title: "Weekly Limit Warning",
                    body: "7-day usage at \(Int(entry.sevenDayUtilization))%",
                    isCritical: entry.sevenDayUtilization >= 95
                )
            }
        }
    }

    private static func shouldFire(key: String) -> Bool {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < cooldown {
            return false
        }
        defaults.set(Date(), forKey: key)
        return true
    }

    private static func fire(id: String, title: String, body: String, isCritical: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = isCritical ? .defaultCritical : .default

        if isCritical {
            content.interruptionLevel = .critical
        } else {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func formatInterval(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "now" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════════════════════

#Preview("Small", as: .systemSmall) {
    ClaudeUsageNativeWidget()
} timeline: {
    UsageEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    ClaudeUsageNativeWidget()
} timeline: {
    UsageEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    ClaudeUsageNativeWidget()
} timeline: {
    UsageEntry.placeholder
}
