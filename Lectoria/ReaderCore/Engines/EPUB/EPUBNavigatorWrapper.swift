import SwiftUI
@preconcurrency import ReadiumShared
@preconcurrency import ReadiumNavigator

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
    
    @Binding var selectedText: String
    @Binding var hasSelection: Bool
    @Binding var selectedLocator: Locator?
    let highlights: [Highlight]
    
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
        
        do {
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: initialLocation?.locator,
                config: config
            )
            navigator.delegate = context.coordinator
            context.coordinator.navigator = navigator
            return navigator
        } catch {
            print("[EPUBNavigatorWrapper] Error al instanciar Navigator con posición inicial: \(error). Reintentando sin posición.")
            if let navigator = try? EPUBNavigatorViewController(
                publication: publication,
                initialLocation: nil,
                config: config
            ) {
                navigator.delegate = context.coordinator
                context.coordinator.navigator = navigator
                return navigator
            }
            fatalError("No se pudo instanciar el EPUBNavigatorViewController de Readium: \(error.localizedDescription)")
        }
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
        
        // Despejar selección reactivamente si hasSelection se pone en false externamente
        if !hasSelection {
            uiViewController.clearSelection()
        }
        
        // Renderizar los destacados usando la API de Decoraciones de Readium
        if let decorable = uiViewController as? DecorableNavigator {
            let decorations = highlights.compactMap { hl -> Decoration? in
                guard let locator = try? Locator(jsonString: hl.anchor) else {
                    return nil
                }
                
                let color = highlightColor(for: hl.colorToken)
                
                return Decoration(
                    id: hl.id.uuidString,
                    locator: locator,
                    style: .highlight(tint: color)
                )
            }
            decorable.apply(decorations: decorations, in: "highlights")
        }
    }
    
    private func highlightColor(for token: String) -> UIColor {
        switch token.lowercased() {
        case "idea principal", "blue", "mainidea":
            return UIColor(red: 0.30, green: 0.55, blue: 0.80, alpha: 0.35)
        case "duda", "purple", "question":
            return UIColor(red: 0.55, green: 0.38, blue: 0.75, alpha: 0.35)
        case "evidencia", "green", "evidence":
            return UIColor(red: 0.25, green: 0.65, blue: 0.45, alpha: 0.35)
        case "acción", "accion", "orange", "coral", "action":
            return UIColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0.35)
        case "cita", "pink", "quote":
            return UIColor(red: 0.80, green: 0.42, blue: 0.55, alpha: 0.35)
        default:
            return UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.35)
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
            
            // Si el usuario toca la pantalla, despejar la selección activa
            parent.selectedText = ""
            parent.hasSelection = false
            parent.selectedLocator = nil
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            // Manejo de errores de navegación
            print("[EPUBNavigatorWrapper] Error del navegador: \(error)")
        }
        
        func navigator(_ navigator: SelectableNavigator, shouldShowMenuForSelection selection: Selection) -> Bool {
            parent.selectedText = selection.locator.text.highlight ?? ""
            parent.hasSelection = true
            parent.selectedLocator = selection.locator
            
            // Retornamos false para ocultar el menú del sistema y mostrar el menú flotante propio de Lectoria
            return false
        }
    }
}
