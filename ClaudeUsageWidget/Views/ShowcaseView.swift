// ShowcaseView.swift
// Scrollable side-by-side showcase of all 5 widget styles.
// Shows both normal and high-usage preview data so you see
// how each style responds under pressure.
// Pick your favourite — then we'll build just that one.

import SwiftUI

struct ShowcaseView: View {
    @StateObject private var api = APIService()
    @State private var selectedStyle: Int? = nil
    @State private var useRealData = false

    private var displayData: UsageData {
        useRealData ? (api.usageData ?? .placeholder) : .placeholder
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0908").ignoresSafeArea()

            // Very subtle warm gradient
            LinearGradient(
                colors: [Color(hex: "#C96442").opacity(0.07), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top bar ──────────────────────────────────────────────
                topBar()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 40) {

                        styleBlock(
                            number: 1,
                            name: "Orbital Rings",
                            hint: "3 concentric donut rings · 5h outer · 7d middle · Sonnet inner",
                            width: 300, height: 310
                        ) {
                            Style1_OrbitalRings(
                                data: displayData,
                                onRefresh: api.refresh,
                                isLoading: api.isLoading,
                                lastFetched: api.lastFetched
                            )
                        }

                        styleBlock(
                            number: 2,
                            name: "Command Center",
                            hint: "Finance dashboard · hero number + arc · metric pill row",
                            width: 360, height: 270
                        ) {
                            Style2_CommandCenter(
                                data: displayData,
                                onRefresh: api.refresh,
                                isLoading: api.isLoading,
                                lastFetched: api.lastFetched
                            )
                        }

                        styleBlock(
                            number: 3,
                            name: "Liquid Glass",
                            hint: "Apple visionOS aesthetic · true system blur · floating pills",
                            width: 300, height: 240
                        ) {
                            Style3_LiquidGlass(
                                data: displayData,
                                onRefresh: api.refresh,
                                isLoading: api.isLoading,
                                lastFetched: api.lastFetched
                            )
                        }

                        styleBlock(
                            number: 4,
                            name: "Neon Arc",
                            hint: "Speedometer gauge · green→red arc · neon glow",
                            width: 320, height: 290
                        ) {
                            Style4_NeonArc(
                                data: displayData,
                                onRefresh: api.refresh,
                                isLoading: api.isLoading,
                                lastFetched: api.lastFetched
                            )
                        }

                        styleBlock(
                            number: 5,
                            name: "Timeline + Usage",
                            hint: "Evolution of Claude2x widget · adds live usage rings",
                            width: 360, height: 290
                        ) {
                            Style5_TimelineUsage(
                                data: displayData,
                                onRefresh: api.refresh,
                                isLoading: api.isLoading,
                                lastFetched: api.lastFetched
                            )
                        }

                        // ── High-usage variants ───────────────────────────
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.horizontal, 40)

                        VStack(spacing: 6) {
                            Text("HIGH USAGE VARIANTS")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.25))
                                .kerning(1.5)
                            Text("Same styles at 87% session usage — how they look under pressure")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.30))
                        }
                        .padding(.top, 10)

                        styleBlock(number: 1, name: "Orbital Rings (High)", hint: "87% session usage", width: 300, height: 310) {
                            Style1_OrbitalRings(data: .highUsage, onRefresh: {}, isLoading: false, lastFetched: Date())
                        }
                        styleBlock(number: 4, name: "Neon Arc (High)", hint: "Red critical state", width: 320, height: 290) {
                            Style4_NeonArc(data: .highUsage, onRefresh: {}, isLoading: false, lastFetched: Date())
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 24)
                }
            }
        }
        .onAppear { api.refresh() }
    }

    // MARK: - Top bar

    @ViewBuilder
    private func topBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CLAUDE USAGE WIDGET")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.28))
                    .kerning(1.4)
                Text("Pick a style")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()

            // Data source toggle
            VStack(spacing: 3) {
                Toggle("Live API data", isOn: $useRealData)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(Color(hex: "#C96442"))
                Text(useRealData
                     ? (api.usageData != nil ? "Live ✓" : "Fetching…")
                     : "Preview data")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(Color(hex: "#0A0908").opacity(0.95))
        .overlay(Divider().background(Color.white.opacity(0.06)), alignment: .bottom)
    }

    // MARK: - Style block

    @ViewBuilder
    private func styleBlock<V: View>(
        number: Int,
        name: String,
        hint: String,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> V
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "#C96442"))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: "#C96442").opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Text(hint)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Button("Select") {
                    selectedStyle = number
                }
                .buttonStyle(SelectButtonStyle())
            }

            content()
                .frame(width: width, height: height)
        }
    }
}

// MARK: - Select button

struct SelectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "#C96442"))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(hex: "#C96442").opacity(configuration.isPressed ? 0.25 : 0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "#C96442").opacity(0.4), lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    ShowcaseView()
        .frame(width: 600, height: 800)
        .preferredColorScheme(.dark)
}
