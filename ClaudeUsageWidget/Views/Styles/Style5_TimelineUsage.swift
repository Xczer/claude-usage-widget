// Style5_TimelineUsage.swift
// Evolution of the Claude2x widget — adds real usage rings.
// Top: 2x window status timeline bar (from Claude2xWidget).
// Middle: 5h + 7d usage rings side by side.
// Bottom: calendar week dots.
// The "power user combo" — one widget, total picture.

import SwiftUI

struct Style5_TimelineUsage: View {
    let data: UsageData
    let onRefresh: () -> Void
    let isLoading: Bool
    let lastFetched: Date?

    // 2x window data (computed locally — same logic as Claude2xWidget)
    @State private var currentTime: Date = Date()
    @State private var appeared = false
    @State private var glowPhase: Double = 0
    @State private var barAppeared = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    // ── 2x ET window logic ──────────────────────────────────────────
    private let etTZ = TimeZone(identifier: "America/New_York")!
    private var etBlockStartMin: Int { 8 * 60 }   // 8 AM ET
    private var etBlockEndMin:   Int { 14 * 60 }  // 2 PM ET

    private var localBlockStart: Int {
        let diff = (TimeZone.current.secondsFromGMT(for: currentTime) - etTZ.secondsFromGMT(for: currentTime)) / 60
        return (etBlockStartMin + diff + 1440) % 1440
    }
    private var localBlockEnd: Int {
        let diff = (TimeZone.current.secondsFromGMT(for: currentTime) - etTZ.secondsFromGMT(for: currentTime)) / 60
        return (etBlockEndMin + diff + 1440) % 1440
    }

    private var isWeekend: Bool {
        let wd = Calendar.current.component(.weekday, from: currentTime)
        return wd == 1 || wd == 7
    }

    private var is2xBlocked: Bool {
        guard !isWeekend else { return false }
        let now = Calendar.current.component(.hour, from: currentTime) * 60 +
                  Calendar.current.component(.minute, from: currentTime)
        if localBlockStart < localBlockEnd {
            return now >= localBlockStart && now < localBlockEnd
        } else {
            return now >= localBlockStart || now < localBlockEnd
        }
    }

    private var twoxStatus: String {
        if isWeekend { return "WEEKEND" }
        return is2xBlocked ? "STANDARD" : "2× ACTIVE"
    }

    private var twoxColor: Color {
        if isWeekend { return Color(hex: "#6B7280") }
        return is2xBlocked ? Color(hex: "#F87171") : Color(hex: "#4ADE80")
    }

    private var nowFrac: CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: currentTime)
        let m = cal.component(.minute, from: currentTime)
        let s = cal.component(.second, from: currentTime)
        return CGFloat(h * 60 + m + (s > 30 ? 1 : 0)) / 1440.0
    }

    private var seg1: CGFloat { CGFloat(localBlockStart) / 1440 }
    private var seg2: CGFloat { CGFloat(localBlockEnd - localBlockStart) / 1440 }
    private var seg3: CGFloat { 1 - seg1 - seg2 }

    private func fmt(_ m: Int) -> String {
        let h = m / 60, mn = m % 60
        let sfx = h >= 12 ? "PM" : "AM"
        let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return mn == 0 ? "\(h12)\(sfx)" : "\(h12):\(String(format: "%02d", mn))\(sfx)"
    }

    var body: some View {
        ZStack {
            WidgetBackground(accentColor: twoxColor)

            VStack(alignment: .leading, spacing: 10) {

                // ── Row 1: 2x status + refresh ─────────────────────────
                HStack(spacing: 7) {
                    StatusDot(level: is2xBlocked ? .high : (isWeekend ? .moderate : .healthy))

                    Text(twoxStatus)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))

                    Spacer()

                    // Usage summary — 5h pill
                    HStack(spacing: 4) {
                        Text("5H:")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                        Text(data.fiveHour.utilizationText)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(data.fiveHour.level.color)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(data.fiveHour.level.color.opacity(0.12))
                    .clipShape(Capsule())

                    RefreshButton(isLoading: isLoading, action: onRefresh)
                }

                // ── Row 2: timeline bar ───────────────────────────────
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let pinX = nowFrac * w

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
                                )

                            if !isWeekend {
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: barAppeared ? w * seg1 - 1 : 0)
                                        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1), value: barAppeared)

                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color(hex: "#DC2626").opacity(0.5), Color(hex: "#991B1B").opacity(0.28)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: barAppeared ? w * seg2 - 2 : 0)
                                        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.18), value: barAppeared)

                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color(hex: "#22C55E").opacity(0.85), Color(hex: "#16A34A").opacity(0.55)],
                                            startPoint: .top, endPoint: .bottom
                                        ))
                                        .frame(width: barAppeared ? w * seg3 - 1 : 0)
                                        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.26), value: barAppeared)
                                }

                                Rectangle()
                                    .fill(Color.black.opacity(0.28))
                                    .frame(width: max(0, pinX))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .allowsHitTesting(false)

                                Rectangle()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: 1.5, height: h)
                                    .shadow(color: Color.white.opacity(0.5 + 0.2 * sin(glowPhase)), radius: 3)
                                    .offset(x: pinX - 0.75)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "moon.zzz.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("NO 2× ON WEEKENDS")
                                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.2))
                                        .kerning(0.8)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(height: 30)

                    HStack {
                        Text("12A")
                            .font(.system(size: 7, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                        Spacer()
                        Text(fmt(localBlockStart))
                            .font(.system(size: 7, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                        Spacer()
                        Text(fmt(localBlockEnd))
                            .font(.system(size: 7, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                        Spacer()
                        Text("12A")
                            .font(.system(size: 7, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .opacity(isWeekend ? 0 : 1)
                }

                // ── Row 3: usage rings row ────────────────────────────
                HStack(spacing: 12) {
                    // 5h ring
                    usageRingCell(
                        label: "5H SESSION",
                        utilization: data.fiveHour.utilization,
                        color: data.fiveHour.level.color,
                        sub: "↺ " + data.fiveHour.timeUntilReset
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 0.5)

                    // 7d ring
                    usageRingCell(
                        label: "7D LIMIT",
                        utilization: data.sevenDay.utilization,
                        color: Color(hex: "#38BDF8"),
                        sub: "↺ " + data.sevenDay.timeUntilReset
                    )

                    if let s = data.sevenDaySonnet {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 0.5)

                        usageRingCell(
                            label: "SONNET",
                            utilization: s.utilization,
                            color: Color(hex: "#A78BFA"),
                            sub: "Pro plan"
                        )
                    }
                }
                .padding(.vertical, 4)

                // ── Row 4: week calendar ──────────────────────────────
                weekRow()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            withAnimation(.easeIn.delay(0.1)) { barAppeared = true }
        }
        .onReceive(ticker)    { _ in currentTime = Date() }
        .onReceive(glowTimer) { _ in glowPhase += 0.04 }
    }

    // ── Usage ring cell ────────────────────────────────────────────

    private func usageRingCell(label: String, utilization: Double, color: Color, sub: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RingGauge(progress: utilization / 100, color: color, lineWidth: 5, trackOpacity: 0.12)
                    .frame(width: 36, height: 36)
                Text(String(format: "%.0f", utilization))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 7.5, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.32))
                    .kerning(0.4)
                Text(String(format: "%.0f%%", utilization))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(sub)
                    .font(.system(size: 7.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.28))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── Week dots ──────────────────────────────────────────────────

    private func weekRow() -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days: [(date: Date, isWeekend: Bool, isToday: Bool)] = (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            let wd = cal.component(.weekday, from: d)
            return (d, wd == 1 || wd == 7, offset == 0)
        }

        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 3) {
                    Text(dayNum(day.date))
                        .font(.system(size: 8.5, weight: day.isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(
                            day.isToday   ? Color(hex: "#C96442") :
                            day.isWeekend ? .white.opacity(0.2)   : .white.opacity(0.42)
                        )
                    Circle()
                        .fill(
                            day.isWeekend ? Color(hex: "#374151") :
                            day.isToday   ? Color(hex: "#C96442") : Color(hex: "#22C55E").opacity(0.75)
                        )
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: day.isToday ? Color(hex: "#C96442").opacity(0.7) : .clear, radius: 3)
                    Text(dayName(day.date))
                        .font(.system(size: 6.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(day.isWeekend ? 0.15 : 0.28))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayNum(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: d)
    }
    private func dayName(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d).uppercased()
    }
}

#Preview("Style 5 – Timeline + Usage") {
    Style5_TimelineUsage(
        data: .placeholder,
        onRefresh: {},
        isLoading: false,
        lastFetched: Date()
    )
    .frame(width: 360, height: 290)
    .preferredColorScheme(.dark)
}
