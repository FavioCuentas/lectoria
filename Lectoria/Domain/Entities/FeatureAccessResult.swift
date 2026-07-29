import Foundation

// MARK: - FeatureAccessResult

/// Resultado tipado de la evaluación de acceso a una función del sistema.
public enum FeatureAccessResult: Equatable, Sendable {
    /// Acceso permitido sin restricciones.
    case allowed

    /// Requiere plan Premium o Lifetime.
    case requiresPremium

    /// El hardware o sistema operativo actual no es compatible.
    case requiresCompatibleDevice

    /// Se ha alcanzado el límite permitido para el plan actual.
    case limitReached(message: String)

    /// Función exclusiva para cuentas con licencia institucional activa.
    case institutionalOnly

    /// La función no está disponible temporalmente.
    case unavailable(reason: String)
}
