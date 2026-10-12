import Foundation
import HealthKit
import Observation

enum HealthKitStatus: Equatable {
    case unavailable
    case notRequested
    case loading
    case ready
    case noData
    case failed(String)

    var title: String {
        switch self {
        case .unavailable: "Unavailable on this device"
        case .notRequested: "Access not requested"
        case .loading: "Syncing…"
        case .ready: "Health data updated"
        case .noData: "No readable data"
        case .failed: "Couldn’t update Health data"
        }
    }

    var symbol: String {
        switch self {
        case .unavailable: "heart.slash"
        case .notRequested: "heart"
        case .loading: "arrow.trianglehead.2.clockwise.rotate.90"
        case .ready: "heart.fill"
        case .noData: "heart.text.square"
        case .failed: "exclamationmark.triangle"
        }
    }
}

enum HealthKitError: LocalizedError {
    case stateOfMindWriteDenied

    var errorDescription: String? {
        switch self {
        case .stateOfMindWriteDenied:
            "State of Mind write access is off. You can change it in "
                + "Settings > Privacy & Security > Health > Self Care."
        }
    }
}

@MainActor
@Observable
final class HealthKitManager {
    private static let authorizationRequestedKey = "selfCare.healthKitAuthorizationRequested"
    private static let stateOfMindAuthorizationRequestedKey = "selfCare.stateOfMindAuthorizationRequested"
    private static let moodExportEnabledKey = "selfCare.moodExportEnabled"

    private let healthStore: HKHealthStore
    private let defaults: UserDefaults
    private let healthDataAvailability: @MainActor () -> Bool

    private(set) var status: HealthKitStatus
    private(set) var hasRequestedAuthorization: Bool
    private(set) var hasRequestedStateOfMindAuthorization: Bool
    private(set) var isMoodExportEnabled: Bool
    private(set) var exerciseMinutes: Double?
    private(set) var sleepHours: Double?
    private(set) var lastUpdated: Date?

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        defaults: UserDefaults = .standard,
        healthDataAvailability: @escaping @MainActor () -> Bool = { HKHealthStore.isHealthDataAvailable() }
    ) {
        self.healthStore = healthStore
        self.defaults = defaults
        self.healthDataAvailability = healthDataAvailability
        hasRequestedAuthorization = defaults.bool(forKey: Self.authorizationRequestedKey)
        hasRequestedStateOfMindAuthorization = defaults.bool(forKey: Self.stateOfMindAuthorizationRequestedKey)
        isMoodExportEnabled = defaults.bool(forKey: Self.moodExportEnabledKey)
        status = healthDataAvailability() ? .notRequested : .unavailable
    }

    var isLoading: Bool {
        status == .loading
    }

    var errorMessage: String? {
        guard case let .failed(message) = status else { return nil }
        return message
    }

    func requestAuthorizationAndRefresh() async {
        guard healthDataAvailability() else {
            status = .unavailable
            return
        }

        status = .loading

        do {
            try await healthStore.requestAuthorization(toShare: [], read: Self.readTypes)
            hasRequestedAuthorization = true
            defaults.set(true, forKey: Self.authorizationRequestedKey)
            await refresh()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func requestAuthorization(for dataType: SupportedHealthDataType) async {
        guard healthDataAvailability() else {
            status = .unavailable
            return
        }
        guard let type = Self.objectType(for: dataType) else {
            status = .failed("This Apple Health data type is not available on this device.")
            return
        }

        status = .loading
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [type])
            hasRequestedAuthorization = true
            defaults.set(true, forKey: Self.authorizationRequestedKey)
            await refresh(dataType)
        } catch {
            status = .failed(
                "Apple Health access wasn’t granted. The category is still available for manual check-in."
            )
        }
    }

    func refreshIfPreviouslyRequested() async {
        guard hasRequestedAuthorization else { return }
        await refresh()
    }

    func refresh() async {
        guard healthDataAvailability() else {
            status = .unavailable
            return
        }

        status = .loading

        do {
            async let exercise = queryExerciseMinutesToday()
            async let sleep = queryLastNightSleepHours()
            let values = try await (exercise, sleep)

            exerciseMinutes = values.0
            sleepHours = values.1
            lastUpdated = .now
            status = values.0 == nil && values.1 == nil ? .noData : .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func refresh(_ dataType: SupportedHealthDataType) async {
        guard healthDataAvailability() else {
            status = .unavailable
            return
        }

        status = .loading
        do {
            switch dataType {
            case .exerciseTime:
                exerciseMinutes = try await queryExerciseMinutesToday()
            case .sleepAnalysis:
                sleepHours = try await queryLastNightSleepHours()
            }
            lastUpdated = .now
            let hasData = dataType == .exerciseTime ? exerciseMinutes != nil : sleepHours != nil
            status = hasData ? .ready : .noData
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func setMoodExportEnabled(_ enabled: Bool) async {
        guard enabled else {
            isMoodExportEnabled = false
            defaults.set(false, forKey: Self.moodExportEnabledKey)
            return
        }

        guard healthDataAvailability(), #available(iOS 18.0, *) else {
            isMoodExportEnabled = false
            defaults.set(false, forKey: Self.moodExportEnabledKey)
            status = .unavailable
            return
        }

        isMoodExportEnabled = true
        defaults.set(true, forKey: Self.moodExportEnabledKey)

        let stateOfMindType = HKObjectType.stateOfMindType()
        do {
            if healthStore.authorizationStatus(for: stateOfMindType) == .notDetermined {
                try await healthStore.requestAuthorization(toShare: [stateOfMindType], read: [])
                hasRequestedStateOfMindAuthorization = true
                defaults.set(true, forKey: Self.stateOfMindAuthorizationRequestedKey)
            }

            guard healthStore.authorizationStatus(for: stateOfMindType) == .sharingAuthorized else {
                throw HealthKitError.stateOfMindWriteDenied
            }
        } catch {
            isMoodExportEnabled = false
            defaults.set(false, forKey: Self.moodExportEnabledKey)
            status = .failed(error.localizedDescription)
        }
    }

    func resetPreferences() {
        defaults.removeObject(forKey: Self.authorizationRequestedKey)
        defaults.removeObject(forKey: Self.stateOfMindAuthorizationRequestedKey)
        defaults.removeObject(forKey: Self.moodExportEnabledKey)
        hasRequestedAuthorization = false
        hasRequestedStateOfMindAuthorization = false
        isMoodExportEnabled = false
        exerciseMinutes = nil
        sleepHours = nil
        lastUpdated = nil
        status = healthDataAvailability() ? .notRequested : .unavailable
    }

    func saveCheckInMood(_ checkIn: CheckInRecord, syncVersion: Int64) async throws -> UUID? {
        guard isMoodExportEnabled else { return nil }
        guard healthDataAvailability() else { return nil }
        guard #available(iOS 18.0, *) else { return nil }

        let stateOfMindType = HKObjectType.stateOfMindType()

        guard healthStore.authorizationStatus(for: stateOfMindType) == .sharingAuthorized else {
            throw HealthKitError.stateOfMindWriteDenied
        }

        let sample = HKStateOfMind(
            date: checkIn.date,
            kind: .momentaryEmotion,
            valence: Self.stateOfMindValence(for: checkIn.moodValue),
            labels: [],
            associations: Self.stateOfMindAssociations(for: checkIn),
            metadata: [
                HKMetadataKeySyncIdentifier: Self.syncIdentifier(for: checkIn.id),
                HKMetadataKeySyncVersion: syncVersion
            ]
        )
        try await healthStore.save(sample)
        return sample.uuid
    }

    func deleteCheckInMood(for checkInID: UUID) async throws {
        guard healthDataAvailability(), #available(iOS 18.0, *) else { return }
        let type = HKObjectType.stateOfMindType()
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            operatorType: .equalTo,
            value: Self.syncIdentifier(for: checkInID)
        )
        _ = try await healthStore.deleteObjects(of: type, predicate: predicate)
    }

    nonisolated static func stateOfMindValence(for moodValue: Double) -> Double {
        min(1, max(-1, (moodValue / 50) - 1))
    }

    nonisolated static func syncIdentifier(for checkInID: UUID) -> String {
        "com.vansedita.SelfCare.checkin.\(checkInID.uuidString)"
    }

    @available(iOS 18.0, *)
    nonisolated static func stateOfMindAssociations(
        for checkIn: CheckInRecord
    ) -> [HKStateOfMind.Association] {
        var associations = Set<HKStateOfMind.Association>()

        if (checkIn.factorValues[.exercise] ?? 0) > 0 {
            associations.insert(.fitness)
        }
        if checkIn.metFactors.contains(.sleep) {
            associations.insert(.health)
        }
        for (categoryID, name) in checkIn.customCategoryNames ?? [:]
        where checkIn.completedCustomCategoryIDs?.contains(categoryID) == true {
            if let association = association(for: name) {
                associations.insert(association)
            }
        }

        return associations.sorted { $0.rawValue < $1.rawValue }
    }

    @available(iOS 18.0, *)
    nonisolated private static func association(for categoryName: String) -> HKStateOfMind.Association? {
        let normalized = categoryName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return switch normalized {
        case "work": .work
        case "family": .family
        case "friends": .friends
        case "partner": .partner
        case "dating": .dating
        case "education", "study", "studying": .education
        case "fitness", "exercise", "workout", "yoga": .fitness
        case "health": .health
        case "hobbies", "hobby": .hobbies
        case "money", "finances": .money
        case "self care", "self-care", "meditation", "journaling": .selfCare
        case "spirituality", "spiritual": .spirituality
        case "tasks", "chores", "errands": .tasks
        case "travel": .travel
        case "weather": .weather
        case "community": .community
        case "current events": .currentEvents
        case "identity": .identity
        default: nil
        }
    }

    private static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    private static func objectType(for dataType: SupportedHealthDataType) -> HKObjectType? {
        switch dataType {
        case .exerciseTime:
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .sleepAnalysis:
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        }
    }

    private func queryExerciseMinutesToday() async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) else {
            return nil
        }

        let window = Self.exerciseWindow(endingAt: .now)
        let predicate = HKQuery.predicateForSamples(
            withStart: window.start,
            end: window.end,
            options: .strictStartDate
        )
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: .minute())
    }

    private func queryLastNightSleepHours() async throws -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        guard let window = Self.sleepWindow(endingAt: .now) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: window.start,
            end: window.end,
            options: []
        )
        let descriptor = HKSampleQueryDescriptor<HKCategorySample>(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: healthStore)
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals = samples.compactMap { sample -> DateInterval? in
            guard asleepValues.contains(sample.value) else { return nil }
            let start = max(sample.startDate, window.start)
            let end = min(sample.endDate, window.end)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }

        let duration = Self.unionDuration(of: intervals)
        return duration > 0 ? duration / 3_600 : nil
    }

    nonisolated static func exerciseWindow(
        endingAt date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        DateInterval(start: calendar.startOfDay(for: date), end: date)
    }

    nonisolated static func sleepWindow(
        endingAt date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        let today = calendar.startOfDay(for: date)
        guard
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
            let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)
        else {
            return nil
        }
        let end = min(date, noon)
        guard end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    nonisolated static func unionDuration(of intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }
        guard var current = sorted.first else { return 0 }

        var total: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }
}
