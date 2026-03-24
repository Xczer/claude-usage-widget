// Style2_CommandCenter.swift
// Finance/data-dashboard aesthetic.
// Hero number (5h %) left, status arc right.
// Three metric pills in the middle row.
// Weekly reset context at the bottom.

import SwiftUI

struct Style2_CommandCenter: View {
    let data: UsageData
    let onRefresh: () -> Void
    let isLoading: Bool
    let lastFetched: Date?

    @State private var appeared = false

    var body: some View {
        ZStack {
            WidgetBackground(accentColor: data.fiveHour.level.color)

            VStack(alignment: .leading, spacing: 0) {

                // ── Top bar ───────────────────────────────────────────
                HStack(alignment: .center) {
                    // Status badge
                    HStack(spacing: 5) {
                        Image(systemName: data.primaryStatus.icon)
                            .font(.system(size: 9))
                            .foregroundColor(data.fiveHour.level.color)
                        Text(data.primaryStatus.label)
                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                            .foregroundColor(data.fiveHour.level.color)
                            .kerning(0.6)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(data.fiveHour.level.color.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(data.fiveHour.level.color.opacity(0.4), lineWidth: 0.8))

                    Spacer()
                    FetchedLabel(date: lastFetched)
                    RefreshButton(isLoading: isLoading, action: onRefresh)
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // ── Hero row — big number + arc ───────────────────────
                HStack(alignment: .center, spacing: 0) {
                    // Left: big 5h number
                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.fiveHour.utilizationText)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)

                        Text("5-HOUR SESSION")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.30))
                            .kerning(0.8)

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 7.5))
                                .foregroundColor(.white.opacity(0.3))
                            Text("resets in \(data.fiveHour.timeUntilReset)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 2)
                    }
                    .padding(.leading, 16)

                    Spacer()

                    // Right: arc gauge
                    ZStack {
                        ArcGauge(
                            progress: data.fiveHour.utilization / 100,
                            lineWidth: 10,
                            startAngle: 140,
                            sweepAngle: 260
                        )
                        .frame(width: 90, height: 90)

                        VStack(spacing: 1) {
                            Text(String(format: "%.0f", data.fiveHour.utilization))
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            Text("%")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                // ── Metric pills row ────────────────────────────────────
                HStack(spacing: 8) {
                    metricPill(
                        label: "5H LIMIT",
                        value: data.fiveHour.utilizationText,
                        sub: "resets \(data.fiveHour.timeUntilReset)",
                        color: data.fiveHour.level.color,
                        progress: data.fiveHour.utilization / 100
                    )

                    metricPill(
                        label: "7D LIMIT",
                        value: data.sevenDay.utilizationText,
                        sub: "resets \(data.sevenDay.timeUntilReset)",
                        color: Color(hex: "#38BDF8"),
                        progress: data.sevenDay.utilization / 100
                    )

                    if let s = data.sevenDaySonnet {
                        metricPill(
                            label: "SONNET",
                            value: s.utilizationText,
                            sub: "7d usage",
                            color: Color(hex: "#A78BFA"),
                            progress: s.utilization / 100
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }

    private func metricPill(label: String, value: String, sub: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 7.5, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.32))
                .kerning(0.5)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.9))

            UsageBar(progress: progress, color: color, height: 4)

            Text(sub)
                .font(.system(size: 7.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.7)
        )
    }
}

#Preview("Style 2 – Command Center") {
    Style2_CommandCenter(
        data: .placeholder,
        onRefresh: {},
        isLoading: false,
        lastFetched: Date()
    )
    .frame(width: 360, height: 280)
    .preferredColorScheme(.dark)
}
