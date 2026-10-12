import Foundation
import Observation

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum InputMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: Self { self }
}

enum GoalDirection: String, Codable {
    case atLeast
    case atMost
}

enum CategorySource: String, Codable, CaseIterable, Identifiable {
    case manual
    case appleHealth

    var id: Self { self }
}

enum SupportedHealthDataType: String, Codable, CaseIterable, Identifiable {
    case exerciseTime
    case sleepAnalysis

    var id: Self { self }

    var title: String {
        switch self {
        case .exerciseTime: "Exercise Time"
        case .sleepAnalysis: "Sleep Analysis"
        }
    }

    var healthKitIdentifier: String {
        switch self {
        case .exerciseTime: "HKQuantityTypeIdentifierAppleExerciseTime"
        case .sleepAnalysis: "HKCategoryTypeIdentifierSleepAnalysis"
        }
    }

    var symbol: String {
        switch self {
        case .exerciseTime: "figure.run"
        case .sleepAnalysis: "moon.stars.fill"
        }
    }
}

struct SelfCareCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var source: CategorySource
    var healthDataTypeIdentifier: String?
    var isUserCreated: Bool

    var linkedHealthDataType: SupportedHealthDataType? {
        guard let healthDataTypeIdentifier else { return nil }
        return SupportedHealthDataType.allCases.first {
            $0.healthKitIdentifier == healthDataTypeIdentifier
        }
    }
}

enum SelfCareModelError: LocalizedError, Equatable {
    case emptyCategoryName
    case duplicateCategoryName
    case categoryNotFound
    case checkInNotFound
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .emptyCategoryName:
            "Enter a category name."
        case .duplicateCategoryName:
            "A category with this name already exists."
        case .categoryNotFound:
            "This category is no longer available."
        case .checkInNotFound:
            "This check-in is no longer available."
        case .persistenceFailed:
            "Self Care couldn’t save this change. Please try again."
        }
    }
}

enum FactorKey: String, Codable, CaseIterable, Identifiable, Hashable {
    case exercise
    case sleep
    case scrolling

    var id: Self { self }

    var label: String {
        switch self {
        case .exercise: "Exercise"
        case .sleep: "Sleep"
        case .scrolling: "Scrolling"
        }
    }

    var chipLabel: String {
        switch self {
        case .exercise: "Exercised"
        case .sleep: "Slept well"
        case .scrolling: "No scrolling"
        }
    }

    var prompt: String {
        switch self {
        case .exercise: "Minutes of exercise today"
        case .sleep: "Hours of sleep last night"
        case .scrolling: "Minutes on social apps today"
        }
    }

    var symbol: String {
        switch self {
        case .exercise: "figure.run"
        case .sleep: "moon.stars.fill"
        case .scrolling: "iphone.slash"
        }
    }

    var unit: String {
        switch self {
        case .exercise, .scrolling: "min"
        case .sleep: "hrs"
        }
    }

    var threshold: Double {
        switch self {
        case .exercise: 20
        case .sleep: 7
        case .scrolling: 30
        }
    }

    var direction: GoalDirection {
        switch self {
        case .exercise, .sleep: .atLeast
        case .scrolling: .atMost
        }
    }

    var supportsHealthKit: Bool {
        self != .scrolling
    }

    var goalDescription: String {
        let relation = direction == .atLeast ? "At least" : "No more than"
        return "\(relation) \(SelfCareModel.format(threshold)) \(unit)"
    }
}

struct FactorState: Codable, Equatable {
    var mode: InputMode = .manual
    var manualValue: Double = 0
}

enum HealthSyncState: String, Codable, Equatable {
    case pending
    case notRequested
    case synced
    case unavailable
    case failed
}

struct CheckInRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let moodValue: Double
    let factorValues: [FactorKey: Double]
    let metFactors: Set<FactorKey>
    var customCategoryNames: [UUID: String]?
    var completedCustomCategoryIDs: Set<UUID>?
    var healthSyncState: HealthSyncState
    var healthSampleID: UUID?
    var healthSyncVersion: Int64?

    var moodLabel: String {
        SelfCareModel.moodLabel(for: moodValue)
    }

    var completedFactorCount: Int {
        metFactors.count
    }
}

struct LocalDay: Codable, Equatable {
    let year: Int
    let month: Int
    let day: Int
}

private struct PersistedSelfCareState: Codable {
    var theme: AppTheme
    var moodValue: Double
    var factors: [FactorKey: FactorState]
    var checkIns: [CheckInRecord]?
    var activeDay: LocalDay?
    var customCategories: [SelfCareCategory]?
    var selectedCustomCategoryIDs: Set<UUID>?
    var suppressedCustomCategoryIDs: Set<UUID>?
}

@MainActor
@Observable
final class SelfCareModel {
    private static let storageKey = "selfCare.state.v1"

    private let defaults: UserDefaults

    private(set) var theme: AppTheme
    private(set) var moodValue: Double
    private(set) var factors: [FactorKey: FactorState]
    private(set) var healthValues: [FactorKey: Double] = [:]
    private(set) var checkIns: [CheckInRecord]
    private(set) var activeDay: LocalDay
    private(set) var customCategories: [SelfCareCategory]
    private(set) var selectedCustomCategoryIDs: Set<UUID>
    private(set) var suppressedCustomCategoryIDs: Set<UUID>
    private(set) var persistenceRecoveryMessage: String?

    var editingFactor: FactorKey?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let today = Self.localDay(containing: .now)

        guard let data = defaults.data(forKey: Self.storageKey) else {
            theme = .dark
            moodValue = 53
            factors = Self.defaultFactors
            checkIns = []
            activeDay = today
            customCategories = []
            selectedCustomCategoryIDs = []
            suppressedCustomCategoryIDs = []
            persistenceRecoveryMessage = nil
            return
        }

        do {
            let saved = try JSONDecoder().decode(PersistedSelfCareState.self, from: data)
            theme = saved.theme
            moodValue = min(100, max(0, saved.moodValue))
            factors = Self.mergingDefaults(into: saved.factors)
            checkIns = (saved.checkIns ?? []).sorted { $0.date > $1.date }
            activeDay = saved.activeDay ?? today
            customCategories = saved.customCategories ?? []
            selectedCustomCategoryIDs = saved.selectedCustomCategoryIDs ?? []
            suppressedCustomCategoryIDs = saved.suppressedCustomCategoryIDs ?? []
            persistenceRecoveryMessage = nil
        } catch {
            theme = .dark
            moodValue = 53
            factors = Self.defaultFactors
            checkIns = []
            activeDay = today
            customCategories = []
            selectedCustomCategoryIDs = []
            suppressedCustomCategoryIDs = []
            persistenceRecoveryMessage = "Self Care couldn’t read its saved data, "
                + "so it started with a safe, empty check-in."
        }
    }

    var moodLabel: String {
        Self.moodLabel(for: moodValue)
    }

    var completedFactorCount: Int {
        FactorKey.allCases.filter(isMet).count
    }

    var completedCategoryCount: Int {
        completedFactorCount + customCategories.filter(isCustomCategoryCompleted).count
    }

    var totalCategoryCount: Int {
        FactorKey.allCases.count + customCategories.count
    }

    var checkInLogged: Bool {
        !checkIns.isEmpty
    }

    var latestCheckIn: CheckInRecord? {
        checkIns.first
    }

    func setTheme(_ newTheme: AppTheme) {
        theme = newTheme
        persistBestEffort()
    }

    @discardableResult
    func refreshForCurrentDay(
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let currentDay = Self.localDay(containing: date, calendar: calendar)
        guard activeDay != currentDay else { return false }

        activeDay = currentDay
        moodValue = 53
        healthValues.removeAll()
        factors = factors.mapValues { state in
            FactorState(mode: state.mode, manualValue: 0)
        }
        selectedCustomCategoryIDs.removeAll()
        suppressedCustomCategoryIDs.removeAll()
        persistBestEffort()
        return true
    }

    func setMood(_ newValue: Double) {
        moodValue = min(100, max(0, newValue))
        persistBestEffort()
    }

    func state(for factor: FactorKey) -> FactorState {
        factors[factor] ?? FactorState()
    }

    func value(for factor: FactorKey) -> Double {
        let state = state(for: factor)
        return state.mode == .automatic ? (healthValues[factor] ?? 0) : state.manualValue
    }

    func hasHealthValue(for factor: FactorKey) -> Bool {
        healthValues[factor] != nil
    }

    func isMet(_ factor: FactorKey) -> Bool {
        let currentValue = value(for: factor)
        switch factor.direction {
        case .atLeast: return currentValue >= factor.threshold
        case .atMost: return currentValue <= factor.threshold
        }
    }

    func summary(for factor: FactorKey) -> String {
        if state(for: factor).mode == .automatic && !hasHealthValue(for: factor) {
            return "No data · Health"
        }
        let source = state(for: factor).mode == .automatic ? "Health" : "Manual"
        return "\(Self.format(value(for: factor))) \(factor.unit) · \(source)"
    }

    func setMode(_ mode: InputMode, for factor: FactorKey) {
        var updated = state(for: factor)
        updated.mode = mode == .automatic && !factor.supportsHealthKit ? .manual : mode
        factors[factor] = updated
        persistBestEffort()
    }

    func updateHealthValues(exerciseMinutes: Double?, sleepHours: Double?) {
        healthValues[.exercise] = exerciseMinutes
        healthValues[.sleep] = sleepHours
    }

    func setManualValue(_ value: Double, for factor: FactorKey) {
        var updated = state(for: factor)
        updated.manualValue = max(0, value)
        factors[factor] = updated
        persistBestEffort()
    }

    func quickToggle(_ factor: FactorKey) {
        let margin = max(1, (factor.threshold * 0.3).rounded())
        let nextValue: Double

        if isMet(factor) {
            switch factor.direction {
            case .atLeast: nextValue = max(0, factor.threshold - margin)
            case .atMost: nextValue = factor.threshold + (margin * 2)
            }
        } else {
            switch factor.direction {
            case .atLeast: nextValue = factor.threshold + margin
            case .atMost: nextValue = max(0, factor.threshold - margin)
            }
        }

        factors[factor] = FactorState(mode: .manual, manualValue: nextValue)
        persistBestEffort()
    }

    func isCustomCategoryCompleted(_ category: SelfCareCategory) -> Bool {
        if suppressedCustomCategoryIDs.contains(category.id) {
            return false
        }
        if selectedCustomCategoryIDs.contains(category.id) {
            return true
        }
        guard category.source == .appleHealth, let healthType = category.linkedHealthDataType else {
            return false
        }
        switch healthType {
        case .exerciseTime:
            return (healthValues[.exercise] ?? 0) > 0
        case .sleepAnalysis:
            return (healthValues[.sleep] ?? 0) > 0
        }
    }

    func toggleCustomCategory(_ categoryID: UUID) {
        guard let category = customCategories.first(where: { $0.id == categoryID }) else { return }
        if isCustomCategoryCompleted(category) {
            selectedCustomCategoryIDs.remove(categoryID)
            suppressedCustomCategoryIDs.insert(categoryID)
        } else {
            selectedCustomCategoryIDs.insert(categoryID)
            suppressedCustomCategoryIDs.remove(categoryID)
        }
        persistBestEffort()
    }

    @discardableResult
    func addCategory(
        named name: String,
        healthDataType: SupportedHealthDataType? = nil
    ) throws -> SelfCareCategory {
        let normalizedName = try validatedCategoryName(name)
        let category = SelfCareCategory(
            id: UUID(),
            name: normalizedName,
            source: healthDataType == nil ? .manual : .appleHealth,
            healthDataTypeIdentifier: healthDataType?.healthKitIdentifier,
            isUserCreated: true
        )
        customCategories.append(category)
        do {
            try persist()
            return category
        } catch {
            customCategories.removeAll { $0.id == category.id }
            throw error
        }
    }

    func updateCategory(
        id: UUID,
        name: String,
        healthDataType: SupportedHealthDataType?
    ) throws {
        guard let index = customCategories.firstIndex(where: { $0.id == id }) else {
            throw SelfCareModelError.categoryNotFound
        }
        let normalizedName = try validatedCategoryName(name, excluding: id)
        let previous = customCategories[index]
        customCategories[index].name = normalizedName
        customCategories[index].source = healthDataType == nil ? .manual : .appleHealth
        customCategories[index].healthDataTypeIdentifier = healthDataType?.healthKitIdentifier
        do {
            try persist()
        } catch {
            customCategories[index] = previous
            throw error
        }
    }

    func deleteCategory(id: UUID) throws {
        guard let index = customCategories.firstIndex(where: { $0.id == id }) else {
            throw SelfCareModelError.categoryNotFound
        }
        let category = customCategories.remove(at: index)
        let wasSelected = selectedCustomCategoryIDs.remove(category.id) != nil
        let wasSuppressed = suppressedCustomCategoryIDs.remove(category.id) != nil
        do {
            try persist()
        } catch {
            customCategories.insert(category, at: index)
            if wasSelected {
                selectedCustomCategoryIDs.insert(category.id)
            }
            if wasSuppressed {
                suppressedCustomCategoryIDs.insert(category.id)
            }
            throw error
        }
    }

    func hasCheckedInToday(
        at date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        checkIns.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    @discardableResult
    func logCheckIn(at date: Date = .now) throws -> CheckInRecord {
        let values = Dictionary(uniqueKeysWithValues: FactorKey.allCases.map { ($0, value(for: $0)) })
        let completedCustomIDs = Set(
            customCategories.filter(isCustomCategoryCompleted).map(\.id)
        )
        let record = CheckInRecord(
            id: UUID(),
            date: date,
            moodValue: moodValue,
            factorValues: values,
            metFactors: Set(FactorKey.allCases.filter(isMet)),
            customCategoryNames: Dictionary(uniqueKeysWithValues: customCategories.map { ($0.id, $0.name) }),
            completedCustomCategoryIDs: completedCustomIDs,
            healthSyncState: .pending,
            healthSampleID: nil,
            healthSyncVersion: nil
        )
        checkIns.insert(record, at: 0)
        do {
            try persist()
            return record
        } catch {
            checkIns.removeAll { $0.id == record.id }
            throw error
        }
    }

    func updateHealthSync(
        for checkInID: UUID,
        state: HealthSyncState,
        sampleID: UUID? = nil
    ) {
        guard let index = checkIns.firstIndex(where: { $0.id == checkInID }) else { return }
        checkIns[index].healthSyncState = state
        if let sampleID {
            checkIns[index].healthSampleID = sampleID
        }
        persistBestEffort()
    }

    @discardableResult
    func nextHealthSyncVersion(for checkInID: UUID) -> Int64? {
        guard let index = checkIns.firstIndex(where: { $0.id == checkInID }) else { return nil }
        let nextVersion = (checkIns[index].healthSyncVersion ?? 0) + 1
        checkIns[index].healthSyncVersion = nextVersion
        persistBestEffort()
        return nextVersion
    }

    @discardableResult
    func deleteCheckIn(id: UUID) throws -> CheckInRecord {
        guard let index = checkIns.firstIndex(where: { $0.id == id }) else {
            throw SelfCareModelError.checkInNotFound
        }
        let deleted = checkIns.remove(at: index)
        do {
            try persist()
            return deleted
        } catch {
            checkIns.insert(deleted, at: index)
            throw error
        }
    }

    func dismissPersistenceRecoveryMessage() {
        persistenceRecoveryMessage = nil
    }

    func exportCSV() -> String {
        let header = "date,mood_value,mood_label,exercise_minutes,sleep_hours,scrolling_minutes,goals_met,health_sync"
        let rows = checkIns.map { checkIn in
            [
                checkIn.date.ISO8601Format(),
                Self.format(checkIn.moodValue),
                checkIn.moodLabel,
                Self.format(checkIn.factorValues[.exercise] ?? 0),
                Self.format(checkIn.factorValues[.sleep] ?? 0),
                Self.format(checkIn.factorValues[.scrolling] ?? 0),
                String(checkIn.completedFactorCount),
                checkIn.healthSyncState.rawValue
            ]
            .map(Self.csvField)
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    func resetAllData() {
        defaults.removeObject(forKey: Self.storageKey)
        theme = .dark
        moodValue = 53
        factors = Self.defaultFactors
        healthValues.removeAll()
        checkIns = []
        activeDay = Self.localDay(containing: .now)
        customCategories = []
        selectedCustomCategoryIDs = []
        suppressedCustomCategoryIDs = []
        persistenceRecoveryMessage = nil
    }

    nonisolated static func moodLabel(for value: Double) -> String {
        switch value {
        case ..<25: "Low"
        case ..<50: "Okay"
        case ..<75: "Good"
        default: "Great"
        }
    }

    nonisolated static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    nonisolated static func localDay(
        containing date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> LocalDay {
        let startOfDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        return LocalDay(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    private func persist() throws {
        let state = PersistedSelfCareState(
            theme: theme,
            moodValue: moodValue,
            factors: factors,
            checkIns: checkIns,
            activeDay: activeDay,
            customCategories: customCategories,
            selectedCustomCategoryIDs: selectedCustomCategoryIDs,
            suppressedCustomCategoryIDs: suppressedCustomCategoryIDs
        )
        let data: Data
        do {
            data = try JSONEncoder().encode(state)
        } catch {
            throw SelfCareModelError.persistenceFailed
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func persistBestEffort() {
        do {
            try persist()
        } catch {
            persistenceRecoveryMessage = SelfCareModelError.persistenceFailed.localizedDescription
        }
    }

    private func validatedCategoryName(
        _ name: String,
        excluding excludedID: UUID? = nil
    ) throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw SelfCareModelError.emptyCategoryName
        }
        let builtInNames = FactorKey.allCases.map(\.label)
        let customNames = customCategories
            .filter { $0.id != excludedID }
            .map(\.name)
        guard !(builtInNames + customNames).contains(where: {
            $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw SelfCareModelError.duplicateCategoryName
        }
        return normalized
    }

    private static func mergingDefaults(into saved: [FactorKey: FactorState]) -> [FactorKey: FactorState] {
        var result = saved.mapValues { state in
            FactorState(mode: state.mode, manualValue: max(0, state.manualValue))
        }
        for factor in FactorKey.allCases where result[factor] == nil {
            result[factor] = FactorState()
        }
        if result[.scrolling]?.mode == .automatic {
            result[.scrolling]?.mode = .manual
        }
        return result
    }

    nonisolated private static var defaultFactors: [FactorKey: FactorState] {
        Dictionary(uniqueKeysWithValues: FactorKey.allCases.map { ($0, FactorState()) })
    }

    nonisolated private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
