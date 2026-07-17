import Testing
import Foundation
import SwiftData
@testable import Lectoria

// MARK: - OpenURLTests

@MainActor
struct OpenURLTests {
    private let container: ModelContainer
    private let dependencies: AppDependencies

    init() {
        self.container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        self.dependencies = AppDependencies(
            modelContainer: container,
            authService: MockAuthService(),
            subscriptionService: MockSubscriptionService(),
            aiService: MockAIService()
        )
    }

    @Test("Parse lectoria://import-text custom url scheme and import text")
    func parseLectoriaCustomScheme() async throws {
        let urlString = "lectoria://import-text?text=Este%20es%20un%20texto%20de%20prueba%20compartido&title=Mi%20Titulo"
        guard let url = URL(string: urlString) else {
            Issue.record("URL inválida")
            return
        }
        
        #expect(url.scheme == "lectoria")
        #expect(url.host == "import-text")
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            let text = queryItems.first(where: { $0.name == "text" })?.value
            let title = queryItems.first(where: { $0.name == "title" })?.value
            
            #expect(text == "Este es un texto de prueba compartido")
            #expect(title == "Mi Titulo")
            
            // Probar la importación
            if let text {
                let record = try await dependencies.importService.importPastedText(text: text, title: title ?? "")
                #expect(record.title == "Mi Titulo")
                #expect(record.publicationType == .pastedText)
            }
        } else {
            Issue.record("No se pudieron extraer componentes de la URL")
        }
    }
}
