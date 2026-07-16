import SwiftUI
import ReadiumShared
import ReadiumNavigator

// MARK: - EPUBNavigatorWrapper

/// Wrapper de SwiftUI para el `EPUBNavigatorViewController` de Readium.
///
/// Permite renderizar y controlar la paginación y formato de libros EPUB nativos
/// dentro de vistas SwiftUI, manteniendo sincronizado el progreso y las preferencias.
struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    let publication: Publication
    let initialLocation: EPUBLocation?
    
    @Binding var currentLocation: EPUBLocation?
    let preferences: EPUBPreferences
    
    /// Callback disparado al hacer tap en la pantalla (usado para alternar barras de herramientas).
    var onTap: ((CGPoint) -> Void)? = nil
    
    /// Ubicación externa forzada (para navegar desde el índice/TOC).
    var targetLocation: EPUBLocation? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        let config = EPUBNavigatorViewController.Configuration(
            preferences: preferences
        )
        
        // Dado que abrimos EPUBs sin DRM locales previamente validados, la instanciación es segura.
        let navigator = try! EPUBNavigatorViewController(
            publication: publication,
            initialLocation: initialLocation?.locator,
            config: config
        )
        
        navigator.delegate = context.coordinator
        context.coordinator.navigator = navigator
        
        return navigator
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        // Enviar las preferencias actualizadas al renderizador de Readium
        uiViewController.submitPreferences(preferences)
        
        // Manejar navegación externa solicitada (ej. saltos del TOC)
        if let target = targetLocation, target != context.coordinator.lastTarget {
            context.coordinator.lastTarget = target
            Task { @MainActor in
                _ = await uiViewController.go(to: target.locator, options: .animated)
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, EPUBNavigatorDelegate {
        var parent: EPUBNavigatorWrapper
        weak var navigator: EPUBNavigatorViewController?
        var lastTarget: EPUBLocation?

        init(_ parent: EPUBNavigatorWrapper) {
            self.parent = parent
        }

        // MARK: - EPUBNavigatorDelegate

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            // Sincronizar el progreso actual de lectura con SwiftUI
            parent.currentLocation = EPUBLocation(locator: locator)
        }

        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
            // Propagar gestos de toque
            parent.onTap?(point)
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Manejo de errores de navegación
            print("[EPUBNavigatorWrapper] Error del navegador: \(error)")
        }
    }
}
