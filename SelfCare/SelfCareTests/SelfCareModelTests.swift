import XCTest
@testable import SelfCare

@MainActor
final class SelfCareModelTests: XCTestCase {
    func testMoodLabelsFollowPrototypeRanges() {
        XCTAssertEqual(SelfCareModel.moodLabel(for: 0), "Low")
        XCTAssertEqual(SelfCareModel.moodLabel(for: 25), "Okay")
        XCTAssertEqual(SelfCareModel.moodLabel(for: 50), "Good")
        XCTAssertEqual(SelfCareModel.moodLabel(for: 75), "Great")
    }

    func testQuickToggleMovesExerciseAcrossGoal() {
        let model = SelfCareModel(defaults: freshDefaults())

        XCTAssertFalse(model.isMet(.exercise))
        model.quickToggle(.exercise)
        XCTAssertTrue(model.isMet(.exercise))
        XCTAssertEqual(model.state(for: .exercise).mode, .manual)

        model.quickToggle(.exercise)
        XCTAssertFalse(model.isMet(.exercise))
    }

    func testScrollingUsesAtMostGoalDirection() {
        let model = SelfCareModel(defaults: freshDefaults())

        XCTAssertTrue(model.isMet(.scrolling))
        model.quickToggle(.scrolling)
        XCTAssertFalse(model.isMet(.scrolling))
        model.quickToggle(.scrolling)
        XCTAssertTrue(model.isMet(.scrolling))
    }

    func testStatePersistsLocally() {
        let defaults = freshDefaults()
        let first = SelfCareModel(defaults: defaults)
        first.setTheme(.light)
        first.setMood(81)
        first.setManualValue(32, for: .exercise)

        let restored = SelfCareModel(defaults: defaults)
        XCTAssertEqual(restored.theme, .light)
        XCTAssertEqual(restored.moodValue, 81)
        XCTAssertEqual(restored.value(for: .exercise), 32)
    }

    func testCorruptPersistenceRecoversWithoutCrashing() {
        let defaults = freshDefaults()
        defaults.set(Data("not valid JSON".utf8), forKey: "selfCare.state.v1")

        let model = SelfCareModel(defaults: defaults)

        XCTAssertTrue(model.checkIns.isEmpty)
        XCTAssertEqual(model.moodValue, 53)
        XCTAssertNotNil(model.persistenceRecoveryMessage)
    }

    func testNewLocalDayResetsDailyInputsButPreservesHistoryAndModes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
        let model = SelfCareModel(defaults: freshDefaults())

        model.refreshForCurrentDay(at: firstDay, calendar: calendar)
        model.setMode(.automatic, for: .exercise)
        model.setMood(91)
        model.setManualValue(45, for: .sleep)
        let checkIn = model.logCheckIn(at: firstDay)

        XCTAssertTrue(model.refreshForCurrentDay(at: nextDay, calendar: calendar))
        XCTAssertEqual(model.moodValue, 53)
        XCTAssertEqual(model.state(for: .exercise).mode, .automatic)
        XCTAssertEqual(model.state(for: .sleep).manualValue, 0)
        XCTAssertEqual(model.checkIns, [checkIn])
        XCTAssertFalse(model.refreshForCurrentDay(at: nextDay, calendar: calendar))
    }

    func testTravelWithinSameLocalCalendarDateDoesNotResetTwice() throws {
        var eastern = Calendar(identifier: .gregorian)
        eastern.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let easternMorning = try XCTUnwrap(eastern.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: 9)))
        let pacificMorning = try XCTUnwrap(pacific.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: 9)))
        let model = SelfCareModel(defaults: freshDefaults())

        model.refreshForCurrentDay(at: easternMorning, calendar: eastern)
        model.setMood(88)

        XCTAssertFalse(model.refreshForCurrentDay(at: pacificMorning, calendar: pacific))
        XCTAssertEqual(model.moodValue, 88)
    }

    func testHealthQueryWindowsUseCalendarBoundariesAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let afterSpringForward = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 10))
        )

        let exercise = HealthKitManager.exerciseWindow(endingAt: afterSpringForward, calendar: calendar)
        let sleep = try XCTUnwrap(HealthKitManager.sleepWindow(endingAt: afterSpringForward, calendar: calendar))

        XCTAssertTrue(calendar.isDate(exercise.start, inSameDayAs: afterSpringForward))
        XCTAssertEqual(calendar.component(.hour, from: exercise.start), 0)
        XCTAssertEqual(calendar.component(.hour, from: sleep.start), 18)
        XCTAssertEqual(calendar.component(.day, from: sleep.start), 7)
        XCTAssertEqual(calendar.component(.hour, from: sleep.end), 10)
    }

    func testHealthValuesDriveAutomaticFactors() {
        let model = SelfCareModel(defaults: freshDefaults())
        model.setMode(.automatic, for: .exercise)
        model.setMode(.automatic, for: .sleep)

        XCTAssertFalse(model.hasHealthValue(for: .exercise))
        XCTAssertEqual(model.summary(for: .exercise), "No data · Health")

        model.updateHealthValues(exerciseMinutes: 42, sleepHours: 7.5)

        XCTAssertEqual(model.value(for: .exercise), 42)
        XCTAssertEqual(model.value(for: .sleep), 7.5)
        XCTAssertEqual(model.summary(for: .exercise), "42 min · Health")
        XCTAssertTrue(model.isMet(.exercise))
    }

    func testScrollingCannotUseHealthKit() {
        let model = SelfCareModel(defaults: freshDefaults())

        model.setMode(.automatic, for: .scrolling)

        XCTAssertEqual(model.state(for: .scrolling).mode, .manual)
    }

    func testSleepIntervalsMergeWithoutDoubleCounting() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let intervals = [
            DateInterval(start: start, duration: 2 * 3_600),
            DateInterval(start: start.addingTimeInterval(3_600), duration: 2 * 3_600),
            DateInterval(start: start.addingTimeInterval(4 * 3_600), duration: 3_600)
        ]

        XCTAssertEqual(HealthKitManager.unionDuration(of: intervals), 4 * 3_600)
    }

    func testCheckInsCaptureSnapshotsAndPersist() {
        let defaults = freshDefaults()
        let model = SelfCareModel(defaults: defaults)
        model.setMood(83)
        model.setManualValue(35, for: .exercise)
        model.setManualValue(8, for: .sleep)
        model.setManualValue(20, for: .scrolling)

        let date = Date(timeIntervalSinceReferenceDate: 123_456)
        let checkIn = model.logCheckIn(at: date)

        XCTAssertEqual(checkIn.date, date)
        XCTAssertEqual(checkIn.moodValue, 83)
        XCTAssertEqual(checkIn.factorValues[.exercise], 35)
        XCTAssertEqual(checkIn.metFactors, Set(FactorKey.allCases))
        XCTAssertEqual(checkIn.healthSyncState, .pending)

        let restored = SelfCareModel(defaults: defaults)
        XCTAssertEqual(restored.checkIns, [checkIn])
    }

    func testMultipleCheckInsAreNewestFirst() {
        let model = SelfCareModel(defaults: freshDefaults())
        let earlier = model.logCheckIn(at: Date(timeIntervalSinceReferenceDate: 100))
        let later = model.logCheckIn(at: Date(timeIntervalSinceReferenceDate: 200))

        XCTAssertEqual(model.checkIns.map(\.id), [later.id, earlier.id])
    }

    func testHealthSyncStatePersists() {
        let defaults = freshDefaults()
        let model = SelfCareModel(defaults: defaults)
        let checkIn = model.logCheckIn()
        let sampleID = UUID()

        model.updateHealthSync(for: checkIn.id, state: .synced, sampleID: sampleID)

        let restored = SelfCareModel(defaults: defaults)
        XCTAssertEqual(restored.checkIns.first?.healthSyncState, .synced)
        XCTAssertEqual(restored.checkIns.first?.healthSampleID, sampleID)
    }

    func testExportAndResetAreExplicitAndComplete() {
        let defaults = freshDefaults()
        let model = SelfCareModel(defaults: defaults)
        model.setMood(72)
        model.logCheckIn(at: Date(timeIntervalSince1970: 1_700_000_000))

        let csv = model.exportCSV()
        XCTAssertTrue(csv.hasPrefix("date,mood_value"))
        XCTAssertTrue(csv.contains(",72,Good,"))

        model.resetAllData()

        XCTAssertTrue(model.checkIns.isEmpty)
        XCTAssertEqual(model.moodValue, 53)
        XCTAssertFalse(model.hasCompletedOnboarding)
        XCTAssertNil(defaults.data(forKey: "selfCare.state.v1"))
    }

    func testOnboardingChoicePersists() {
        let defaults = freshDefaults()
        let model = SelfCareModel(defaults: defaults)
        XCTAssertFalse(model.hasCompletedOnboarding)

        model.completeOnboarding()

        XCTAssertTrue(SelfCareModel(defaults: defaults).hasCompletedOnboarding)
    }

    func testMoodMapsToHealthKitValence() {
        XCTAssertEqual(HealthKitManager.stateOfMindValence(for: 0), -1)
        XCTAssertEqual(HealthKitManager.stateOfMindValence(for: 50), 0)
        XCTAssertEqual(HealthKitManager.stateOfMindValence(for: 100), 1)
        XCTAssertEqual(HealthKitManager.stateOfMindValence(for: 150), 1)
    }

    private func freshDefaults() -> UserDefaults {
        let suiteName = "SelfCareTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
