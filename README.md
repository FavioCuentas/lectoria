# Lectoria iOS

> Un lector personal para estudiar, investigar y trabajar con EPUB, PDF y texto.

## Descripción

Lectoria es una aplicación iOS nativa que permite importar, organizar y leer documentos EPUB, PDF, TXT y Markdown. Diseñada para estudiantes, docentes, investigadores y profesionales que necesitan una experiencia de lectura minimalista, elegante y altamente configurable.

## Requisitos

- **Xcode**: 26 o posterior
- **Swift**: 6 (language mode)
- **iOS deployment target**: 17.0
- **macOS**: para desarrollo, compatible con Xcode 26

## Configuración del proyecto

1. Abre Xcode 26.
2. Crea un nuevo proyecto iOS App:
   - Product Name: `Lectoria`
   - Team: Tu Apple Developer Team
   - Organization Identifier: `com.lectoria`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
3. Copia los archivos de este repositorio dentro del grupo `Lectoria/`.
4. Configura el deployment target a iOS 17.0.
5. Habilita Swift 6 language mode en Build Settings → Swift Compiler → Swift Language Version → Swift 6.

## Estructura

```
Lectoria/
├── App/            # Entry point, environment, navigation
├── DesignSystem/   # Tokens, components, modifiers, previews
├── Domain/         # Entities, repositories, use cases, errors
├── Data/           # Persistence, files, networking, mappers
├── ReaderCore/     # Reading abstractions, protocols, coordinator
├── Engines/        # EPUB, PDF, Text rendering engines
├── Features/       # UI por feature: Onboarding, Home, Library, etc.
├── Services/       # Auth, AI, Subscription, Sync, Analytics
├── Resources/      # Assets, localization, sample files
├── ShareExtension/ # Share Extension (futuro)
├── LectoriaTests/  # Unit & integration tests
└── LectoriaUITests/ # UI tests
```

## Arquitectura

Clean Architecture pragmática con módulos por feature. Ver [ADR-001](docs/ADR-001-architecture.md) para detalles.

## Fases de desarrollo

| Fase | Contenido | Estado |
|---|---|---|
| 0 | Preparación del proyecto | 🔧 En progreso |
| 1 | Design System y navegación | 🔧 En progreso |
| 2 | Persistencia e importación | ⏳ Pendiente |
| 3 | EPUB con Readium | ⏳ Pendiente |
| 4 | PDF con PDFKit | ⏳ Pendiente |
| 5 | Texto y Markdown | ⏳ Pendiente |
| 6 | Anotaciones | ⏳ Pendiente |
| 7 | Cuenta y backend | ⏳ Pendiente |
| 8 | StoreKit | ⏳ Pendiente |
| 9 | IA | ⏳ Pendiente |
| 10 | Sincronización | ⏳ Pendiente |
| 11 | Calidad y lanzamiento | ⏳ Pendiente |

## Licencia

Propietario. Todos los derechos reservados.
