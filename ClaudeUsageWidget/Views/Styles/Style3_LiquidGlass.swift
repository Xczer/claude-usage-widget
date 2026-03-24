// Style3_LiquidGlass.swift
// Apple visionOS / iOS 26 "Liquid Glass" aesthetic.
// True system blur backdrop + floating glass pills.
// Minimal information, maximum beauty.

import SwiftUI

struct Style3_LiquidGlass: View {
    let data: UsageData
    let onRefresh: () -> Void
    let isLoading: Bool
    let lastFetched: Date?

    @State private var appeared = false
    @State private var glowPhase: Double = 0
    private let glowTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    private var accent: Color { data.fiveHour.level.color }

    var body: some View {
        ZStack {
            // True OS blur — shows through to wallpaper / background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            // Tinted overlay
            LinearGradient(
                colors: [
                    accent.opacity(0.18),
                    Color(hex: "#7C3AED").opacity(0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Noise grain
            NoiseLayer().opacity(0.04)

            VStack(spacing: 12) {
                // ── Top pill — 5-hour status ──────────────────────────
                pillView(content: {
                    HStack(spacing: 12) {
                        // Ring + number
                        ZStack {
                            RingGauge(
                                progress: data.fiveHour.utilization / 100,
                                color: accent,
                                lineWidth: 5,
                                trackOpacity: 0.15
                            )
                            .frame(width: 44, height: 44)

                            Text(String(format: "%.0f", data.fiveHour.utilization))
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                StatusDot(level: data.fiveHour.level)
                                    .scaleEffect(0.75)
                                Text(data.fiveHour.level.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.88))
                            }

                            Text("5h session • resets in \(data.fiveHour.timeUntilReset)")
                                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.42))
                        }

                        Spacer()

                        RefreshButton(isLoading: isLoading, action: onRefresh)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                })

                // ── Middle pill — 7-day ──────────────────────────────
                pillView(content: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("WEEKLY LIMIT")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .kerning(0.8)
                            Spacer()
                            Text(data.sevenDay.utilizationText)
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#38BDF8"))
                        }

                        UsageBar(
                            progress: data.sevenDay.utilization / 100,
                            color: Color(hex: "#38BDF8"),
                            height: 6
                        )

                        Text("Resets in \(data.sevenDay.timeUntilReset)")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.32))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                })

                // ── Bottom pill — Sonnet (Pro) ────────────────────────
                if let s = data.sevenDaySonnet {
                    pillView(content: {
                        HStack(spacing: 10) {
                            ZStack {
                                RingGauge(
                                    progress: s.utilization / 100,
                                    color: Color(hex: "#A78BFA"),
                                    lineWidth: 4,
                                    trackOpacity: 0.15
                                )
                                .frame(width: 32, height: 32)

                                Text(String(format: "%.0f", s.utilization))
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("SONNET 7D")
                                    .font(.system(size: 8, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .kerning(0.6)
                                Text(s.utilizationText + " used")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#A78BFA"))
                            }

                            Spacer()

                            FetchedLabel(date: lastFetched)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                    })
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28 + 0.08 * sin(glowPhase)),
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: accent.opacity(0.20 + 0.10 * sin(glowPhase)), radius: 30)
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { appeared = true } }
        .onReceive(glowTimer) { _ in glowPhase += 0.03 }
    }

    @ViewBuilder
    private func pillView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                ZStack {
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    Color.white.opacity(0.06)
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
            )
    }
}

#Preview("Style 3 – Liquid Glass") {
    Style3_LiquidGlass(
        data: .placeholder,
        onRefresh: {},
        isLoading: false,
        lastFetched: Date()
    )
    .frame(width: 300, height: 240)
    .preferredColorScheme(.dark)
}
