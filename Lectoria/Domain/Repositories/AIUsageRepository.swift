import Foundation

// MARK: - AIUsageRepository

/// Contrato para llevar el control local de cuotas consumidas de IA.
public protocol AIUsageRepository: Sendable {
    /// Obtiene todos los registros de consumo de IA locales.
    func fetchAll() async throws -> [AIUsage]

    /// Registra una nueva operación de IA.
    func save(_ usage: AIUsage) async throws

    /// Calcula la cantidad total de créditos consumidos en el día de hoy.
    func fetchTotalCreditsUsedToday() async throws -> Int
}
