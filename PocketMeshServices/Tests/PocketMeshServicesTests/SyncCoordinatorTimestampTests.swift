import Testing
import Foundation
@testable import PocketMeshServices

@Suite("SyncCoordinator Timestamp Correction")
struct SyncCoordinatorTimestampTests {

    // MARK: - Test Constants

    private let oneMinute: TimeInterval = 60
    private let fiveMinutes: TimeInterval = 5 * 60
    private let sixMinutes: TimeInterval = 6 * 60
    private let oneWeek: TimeInterval = 7 * 24 * 60 * 60
    private let threeMonths: TimeInterval = 3 * 30 * 24 * 60 * 60
    private let sixMonths: TimeInterval = 6 * 30 * 24 * 60 * 60
    private let sevenMonths: TimeInterval = 7 * 30 * 24 * 60 * 60

    // MARK: - Valid Range Tests

    @Test("Timestamp within valid range is not corrected")
    func validTimestampNotCorrected() {
        let now = Date()
        let timestamp = UInt32(now.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    // MARK: - Future Timestamp Tests

    @Test("Timestamp 1 minute in future is not corrected")
    func oneMinuteFutureNotCorrected() {
        let now = Date()
        let futureDate = now.addingTimeInterval(oneMinute)
        let timestamp = UInt32(futureDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    @Test("Timestamp exactly 5 minutes in future is not corrected")
    func exactlyFiveMinutesFutureNotCorrected() {
        let now = Date()
        let futureDate = now.addingTimeInterval(fiveMinutes)
        let timestamp = UInt32(futureDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    @Test("Timestamp 6 minutes in future is corrected")
    func sixMinutesFutureIsCorrected() {
        let now = Date()
        let futureDate = now.addingTimeInterval(sixMinutes)
        let timestamp = UInt32(futureDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(wasCorrected)
        #expect(corrected == UInt32(now.timeIntervalSince1970))
    }

    // MARK: - Past Timestamp Tests

    @Test("Timestamp 1 week ago is not corrected")
    func oneWeekAgoNotCorrected() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-oneWeek)
        let timestamp = UInt32(pastDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    @Test("Timestamp 3 months ago is not corrected")
    func threeMonthsAgoNotCorrected() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-threeMonths)
        let timestamp = UInt32(pastDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    @Test("Timestamp exactly 6 months in past is not corrected")
    func exactlySixMonthsAgoNotCorrected() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-sixMonths)
        let timestamp = UInt32(pastDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(!wasCorrected)
        #expect(corrected == timestamp)
    }

    @Test("Timestamp 7 months ago is corrected")
    func sevenMonthsAgoIsCorrected() {
        let now = Date()
        let pastDate = now.addingTimeInterval(-sevenMonths)
        let timestamp = UInt32(pastDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(wasCorrected)
        #expect(corrected == UInt32(now.timeIntervalSince1970))
    }

    // MARK: - Edge Case Tests

    @Test("Timestamp of zero (Unix epoch) is corrected")
    func unixEpochIsCorrected() {
        let now = Date()
        let timestamp: UInt32 = 0

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(wasCorrected)
        #expect(corrected == UInt32(now.timeIntervalSince1970))
    }

    @Test("Timestamp from year 2020 is corrected")
    func year2020IsCorrected() {
        let now = Date()
        let oldDate = Date(timeIntervalSince1970: 1577836800) // Jan 1, 2020
        let timestamp = UInt32(oldDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(wasCorrected)
        #expect(corrected == UInt32(now.timeIntervalSince1970))
    }

    @Test("Timestamp from year 2030 is corrected")
    func year2030IsCorrected() {
        let now = Date()
        let futureDate = Date(timeIntervalSince1970: 1893456000) // Jan 1, 2030
        let timestamp = UInt32(futureDate.timeIntervalSince1970)

        let (corrected, wasCorrected) = SyncCoordinator.correctTimestampIfNeeded(timestamp, receiveTime: now)

        #expect(wasCorrected)
        #expect(corrected == UInt32(now.timeIntervalSince1970))
    }
}
