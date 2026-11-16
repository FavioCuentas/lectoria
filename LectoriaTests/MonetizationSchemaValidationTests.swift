import Testing
import Foundation
@testable import Lectoria

// MARK: - MonetizationSchemaValidationTests

struct MonetizationSchemaValidationTests {

    /// Migración dentro del repositorio, resuelta desde la ubicación de este archivo de pruebas.
    static let migrationURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // LectoriaTests/
        .deletingLastPathComponent() // raíz del repositorio
        .appendingPathComponent("supabase/migrations/20260730000000_monetization_schema.sql")

    /// Solo ejecutable donde el sistema de archivos del repositorio es accesible (Mac/simulador);
    /// en un iPhone físico el sandbox no puede leer el disco de la Mac y la prueba se omite.
    static var migrationFileReachable: Bool {
        FileManager.default.fileExists(atPath: migrationURL.path)
    }

    @Test(
        "SQL Migration file exists and contains essential table definitions",
        .enabled(if: MonetizationSchemaValidationTests.migrationFileReachable, "Repositorio no accesible desde este destino de pruebas (dispositivo físico)")
    )
    func testMigrationFileStructure() throws {
        let migrationURL = Self.migrationURL
        #expect(FileManager.default.fileExists(atPath: migrationURL.path))

        let sqlContent = try String(contentsOf: migrationURL, encoding: .utf8)

        #expect(sqlContent.contains("CREATE TABLE IF NOT EXISTS public.subscription_entitlements"))
        #expect(sqlContent.contains("CREATE TABLE IF NOT EXISTS public.purchase_transactions"))
        #expect(sqlContent.contains("CREATE TABLE IF NOT EXISTS public.founder_allocations"))
        #expect(sqlContent.contains("CREATE TABLE IF NOT EXISTS public.lifetime_allocations"))
        #expect(sqlContent.contains("CREATE TABLE IF NOT EXISTS public.registered_devices"))

        #expect(sqlContent.contains("claim_founder_allocation"))
        #expect(sqlContent.contains("1000"))
        #expect(sqlContent.contains("claim_lifetime_allocation"))
        #expect(sqlContent.contains("250"))

        #expect(sqlContent.contains("ENABLE ROW LEVEL SECURITY"))
    }
}
