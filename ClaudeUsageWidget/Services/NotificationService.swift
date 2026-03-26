// NotificationService.swift
// Sends macOS notifications when Claude usage hits critical thresholds.
//
// Thresholds:
//   • 75% — "High usage" warning
//   • 90% — "Near limit" critical alert
//   • 95% — "Almost exhausted" urgent alert
//
// Cooldown: won't re-fire the same level within 30 minutes
// to avoid notification spam.

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    // Cooldown: don't re-fire same threshold within this interval
    private let cooldown: TimeInterval = 30 * 60  // 30 minutes

    private init() {}

    // MARK: - Request permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("[Notifications] Permission granted")
            } else if let error = error {
                print("[Notifications] Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Check and fire

    /// Call this after every successful API fetch.
    /// Compares utilization against thresholds and fires if needed.
    func checkAndNotify(
        fiveHourUtilization: Double,
        fiveHourResetsIn: String,
        sevenDayUtilization: Double
    ) {
        // 5-hour thresholds (most urgent)
        checkThreshold(
            utilization: fiveHourUtilization,
            windowName: "5-hour session",
            resetsIn: fiveHourResetsIn,
            thresholds: [
                (95, "Almost Exhausted", "Your 5h session is at \(Int(fiveHourUtilization))%. Resets in \(fiveHourResetsIn).", .critical),
                (90, "Near Limit",       "Your 5h session hit \(Int(fiveHourUtilization))%. Slow down or wait \(fiveHourResetsIn).", .high),
                (75, "High Usage",        "5h session at \(Int(fiveHourUtilization))%. You have \(fiveHourResetsIn) until reset.", .moderate),
            ]
        )

        // 7-day threshold (less urgent)
        if sevenDayUtilization >= 80 {
            checkThreshold(
                utilization: sevenDayUtilization,
                windowName: "7-day limit",
                resetsIn: "",
                thresholds: [
                    (90, "Weekly Limit Critical", "Your 7-day usage is at \(Int(sevenDayUtilization))%.", .high),
                    (80, "Weekly Limit Warning",  "7-day usage reached \(Int(sevenDayUtilization))%.", .moderate),
                ]
            )
        }
    }

    // MARK: - Internal

    private enum Severity { case moderate, high, critical }

    private func checkThreshold(
        utilization: Double,
        windowName: String,
        resetsIn: String,
        thresholds: [(level: Int, title: String, body: String, severity: Severity)]
    ) {
        // Find the highest threshold crossed
        guard let match = thresholds.first(where: { utilization >= Double($0.level) }) else { return }

        let key = "notif_\(windowName)_\(match.level)"
        let defaults = UserDefaults.standard

        // Check cooldown
        if let lastFired = defaults.object(forKey: key) as? Date,
           Date().timeIntervalSince(lastFired) < cooldown {
            return  // Still in cooldown
        }

        // Fire notification
        fireNotification(
            id: key,
            title: match.title,
            body: match.body,
            severity: match.severity
        )

        // Record timestamp
        defaults.set(Date(), forKey: key)
    }

    private func fireNotification(id: String, title: String, body: String, severity: Severity) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.categoryIdentifier = "USAGE_ALERT"

        switch severity {
        case .critical:
            content.sound = .defaultCritical
            content.interruptionLevel = .critical
        case .high:
            content.sound = .default
            content.interruptionLevel = .timeSensitive
        case .moderate:
            content.sound = .default
            content.interruptionLevel = .active
        }

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil  // Fire immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Failed: \(error.localizedDescription)")
            }
        }
    }
}
