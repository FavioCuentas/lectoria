import Foundation

// MARK: - EntitlementService

/// Protocolo maestro para evaluar los derechos de acceso y límites comerciales de Lectoría.
public protocol EntitlementService: FeatureEntitlementService, Sendable {
    /// Obtiene la fuente de verdad consolidada de entitlements del usuario actual.
    func currentEntitlements() async -> Entitlements

    /// Fuerza la actualización y reconciliación de los derechos desde las distintas fuentes (StoreKit, Supabase, Local).
    func refreshEntitlements() async throws

    /// Evalúa si el usuario tiene permiso para acceder a una función específica del sistema.
    func canAccess(_ feature: AppFeature) async -> FeatureAccessResult

    /// Evalúa la fuente activa de mayor prioridad entre un conjunto de licencias/fuentes.
    func resolveHighestPrioritySource(_ sources: [EntitlementSource]) -> EntitlementSource
}
