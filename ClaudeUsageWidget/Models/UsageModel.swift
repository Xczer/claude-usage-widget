// UsageModel.swift
// Data models for Claude usage API response

import SwiftUI

// MARK: - Usage Window

struct UsageWindow {
    let utilization: Double  // 0–100
    let resetsAt: Date

    var timeUntilReset: String {
        let interval = resetsAt.timeIntervalSinceNow
        guard interval > 0 else { return "Resetting…" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let days = hours / 24
        if days > 0  { return "\(days)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var utilizationText: String { String(format: "%.0f%%", utilization) }

    var level: UsageLevel {
        switch utilization {
        case ..<50: return .healthy
        case 50..<75: return .moderate
        case 75..<90: return .high
        default:      return .critical
        }
    }
}

// MARK: - Usage Level

enum UsageLevel: Equatable {
    case healthy, moderate, high, critical

    var color: Color {
        switch self {
        case .healthy:  return Color(hex: "#22C55E")
        case .moderate: return Color(hex: "#F59E0B")
        case .high:     return Color(hex: "#F97316")
        case .critical: return Color(hex: "#EF4444")
        }
    }

    var glowColor: Color { color.opacity(0.45) }

    var label: String {
        switch self {
        case .healthy:  return "HEALTHY"
        case .moderate: return "MODERATE"
        case .high:     return "HIGH USAGE"
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

// MARK: - Usage Data

struct UsageData {
    let fiveHour: UsageWindow
    let sevenDay: UsageWindow
    let sevenDaySonnet: UsageWindow?
    let fetchedAt: Date

    var isPro: Bool { sevenDaySonnet != nil }

    var primaryStatus: UsageLevel { fiveHour.level }

    // MARK: Preview / placeholder

    static let placeholder = UsageData(
        fiveHour: UsageWindow(
            utilization: 43.0,
            resetsAt: Date().addingTimeInterval(2 * 3600 + 18 * 60)
        ),
        sevenDay: UsageWindow(
            utilization: 28.5,
            resetsAt: Date().addingTimeInterval(3 * 24 * 3600 + 6 * 3600)
        ),
        sevenDaySonnet: UsageWindow(
            utilization: 14.2,
            resetsAt: Date().addingTimeInterval(3 * 24 * 3600 + 6 * 3600)
        ),
        fetchedAt: Date()
    )

    static let highUsage = UsageData(
        fiveHour: UsageWindow(
            utilization: 87.0,
            resetsAt: Date().addingTimeInterval(45 * 60)
        ),
        sevenDay: UsageWindow(
            utilization: 72.3,
            resetsAt: Date().addingTimeInterval(2 * 24 * 3600)
        ),
        sevenDaySonnet: UsageWindow(
            utilization: 55.8,
            resetsAt: Date().addingTimeInterval(2 * 24 * 3600)
        ),
        fetchedAt: Date()
    )
}
