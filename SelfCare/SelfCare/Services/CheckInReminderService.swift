import Foundation
import Observation
import UserNotifications

enum CheckInOpeningPreference: String, Codable, CaseIterable, Identifiable {
    case manual
    case dailyReminder

    var id: Self { self }
}

extension Notification.Name {
    static let openSelfCareCheckIn = Notification.Name("openSelfCareCheckIn")
}

@MainActor
@Observable
final class CheckInReminderService: NSObject, UNUserNotificationCenterDelegate {
    nonisolated static let notificationIdentifier = "selfCare.dailyCheckInReminder"

    private static let preferenceKey = "selfCare.checkInOpeningPreference"
    private static let reminderSecondsKey = "selfCare.dailyReminderSeconds"

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    private(set) var openingPreference: CheckInOpeningPreference
    private(set) var reminderTime: Date
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
        openingPreference = CheckInOpeningPreference(
            rawValue: defaults.string(forKey: Self.preferenceKey) ?? ""
        ) ?? .manual

        let savedSeconds = defaults.object(forKey: Self.reminderSecondsKey) as? Int
        reminderTime = Self.date(secondsFromMidnight: savedSeconds ?? (8 * 3_600))
        super.init()
        center.delegate = self
    }

    var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized: "Notifications are allowed."
        case .provisional: "Notifications are delivered quietly."
        case .ephemeral: "Notifications are temporarily allowed."
        case .denied: "Reminders are disabled in iOS Settings."
        case .notDetermined: "Notification permission has not been requested."
        @unknown default: "Notification permission status is unavailable."
        }
    }

    var canOpenSystemSettings: Bool {
        authorizationStatus == .denied
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func selectPreference(_ preference: CheckInOpeningPreference) async {
        errorMessage = nil

        switch preference {
        case .manual:
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            openingPreference = .manual
            defaults.set(preference.rawValue, forKey: Self.preferenceKey)
            await refreshAuthorizationStatus()

        case .dailyReminder:
            openingPreference = .dailyReminder
            defaults.set(preference.rawValue, forKey: Self.preferenceKey)
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus

            if settings.authorizationStatus == .notDetermined {
                do {
                    _ = try await center.requestAuthorization(options: [.alert, .sound])
                    await refreshAuthorizationStatus()
                } catch {
                    errorMessage = "Self Care couldn’t request notification permission. \(error.localizedDescription)"
                    return
                }
            }

            guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
                errorMessage = "Daily reminders are off. Allow notifications in iOS Settings, then try again."
                return
            }

            do {
                try await scheduleDailyReminder()
            } catch {
                errorMessage = "Self Care couldn’t schedule the reminder. \(error.localizedDescription)"
            }
        }
    }

    func setReminderTime(_ date: Date) async {
        reminderTime = date
        let seconds = Self.secondsFromMidnight(date)
        defaults.set(seconds, forKey: Self.reminderSecondsKey)

        guard openingPreference == .dailyReminder else { return }
        do {
            try await scheduleDailyReminder()
            errorMessage = nil
        } catch {
            errorMessage = "Self Care couldn’t update the reminder. \(error.localizedDescription)"
        }
    }

    func reconcileSchedule() async {
        await refreshAuthorizationStatus()
        guard openingPreference == .dailyReminder else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
            return
        }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            errorMessage = "Daily reminders are disabled at the system level."
            return
        }
        do {
            try await scheduleDailyReminder()
        } catch {
            errorMessage = "Self Care couldn’t restore the daily reminder. \(error.localizedDescription)"
        }
    }

    func resetPreferences() async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        defaults.removeObject(forKey: Self.preferenceKey)
        defaults.removeObject(forKey: Self.reminderSecondsKey)
        openingPreference = .manual
        reminderTime = Self.date(secondsFromMidnight: 8 * 3_600)
        errorMessage = nil
        await refreshAuthorizationStatus()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == Self.notificationIdentifier else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .openSelfCareCheckIn, object: nil)
        }
    }

    nonisolated static func reminderDateComponents(for date: Date) -> DateComponents {
        Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
    }

    private func scheduleDailyReminder() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for your Self Care check-in"
        content.body = "Take a moment to see how you’re doing today."
        content.sound = .default
        content.userInfo = ["destination": "check-in"]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Self.reminderDateComponents(for: reminderTime),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    nonisolated private static func secondsFromMidnight(_ date: Date) -> Int {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 8) * 3_600 + (components.minute ?? 0) * 60
    }

    nonisolated private static func date(secondsFromMidnight seconds: Int) -> Date {
        let hour = max(0, min(23, seconds / 3_600))
        let minute = max(0, min(59, (seconds % 3_600) / 60))
        return Calendar.autoupdatingCurrent.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: .now
        ) ?? .now
    }
}
