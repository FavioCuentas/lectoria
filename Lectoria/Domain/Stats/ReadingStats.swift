import Foundation

// MARK: - DayMinutes

/// Minutos leídos en un día concreto (para el gráfico de los últimos 7 días).
struct DayMinutes: Equatable, Identifiable, Sendable {
    /// Inicio del día en el calendario del usuario.
    let date: Date
    let minutes: Int
    var id: Date { date }
}

// MARK: - TopPublication

/// Documento entre los más leídos, con sus minutos totales.
struct TopPublication: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let minutes: Int
}

// MARK: - ReadingStats

/// Resultado del cálculo de estadísticas de lectura que muestra `StatsView`.
struct ReadingStats: Equatable, Sendable {
    var weekMinutes: Int
    var weeklyGoalMinutes: Int
    /// 7 elementos, del más antiguo a hoy.
    var last7Days: [DayMinutes]
    var currentStreak: Int
    var activeDaysThisMonth: Int
    var totalMinutes: Int
    var startedCount: Int
    var finishedCount: Int
    /// Máximo 3, de más a menos minutos.
    var topPublications: [TopPublication]
    var hasReadToday: Bool
    /// Hay al menos una sesión con tiempo de lectura.
    var hasAnyData: Bool
}
