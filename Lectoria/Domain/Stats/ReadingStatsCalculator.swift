import Foundation

// MARK: - ReadingStatsCalculator

/// Calcula las estadísticas de lectura a partir de las sesiones guardadas.
///
/// Es puro (sin acceso a base de datos ni reloj propio) para poder probarlo:
/// recibe `now` y el `Calendar` del usuario, que define zona horaria e inicio de semana.
enum ReadingStatsCalculator {
    /// Segundos mínimos de lectura en un día para considerarlo "día activo".
    static let activeDayThresholdSeconds = 60
    /// Progreso a partir del cual un documento cuenta como terminado.
    static let finishedThreshold = 0.98

    /// Quita checkpoints duplicados de versiones antiguas de la app: varias sesiones del mismo
    /// documento con el mismo `startedAt` son la misma lectura; se conserva la de más segundos.
    static func dedupe(_ sessions: [ReadingSession]) -> [ReadingSession] {
        struct Key: Hashable { let publicationID: UUID; let startedAt: Date }
        var best: [Key: ReadingSession] = [:]
        for session in sessions {
            let key = Key(publicationID: session.publicationID, startedAt: session.startedAt)
            if let current = best[key], current.activeSeconds >= session.activeSeconds { continue }
            best[key] = session
        }
        return Array(best.values)
    }

    static func compute(
        sessions: [ReadingSession],
        publications: [PublicationRecord],
        progressByPublication: [UUID: Double],
        weeklyGoalMinutes: Int,
        now: Date,
        calendar: Calendar
    ) -> ReadingStats {
        let unique = dedupe(sessions)
        let today = calendar.startOfDay(for: now)

        // Segundos por día (cada sesión cuenta entera en el día en que empezó).
        var secondsByDay: [Date: Int] = [:]
        for session in unique {
            secondsByDay[calendar.startOfDay(for: session.startedAt), default: 0] += session.activeSeconds
        }
        func isActive(_ day: Date) -> Bool {
            (secondsByDay[day] ?? 0) >= activeDayThresholdSeconds
        }
        func day(_ offset: Int, from base: Date) -> Date {
            calendar.date(byAdding: .day, value: offset, to: base) ?? base
        }

        let last7Days = (0..<7).reversed().map { back -> DayMinutes in
            let date = day(-back, from: today)
            return DayMinutes(date: date, minutes: (secondsByDay[date] ?? 0) / 60)
        }

        // Racha: desde hoy, o desde ayer si hoy aún no hay lectura suficiente.
        let hasReadToday = isActive(today)
        var streak = 0
        var cursor = hasReadToday ? today : day(-1, from: today)
        while isActive(cursor) {
            streak += 1
            cursor = day(-1, from: cursor)
        }

        let weekSeconds = calendar.dateInterval(of: .weekOfYear, for: now).map { week in
            unique.filter { week.contains($0.startedAt) }.reduce(0) { $0 + $1.activeSeconds }
        } ?? 0

        let activeDaysThisMonth = secondsByDay.keys.filter {
            calendar.isDate($0, equalTo: now, toGranularity: .month) && isActive($0)
        }.count

        let totalSeconds = unique.reduce(0) { $0 + $1.activeSeconds }

        // Documentos iniciados y terminados.
        let publicationsWithSessions = Set(unique.filter { $0.activeSeconds > 0 }.map(\.publicationID))
        let startedCount = publications.filter {
            publicationsWithSessions.contains($0.id) || (progressByPublication[$0.id] ?? 0) > 0
                || $0.finishedAt != nil || (progressByPublication[$0.id] ?? 0) >= finishedThreshold
        }.count
        let finishedCount = publications.filter {
            $0.finishedAt != nil || (progressByPublication[$0.id] ?? 0) >= finishedThreshold
        }.count

        // Más leídos: solo publicaciones que aún existen.
        var secondsByPublication: [UUID: Int] = [:]
        for session in unique {
            secondsByPublication[session.publicationID, default: 0] += session.activeSeconds
        }
        let topPublications = publications
            .compactMap { pub -> TopPublication? in
                guard let seconds = secondsByPublication[pub.id], seconds > 0 else { return nil }
                return TopPublication(id: pub.id, title: pub.title, minutes: seconds / 60)
            }
            .sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.title < $1.title }
            .prefix(3)

        return ReadingStats(
            weekMinutes: weekSeconds / 60,
            weeklyGoalMinutes: weeklyGoalMinutes,
            last7Days: last7Days,
            currentStreak: streak,
            activeDaysThisMonth: activeDaysThisMonth,
            totalMinutes: totalSeconds / 60,
            startedCount: startedCount,
            finishedCount: finishedCount,
            topPublications: Array(topPublications),
            hasReadToday: hasReadToday,
            hasAnyData: totalSeconds > 0
        )
    }

    /// Mensaje amable (sin culpa) que acompaña a la mascota.
    static func mascotMessage(for stats: ReadingStats) -> String {
        if !stats.hasAnyData {
            return String(localized: "Tus estadísticas aparecerán cuando empieces a leer", comment: "Stats: mascot message, no data")
        }
        switch stats.currentStreak {
        case 0:
            return String(localized: "¿Leemos un rato hoy?", comment: "Stats: mascot message, no streak")
        case 1:
            return String(localized: "Llevas 1 día seguido leyendo", comment: "Stats: mascot message, 1-day streak")
        default:
            return String(localized: "Llevas \(stats.currentStreak) días seguidos leyendo", comment: "Stats: mascot message, streak")
        }
    }
}
