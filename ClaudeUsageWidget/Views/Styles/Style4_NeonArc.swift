// Style4_NeonArc.swift
// Speedometer / gauge aesthetic — dark with vivid neon arc.
// Big arc gauge fills green→yellow→red based on usage %.
// Secondary stats float below. Pure drama.

import SwiftUI

struct Style4_NeonArc: View {
    let data: UsageData
    let onRefresh: () -> Void
    let isLoading: Bool
    let lastFetched: Date?

    @State private var appeared = false
    @State private var needlePhase: Double = 0
    private let needleTimer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    private var progress: Double { data.fiveHour.utilization / 100 }
    private var needleColor: Color {
        switch progress {
        case ..<0.5:  return Color(hex: "#22C55E")
        case 0.5..<0.75: return Color(hex: "#F59E0B")
        case 0.75..<0.9: return Color(hex: "#F97316")
        default:      return Color(hex: "#EF4444")
        }
    }

    var body: some View {
        ZStack {
            // Rich dark background
            Color(hex: "#0A0907")

            // Subtle radial glow matching current level
            RadialGradient(
                colors: [needleColor.opacity(0.12), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )

            NoiseLayer().opacity(0.03)

            VStack(spacing: 0) {
                // ── Header ─────────────────────────────────────────────
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("5-HOUR SESSION")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.28))
                            .kerning(1.0)
                        Text("Usage Rate")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        FetchedLabel(date: lastFetched)
                        RefreshButton(isLoading: isLoading, action: onRefresh)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 6)

                // ── Arc gauge ──────────────────────────────────────────
                ZStack {
                    // Arc
                    ArcGauge(
                        progress: progress,
                        lineWidth: 14,
                        startAngle: 145,
                        sweepAngle: 250
                    )
                    .frame(width: 180, height: 180)

                    // Scale marks — 0 / 25 / 50 / 75 / 100
                    ForEach(Array([0, 25, 50, 75, 100].enumerated()), id: \.offset) { i, tick in
                        let frac   = Double(tick) / 100.0
                        let deg    = 145.0 + 250.0 * frac
                        let rad    = deg * .pi / 180
                        let r      = 74.0
                        let x      = r * cos(rad)
                        let y      = r * sin(rad)

                        Text("\(tick)")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.22))
                            .offset(x: x, y: y)
                    }

                    // Center number stack
                    VStack(spacing: 3) {
                        Text(data.fiveHour.utilizationText)
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: needleColor.opacity(0.5 + 0.2 * sin(needlePhase)), radius: 12)
                            .contentTransition(.numericText())

                        Text(data.fiveHour.level.label)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(needleColor)
                            .kerning(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(needleColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .offset(y: 14)
                }
                .frame(height: 170)
                .scaleEffect(appeared ? 1 : 0.88)
                .opacity(appeared ? 1 : 0)

                // ── Bottom stats row ───────────────────────────────────
                HStack(spacing: 0) {
                    statCell(
                        label: "RESETS IN",
                        value: data.fiveHour.timeUntilReset,
                        color: needleColor
                    )

                    divider()

                    statCell(
                        label: "7D USAGE",
                        value: data.sevenDay.utilizationText,
                        color: Color(hex: "#38BDF8")
                    )

                    if let s = data.sevenDaySonnet {
                        divider()
                        statCell(
                            label: "SONNET 7D",
                            value: s.utilizationText,
                            color: Color(hex: "#A78BFA")
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            needleColor.opacity(0.35 + 0.12 * sin(needlePhase)),
                            Color.white.opacity(0.07),
                            needleColor.opacity(0.12)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: needleColor.opacity(0.25 + 0.10 * sin(needlePhase)), radius: 28)
        .shadow(color: .black.opacity(0.45), radius: 30, y: 14)
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true } }
        .onReceive(needleTimer) { _ in needlePhase += 0.035 }
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 7.5, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.28))
                .kerning(0.5)
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.8, height: 28)
    }
}

#Preview("Style 4 – Neon Arc") {
    Style4_NeonArc(
        data: .highUsage,
        onRefresh: {},
        isLoading: false,
        lastFetched: Date()
    )
    .frame(width: 320, height: 300)
    .preferredColorScheme(.dark)
}
