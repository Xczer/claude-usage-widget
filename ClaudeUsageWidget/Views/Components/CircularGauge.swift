// CircularGauge.swift
// Reusable circular/arc gauge components used across multiple styles.

import SwiftUI

// MARK: - Full-ring gauge (donut style)

struct RingGauge: View {
    let progress: Double    // 0–1
    let color: Color
    var lineWidth: CGFloat = 8
    var trackOpacity: CGFloat = 0.10
    var animated: Bool = true

    @State private var drawn: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: animated ? drawn : progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.7), color]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: lineWidth * 0.6)
        }
        .onAppear {
            if animated {
                withAnimation(.spring(response: 1.1, dampingFraction: 0.75).delay(0.1)) {
                    drawn = progress
                }
            }
        }
        .onChange(of: progress) { p in
            if animated {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { drawn = p }
            }
        }
    }
}

// MARK: - Semicircular arc gauge (speedometer style)

struct ArcGauge: View {
    let progress: Double    // 0–1
    var lineWidth: CGFloat = 14
    var startAngle: Double = 150   // degrees
    var sweepAngle: Double = 240

    @State private var drawn: Double = 0

    private var arcStart: Angle { .degrees(startAngle) }
    private var arcEnd:   Angle { .degrees(startAngle + sweepAngle * (drawn)) }

    private func gradientColors(for p: Double) -> [Color] {
        switch p {
        case ..<0.5: return [Color(hex: "#22C55E"), Color(hex: "#A3E635")]
        case 0.5..<0.75: return [Color(hex: "#A3E635"), Color(hex: "#F59E0B")]
        case 0.75..<0.9: return [Color(hex: "#F59E0B"), Color(hex: "#F97316")]
        default:         return [Color(hex: "#F97316"), Color(hex: "#EF4444")]
        }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Track arc
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(startAngle),
                             endAngle: .degrees(startAngle + sweepAngle),
                             clockwise: false)
                }
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Filled arc (gradient)
                Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(startAngle),
                             endAngle: .degrees(startAngle + sweepAngle * drawn),
                             clockwise: false)
                }
                .stroke(
                    LinearGradient(
                        colors: gradientColors(for: progress),
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

                // Tick marks
                ForEach([0.25, 0.5, 0.75], id: \.self) { frac in
                    let angle = startAngle + sweepAngle * frac
                    let rad   = angle * .pi / 180
                    let inner = radius - lineWidth
                    let outer = radius + lineWidth * 0.3
                    Path { p in
                        p.move(to: CGPoint(
                            x: center.x + inner * cos(rad),
                            y: center.y + inner * sin(rad)
                        ))
                        p.addLine(to: CGPoint(
                            x: center.x + outer * cos(rad),
                            y: center.y + outer * sin(rad)
                        ))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.15)) {
                drawn = progress
            }
        }
        .onChange(of: progress) { p in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { drawn = p }
        }
    }
}

// MARK: - Horizontal progress bar

struct UsageBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6
    var animated: Bool = true

    @State private var width: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.10))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(LinearGradient(
                        colors: [color.opacity(0.8), color],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * (animated ? width : progress))
                    .shadow(color: color.opacity(0.5), radius: 3)
            }
        }
        .frame(height: height)
        .onAppear {
            if animated {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                    width = progress
                }
            }
        }
        .onChange(of: progress) { p in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { width = p }
        }
    }
}
