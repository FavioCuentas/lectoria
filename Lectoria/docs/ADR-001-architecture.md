# ADR-001: Arquitectura de Lectoria iOS

**Estado:** Aceptada  
**Fecha:** 2026-07-15  
**Autores:** Equipo Lectoria

## Contexto

Lectoria es una aplicación iOS de lectura digital que debe soportar múltiples formatos (EPUB, PDF, TXT, Markdown), funcionar offline, integrar IA y escalar a iPad/macOS en el futuro.

## Decisión

Usar **Clean Architecture pragmática** con las siguientes capas:

### Capas

1. **App** — Composición, entry point, navegación raíz.
2. **Domain** — Entidades puras, protocolos de repositorios, casos de uso. Sin dependencias de frameworks.
3. **Data** — Implementaciones de repositorios, SwiftData, sistema de archivos, red.
4. **Features** — Vistas SwiftUI y ViewModels agrupados por funcionalidad.
5. **DesignSystem** — Tokens semánticos y componentes reutilizables.
6. **ReaderCore** — Abstracciones comunes de lectura, protocolo `PublicationEngine`.
7. **Engines** — Implementaciones concretas: EPUB (Readium), PDF (PDFKit), Text (nativo).
8. **Services** — Servicios transversales: Auth, AI, Subscription, Sync, Analytics.

### Principios

- **Offline-first**: SwiftData como fuente de verdad local. Backend como sincronización, no dependencia.
- **Modular por feature**: Cada feature contiene sus vistas y view models.
- **Protocol-oriented**: Los motores de lectura implementan `PublicationEngine`.
- **No sobreabstraer**: No crear abstracciones sin al menos dos implementaciones reales.
- **Swift 6 concurrency**: async/await, actores, Sendable desde el inicio.
- **Adapter pattern**: Los engines (Readium, PDFKit) se encapsulan en adaptadores para no filtrar dependencias.

### Navegación

- `TabView` con 4 tabs: Inicio, Biblioteca, Notas, Perfil.
- Onboarding condicional controlado por `@AppStorage`.
- Navegación interna por `NavigationStack` dentro de cada tab.

### Theming

- Tres temas: Light, Dark, Sepia.
- `AppTheme` enum con `@Observable` ThemeManager.
- Los colores no usan `colorScheme` del sistema para sepia; se resuelven por theme manager propio.

### Localización

- String Catalog (`.xcstrings`).
- Español como idioma base, inglés preparado.
- Todas las cadenas visibles usan `String(localized:)`.

## Consecuencias

- El código es más verboso que una app monolítica, pero más mantenible.
- Los motores de lectura se pueden reemplazar sin afectar la UI.
- La capa Domain permanece pura y testeable.
- El tema sepia requiere gestión propia fuera de `ColorScheme`.

## Alternativas consideradas

1. **MVVM simple sin capas**: Descartado por falta de separación para tests y escalabilidad.
2. **TCA (The Composable Architecture)**: Descartado por curva de aprendizaje y peso adicional innecesario en esta fase.
3. **SwiftUI puro sin UIKit**: No viable; Readium Navigator y PDFKit requieren `UIViewControllerRepresentable`.
