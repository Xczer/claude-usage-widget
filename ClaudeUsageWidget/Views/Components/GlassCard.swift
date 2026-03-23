// GlassCard.swift
// Reusable glass-morphism card components — Claude orange palette.

import SwiftUI
import AppKit

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Claude Brand Colors

extension Color {
    static let claudeOrange  = Color(hex: "#C96442")
    static let claudeDark    = Color(hex: "#0F0D0B")
    static let claudeCard    = Color(hex: "#1A1714")
    static let claudeSurface = Color(hex: "#231E1B")
}

// MARK: - NSVisualEffectView wrapper (true OS-level blur)

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material     = material
        v.blendingMode = blendingMode
        v.state        = state
        v.wantsLayer   = true
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material     = material
        nsView.blendingMode = blendingMode
        nsView.state        = state
    }
}

// MARK: - Liquid Glass Card Modifier (Apple 2025 style)

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var tint: Color = .white
    var tintOpacity: CGFloat = 0.06
    var borderOpacity: CGFloat = 0.22
    var shadowRadius: CGFloat = 28
    var isElevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base coat — semi-opaque dark
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.claudeCard.opacity(0.80))

                    // Colour tint layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))

                    // Top specular shine (sells the glass)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.04), .clear],
                            startPoint: .top, endPoint: .center
                        ))

                    // Bottom edge dark
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.clear, Color.black.opacity(0.18)],
                            startPoint: .center, endPoint: .bottom
                        ))
                }
            )
            // Gradient border — top-leading is brightest
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [
                            Color.white.opacity(borderOpacity * 1.6),
                            Color.white.opacity(borderOpacity),
                            Color.white.opacity(borderOpacity * 0.3)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.9)
            )
            // Dual-shadow for lift
            .shadow(color: .black.opacity(isElevated ? 0.40 : 0.25),
                    radius: isElevated ? shadowRadius * 1.5 : shadowRadius,
                    x: 0, y: isElevated ? 14 : 8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 22,
        tint: Color = .white,
        tintOpacity: CGFloat = 0.06,
        borderOpacity: CGFloat = 0.22,
        shadowRadius: CGFloat = 28,
        isElevated: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            borderOpacity: borderOpacity,
            shadowRadius: shadowRadius,
            isElevated: isElevated
        ))
    }
}

// MARK: - Animated Gradient Background

struct WidgetBackground: View {
    var accentColor: Color = .claudeOrange

    @State private var p1: Double = 0
    @State private var p2: Double = 1.1

    private let t = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.claudeDark

            // Warm blob
            Ellipse()
                .fill(RadialGradient(
                    colors: [accentColor.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 160
                ))
                .frame(width: 300, height: 220)
                .offset(x: 70 * cos(p1), y: 40 * sin(p1 * 0.7))
                .blur(radius: 36)

            // Cool blob
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(hex: "#7C3AED").opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 130
                ))
                .frame(width: 230, height: 180)
                .offset(x: -55 * cos(p2), y: 55 * sin(p2 * 0.5))
                .blur(radius: 44)

            // Grain noise
            NoiseLayer().opacity(0.035)
        }
        .onReceive(t) { _ in p1 += 0.004; p2 += 0.0028 }
        .ignoresSafeArea()
    }
}

// MARK: - Film Grain

struct NoiseLayer: View {
    var body: some View {
        Canvas { ctx, size in
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<Int(size.width * size.height * 0.12) {
                let x = CGFloat.random(in: 0..<size.width,  using: &rng)
                let y = CGFloat.random(in: 0..<size.height, using: &rng)
                let g = Double.random(in: 0.4...1.0,        using: &rng)
                ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                         with: .color(.init(white: g, opacity: 0.55)))
            }
        }
        .drawingGroup()
    }
}

// MARK: - Refresh Button

struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    @State private var spin: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .rotationEffect(.degrees(isLoading ? spin : 0))
                .animation(isLoading
                    ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                    : .default,
                    value: isLoading)
        }
        .buttonStyle(.plain)
        .onChange(of: isLoading) { loading in
            if loading { withAnimation { spin = 360 } }
        }
    }
}

// MARK: - Last-fetched label

struct FetchedLabel: View {
    let date: Date?

    var body: some View {
        if let d = date {
            Text("Updated \(timeAgo(d))")
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.28))
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(-date.timeIntervalSinceNow)
        if s < 10  { return "just now" }
        if s < 60  { return "\(s)s ago" }
        if s < 3600 { return "\(s/60)m ago" }
        return "\(s/3600)h ago"
    }
}

// MARK: - Usage status dot

struct StatusDot: View {
    let level: UsageLevel
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(level.color.opacity(0.25))
                .frame(width: 16, height: 16)
                .scaleEffect(pulse)

            Circle()
                .fill(level.color)
                .frame(width: 7, height: 7)
                .shadow(color: level.glowColor, radius: 6)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = 2.2
            }
        }
    }
}
