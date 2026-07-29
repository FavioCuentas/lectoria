import Testing
import Foundation
@testable import Lectoria

// MARK: - MonetizationSchemaValidationTests

struct MonetizationSchemaValidationTests {

    @Test("SQL Migration file exists and contains essential table definitions")
    func testMigrationFileStructure() throws {
        let migrationURL = URL(fileURLWithPath: "/Users/faviocuentas/Documents/Projects/Lectoria IA/supabase/migrations/20260730000000_monetization_schema.sql")
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
