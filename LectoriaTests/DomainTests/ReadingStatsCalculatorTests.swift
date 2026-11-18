import Testing
import Foundation
@testable import Lectoria

struct ReadingStatsCalculatorTests {

    // MARK: - Fixtures

    /// Calendario fijo: La Paz, semana que empieza en lunes salvo que se indique.
    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/La_Paz")!
        cal.firstWeekday = firstWeekday
        return cal
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar()
        formatter.timeZone = calendar().timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    /// Miércoles 18 de noviembre de 2026, 15:00.
    private var now: Date { date("2026-11-18 15:00") }

    private func session(pub: UUID, start: String, seconds: Int) -> ReadingSession {
        let startDate = date(start)
        return ReadingSession(
            publicationID: pub, startedAt: startDate,
            endedAt: startDate.addingTimeInterval(TimeInterval(seconds)),
            activeSeconds: seconds, startPercentage: 0, endPercentage: 0
        )
    }

    private func publication(_ id: UUID, title: String = "Doc", finishedAt: Date? = nil) -> PublicationRecord {
        PublicationRecord(
            id: id, title: title, publicationType: .pdf, localFileName: "\(id).pdf",
            mimeType: "application/pdf", fileSize: 1, sha256: id.uuidString, finishedAt: finishedAt
        )
    }

    private func compute(
        _ sessions: [ReadingSession],
        publications: [PublicationRecord] = [],
        progress: [UUID: Double] = [:],
        firstWeekday: Int = 2
    ) -> ReadingStats {
        ReadingStatsCalculator.compute(
            sessions: sessions, publications: publications, progressByPublication: progress,
            weeklyGoalMinutes: 120, now: now, calendar: calendar(firstWeekday: firstWeekday)
        )
    }

    // MARK: - Tests

    @Test func testEmptyInputGivesZerosAndSevenEmptyDays() {
        let stats = compute([])
        #expect(stats.last7Days.count == 7)
        #expect(stats.last7Days.allSatisfy { $0.minutes == 0 })
        #expect(stats.last7Days.last?.date == calendar().startOfDay(for: now))
        #expect(stats.totalMinutes == 0)
        #expect(stats.weekMinutes == 0)
        #expect(stats.currentStreak == 0)
        #expect(stats.startedCount == 0)
        #expect(stats.finishedCount == 0)
        #expect(stats.topPublications.isEmpty)
        #expect(stats.hasAnyData == false)
        #expect(stats.weeklyGoalMinutes == 120)
        #expect(ReadingStatsCalculator.mascotMessage(for: stats) == "Tus estadísticas aparecerán cuando empieces a leer")
    }

    @Test func testDedupeKeepsLongestCheckpoint() {
        let pub = UUID()
        let stats = compute([
            session(pub: pub, start: "2026-11-18 10:00", seconds: 120),
            session(pub: pub, start: "2026-11-18 10:00", seconds: 300),
            session(pub: pub, start: "2026-11-18 10:00", seconds: 600)
        ])
        #expect(stats.totalMinutes == 10)
    }

    @Test func testSessionCrossingMidnightCountsOnStartDay() {
        let stats = compute([session(pub: UUID(), start: "2026-11-17 23:50", seconds: 1800)])
        let day17 = calendar().startOfDay(for: date("2026-11-17 12:00"))
        let day18 = calendar().startOfDay(for: now)
        #expect(stats.last7Days.first { $0.date == day17 }?.minutes == 30)
        #expect(stats.last7Days.first { $0.date == day18 }?.minutes == 0)
    }

    @Test func testStreakEndsYesterdayWhenNoReadingToday() {
        let pub = UUID()
        let stats = compute([
            session(pub: pub, start: "2026-11-16 09:00", seconds: 120),
            session(pub: pub, start: "2026-11-17 09:00", seconds: 120)
        ])
        #expect(stats.currentStreak == 2)
        #expect(stats.hasReadToday == false)
    }

    @Test func testStreakCountsTodayAndIgnoresUnder60Seconds() {
        let pub = UUID()
        let stats = compute([
            session(pub: pub, start: "2026-11-16 09:00", seconds: 120),
            session(pub: pub, start: "2026-11-17 09:00", seconds: 59),
            session(pub: pub, start: "2026-11-18 09:00", seconds: 120)
        ])
        #expect(stats.currentStreak == 1)
        #expect(stats.hasReadToday == true)
    }

    @Test func testWeekStartsOnCalendarFirstWeekday() {
        let sunday = [session(pub: UUID(), start: "2026-11-15 10:00", seconds: 600)]
        #expect(compute(sunday, firstWeekday: 2).weekMinutes == 0)
        #expect(compute(sunday, firstWeekday: 1).weekMinutes == 10)
    }

    @Test func testActiveDaysThisMonthExcludesOtherMonths() {
        let pub = UUID()
        let stats = compute([
            session(pub: pub, start: "2026-10-31 10:00", seconds: 120),
            session(pub: pub, start: "2026-11-02 10:00", seconds: 120)
        ])
        #expect(stats.activeDaysThisMonth == 1)
    }

    @Test func testStartedAndFinishedCounts() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        let stats = compute(
            [session(pub: a, start: "2026-11-18 10:00", seconds: 120)],
            publications: [
                publication(a), publication(b),
                publication(c, finishedAt: date("2026-11-01 10:00")), publication(d)
            ],
            progress: [a: 0.5, b: 0.99]
        )
        #expect(stats.startedCount == 2)
        #expect(stats.finishedCount == 2)
    }

    @Test func testTopPublicationsMaxThreeSortedAndSkipsDeleted() {
        let p1 = UUID(), p2 = UUID(), p3 = UUID(), p4 = UUID(), deleted = UUID()
        let stats = compute(
            [
                session(pub: p1, start: "2026-11-10 10:00", seconds: 60 * 5),
                session(pub: p2, start: "2026-11-11 10:00", seconds: 60 * 20),
                session(pub: p3, start: "2026-11-12 10:00", seconds: 60 * 10),
                session(pub: p4, start: "2026-11-13 10:00", seconds: 60 * 1),
                session(pub: deleted, start: "2026-11-14 10:00", seconds: 60 * 90)
            ],
            publications: [
                publication(p1, title: "Uno"), publication(p2, title: "Dos"),
                publication(p3, title: "Tres"), publication(p4, title: "Cuatro")
            ]
        )
        #expect(stats.topPublications.map(\.title) == ["Dos", "Tres", "Uno"])
        #expect(stats.topPublications.map(\.minutes) == [20, 10, 5])
    }

    @Test func testMascotMessages() {
        let pub = UUID()
        let oneDay = compute([session(pub: pub, start: "2026-11-18 09:00", seconds: 120)])
        #expect(ReadingStatsCalculator.mascotMessage(for: oneDay) == "Llevas 1 día seguido leyendo")

        let threeDays = compute([
            session(pub: pub, start: "2026-11-16 09:00", seconds: 120),
            session(pub: pub, start: "2026-11-17 09:00", seconds: 120),
            session(pub: pub, start: "2026-11-18 09:00", seconds: 120)
        ])
        #expect(ReadingStatsCalculator.mascotMessage(for: threeDays) == "Llevas 3 días seguidos leyendo")

        let noStreak = compute([session(pub: pub, start: "2026-11-10 09:00", seconds: 120)])
        #expect(ReadingStatsCalculator.mascotMessage(for: noStreak) == "¿Leemos un rato hoy?")
    }
}
