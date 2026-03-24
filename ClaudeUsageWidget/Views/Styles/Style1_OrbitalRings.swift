// Style1_OrbitalRings.swift
// Three concentric rings — 5h outer, 7d middle, Sonnet inner.
// Big percentage hero in the center. Reset countdown below.
// Dark background with dynamic accent glow.

import SwiftUI

struct Style1_OrbitalRings: View {
    let data: UsageData
    let onRefresh: () -> Void
    let isLoading: Bool
    let lastFetched: Date?

    @State private var appeared = false
    @State private var glowPhase: Double = 0
    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    private var primaryColor: Color { data.fiveHour.level.color }

    var body: some View {
        ZStack {
            WidgetBackground(accentColor: primaryColor)

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                HStack {
                    Text("CLAUDE USAGE")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .kerning(1.2)

                    Spacer()

                    FetchedLabel(date: lastFetched)
                    RefreshButton(isLoading: isLoading, action: onRefresh)
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                Spacer()

                // ── Orbital rings + center ───────────────────────────────
                ZStack {
                    // Outer ring — 5 hour (most important)
                    RingGauge(
                        progress: data.fiveHour.utilization / 100,
                        color: data.fiveHour.level.color,
                        lineWidth: 11,
                        trackOpacity: 0.08
                    )
                    .frame(width: 160, height: 160)

                    // Middle ring — 7 day
                    RingGauge(
                        progress: data.sevenDay.utilization / 100,
                        color: Color(hex: "#38BDF8"),
                        lineWidth: 8,
                        trackOpacity: 0.07
                    )
                    .frame(width: 122, height: 122)

                    // Inner ring — Sonnet (if Pro)
                    if let sonnet = data.sevenDaySonnet {
                        RingGauge(
                            progress: sonnet.utilization / 100,
                            color: Color(hex: "#A78BFA"),
                            lineWidth: 6,
                            trackOpacity: 0.08
                        )
                        .frame(width: 88, height: 88)
                    }

                    // Ambient glow behind center
                    Circle()
                        .fill(RadialGradient(
                            colors: [primaryColor.opacity(0.22 + 0.08 * sin(glowPhase)), .clear],
                            center: .center, startRadius: 0, endRadius: 40
                        ))
                        .frame(width: 80, height: 80)
                        .blur(radius: 12)

                    // Center content
                    VStack(spacing: 2) {
                        Text(data.fiveHour.utilizationText)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                            .contentTransition(.numericText())

                        Text("5H SESSION")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.38))
                            .kerning(0.8)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // ── Legend row ───────────────────────────────────────────
                HStack(spacing: 16) {
                    legendItem(color: data.fiveHour.level.color,  label: "5H", value: data.fiveHour.utilizationText)
                    legendItem(color: Color(hex: "#38BDF8"),       label: "7D", value: data.sevenDay.utilizationText)
                    if let s = data.sevenDaySonnet {
                        legendItem(color: Color(hex: "#A78BFA"),   label: "SONNET", value: s.utilizationText)
                    }
                }
                .padding(.horizontal, 18)

                // ── Reset countdown ──────────────────────────────────────
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.28))
                    Text("5h resets in \(data.fiveHour.timeUntilReset)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    Spacer()
                    Text(data.primaryStatus.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(primaryColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18 + 0.06 * sin(glowPhase)),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        )
        .shadow(color: primaryColor.opacity(0.18 + 0.08 * sin(glowPhase)), radius: 24)
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true } }
        .onReceive(glowTimer) { _ in glowPhase += 0.035 }
    }

    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .shadow(color: color.opacity(0.8), radius: 3)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.38))
                .kerning(0.5)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview("Style 1 – Orbital Rings") {
    Style1_OrbitalRings(
        data: .placeholder,
        onRefresh: {},
        isLoading: false,
        lastFetched: Date()
    )
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}
