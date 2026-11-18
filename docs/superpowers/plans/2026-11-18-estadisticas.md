# Estadísticas de lectura: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pantalla de estadísticas de lectura en Perfil → Estadísticas, con datos correctos y un espacio para la mascota de Lectoria.

**Architecture:** Primero se corrige el registro de sesiones: un id estable por sesión y guardado con upsert, para no duplicar minutos. Un calculador puro (`ReadingStatsCalculator`) convierte sesiones, publicaciones y progreso en un `ReadingStats`. `StatsView` (SwiftUI + Swift Charts) lo muestra y se abre desde la fila existente de `ProfileView`.

**Tech Stack:** Swift 6 (concurrencia estricta), SwiftUI, SwiftData, Swift Charts, Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-11-18-busqueda-global-pptx-estadisticas-design.md`, sección 4.1. Este plan cubre solo la parte 1 del orden de construcción; PowerPoint y búsqueda global tendrán su propio plan.

## Global Constraints

- iOS 18+, Swift 6 con concurrencia estricta, sin dependencias de terceros nuevas. Swift Charts está permitido.
- Interfaz en español con `String(localized:comment:)`, con el sistema de diseño existente (`AppColor`, `AppTypography`, `AppSpacing`, `AppRadius`) y legible en los temas claro, oscuro y sepia (`themeManager.currentTheme`).
- Sin gamificación invasiva: sin notificaciones, medallas ni mensajes de culpa.
- No se borra nada de la base de datos. Los duplicados antiguos se filtran al calcular.
- Disponible para todos los planes (Free y Premium).
- Compilar y probar **en el iPhone**, que debe estar desbloqueado (no hay simuladores):
  - Tests: `xcodebuild test -project Lectoria.xcodeproj -scheme Lectoria -destination "platform=iOS,id=00008150-000525580A33401C" -derivedDataPath "/Volumes/FavStudio/Developer/Xcode/DerivedData/Lectoria" -allowProvisioningUpdates -only-testing:LectoriaTests/<Suite>`. Éxito: `** TEST SUCCEEDED **`.
  - Build e instalación: ver la memoria `ios-device-build`. Éxito: `** BUILD SUCCEEDED **` y `App installed:`.
  - Los diagnósticos de SourceKit tipo "No such module" son ruido; manda el resultado de `xcodebuild`.
- Todos los comandos se ejecutan desde `/Users/faviocuentas/Documents/Projects/Lectoria IA/Lectoria/Lectoria`.

## Review Focus

1. **Sesión que cruza la medianoche** (23:50 → 00:20): cuenta entera en el día en que empezó y no crea un día activo extra. Prueba en la Tarea 2.
2. **Duplicados antiguos de checkpoints** (mismo documento, mismo `startedAt`, segundos crecientes): solo cuenta el de más segundos. Prueba en la Tarea 2.
3. **Usuario sin ninguna sesión:** todos los números en 0, gráfico con 7 barras en 0, mensaje "sin datos", sin fallos. Prueba en la Tarea 2.
4. **Semana que empieza en domingo o en lunes** (`firstWeekday` 1 o 2): los minutos de la semana cambian según el calendario del usuario. Prueba en la Tarea 2.
5. **Racha cuando hoy aún no se leyó:** termina ayer y no se rompe. Prueba en la Tarea 2.

---

### Task 1: Sesiones sin duplicados (id estable + upsert + porcentajes)

**Files:**
- Modify: `Lectoria/Services/Analytics/ReadingSessionCoordinator.swift`
- Modify: `Lectoria/Data/Repositories/SwiftDataRepositories.swift` (`SwiftDataReadingSessionRepository.save`, cerca de la línea 363)
- Modify: `Lectoria/Features/Reader/PDFReaderView.swift:867`, `EPUBReaderView.swift:754`, `TextReaderView.swift:975` (pasar el proveedor de progreso)
- Test: `LectoriaTests/DomainTests/ReadingSessionCoordinatorTests.swift` (el `MockReadingSessionRepository` pasa a hacer upsert por `id`)
- Test: `LectoriaTests/DomainTests/ReadingSessionRepositoryTests.swift` (nuevo)

**Interfaces:**
- Produces:
  - `ReadingSessionCoordinator.init(publicationID:format:analyticsService:readingSessionRepository:progressProvider: (@MainActor () -> Double?)? = nil, nowProvider:)`.
  - `public let sessionID: UUID` (se genera en el `init`).
  - `ReadingSessionRepository.save(_:)`, ahora con semántica de upsert por `id`. El protocolo no cambia.

- [ ] **Step 1: Write the failing tests**

En `ReadingSessionCoordinatorTests`:
- Cambiar `MockReadingSessionRepository.save` para que reemplace por `id` si ya existe y agregue si no.
- `testCheckpointsAndEndShareOneSessionID`: iniciar la sesión, `handleScenePhaseChange(.background)`, `.active`, `.background`, `endSession()`, y esperar a que terminen los `Task`. Ver con `try await Task.sleep(for: .milliseconds(100))` cómo lo hace el test existente de la línea 146.
  - `#expect(Set(mockRepo.savedSessions.map(\.id)).count == 1)`
  - `#expect(mockRepo.savedSessions.first?.id == coordinator.sessionID)`
- `testProgressProviderRecordsStartAndEndPercentage`: proveedor que devuelve `0.2` al iniciar y `0.5` después (variable capturada que se cambia antes de `endSession()`).
  - `#expect(saved.startPercentage == 0.2)`
  - `#expect(saved.endPercentage == 0.5)`
- `testNilProgressProviderKeepsZero`: sin proveedor, `startPercentage == 0` y `endPercentage == 0`.

En el nuevo `ReadingSessionRepositoryTests` (`@MainActor`, contenedor `ModelContainerFactory.create(isStoredInMemoryOnly: true)`):
- `testSaveSameIDTwiceUpdatesInsteadOfDuplicating`: guardar una sesión con `activeSeconds: 30` y luego la misma `id` con `activeSeconds: 90` y `endPercentage: 0.4`.
  - `fetchAll().count == 1`
  - `activeSeconds == 90`
  - `endPercentage == 0.4`

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test … -only-testing:LectoriaTests/ReadingSessionCoordinatorTests -only-testing:LectoriaTests/ReadingSessionRepositoryTests`
Expected: FAIL. `sessionID` no existe, y el repositorio devuelve 2 sesiones.

- [ ] **Step 3: Implement**

- En el coordinador:
  - `sessionID = UUID()` en el `init`.
  - `checkpoint` y `endSession` usan `id: sessionID`.
  - `startPercentage` se lee una vez en `startSession()` con `progressProvider?() ?? 0`.
  - `endPercentage` se lee en cada guardado con `progressProvider?() ?? startPercentage`.
- En el repositorio: buscar con `FetchDescriptor<ReadingSessionModel>(predicate: #Predicate { $0.id == id })`. Si existe, actualizar `endedAt`, `activeSeconds`, `startPercentage` y `endPercentage`; si no, el comportamiento actual (insertar y relacionar con la publicación). Luego `context.save()`.

- [ ] **Step 4: Pass the progress provider from the readers**

En cada lector, pasar `progressProvider:` con un closure que devuelva el porcentaje que ese lector ya calcula al guardar `ReadingProgress`:
- PDF: el mismo cálculo de `saveReadingProgress`, línea 1489 (`pageIndex / (total - 1)`), a partir de la página actual.
- EPUB y Texto: su porcentaje de progreso actual.

`PresentationReaderView` queda sin proveedor por ahora (el plan de PowerPoint lo agrega).

- [ ] **Step 5: Run tests to verify they pass, then build**

Run: los tests del Step 2 y luego el build de la app para el dispositivo.
Expected: `** TEST SUCCEEDED **` y `** BUILD SUCCEEDED **`. Los demás tests de `ReadingSessionCoordinatorTests` siguen en verde.

- [ ] **Step 6: Commit**

```bash
git add Lectoria/Services/Analytics/ReadingSessionCoordinator.swift Lectoria/Data/Repositories/SwiftDataRepositories.swift Lectoria/Features/Reader/PDFReaderView.swift Lectoria/Features/Reader/EPUBReaderView.swift Lectoria/Features/Reader/TextReaderView.swift LectoriaTests/DomainTests/ReadingSessionCoordinatorTests.swift LectoriaTests/DomainTests/ReadingSessionRepositoryTests.swift
git commit -m "fix(sessions): keep one record per reading session and store progress"
```

---

### Task 2: `ReadingStatsCalculator` (cálculo puro)

**Files:**
- Create: `Lectoria/Domain/Stats/ReadingStats.swift`
- Create: `Lectoria/Domain/Stats/ReadingStatsCalculator.swift`
- Test: `LectoriaTests/DomainTests/ReadingStatsCalculatorTests.swift`

**Interfaces:**
- Consumes: `ReadingSession`, `PublicationRecord` (`id`, `title`, `finishedAt`).
- Produces:

```swift
struct DayMinutes: Equatable, Identifiable, Sendable { let date: Date /* inicio del día */; let minutes: Int; var id: Date { date } }
struct TopPublication: Equatable, Identifiable, Sendable { let id: UUID; let title: String; let minutes: Int }
struct ReadingStats: Equatable, Sendable {
    var weekMinutes: Int
    var weeklyGoalMinutes: Int
    var last7Days: [DayMinutes]      // 7 elementos, del más antiguo a hoy
    var currentStreak: Int
    var activeDaysThisMonth: Int
    var totalMinutes: Int
    var startedCount: Int
    var finishedCount: Int
    var topPublications: [TopPublication] // máx. 3, de más a menos minutos
    var hasReadToday: Bool
    var hasAnyData: Bool             // hay al menos una sesión con activeSeconds > 0
}
enum ReadingStatsCalculator {
    static let activeDayThresholdSeconds = 60
    static let finishedThreshold = 0.98
    static func dedupe(_ sessions: [ReadingSession]) -> [ReadingSession]
    static func compute(sessions: [ReadingSession], publications: [PublicationRecord],
                        progressByPublication: [UUID: Double], weeklyGoalMinutes: Int,
                        now: Date, calendar: Calendar) -> ReadingStats
    static func mascotMessage(for stats: ReadingStats) -> String
}
```

Reglas (de la sección 4.1.3 del spec):
- `compute` llama a `dedupe` primero. `dedupe` agrupa por `(publicationID, startedAt)` y se queda con la de mayor `activeSeconds`.
- **Minutos de un día:** `floor(segundos del día / 60)`, donde cada sesión cuenta entera en el día de su `startedAt`. **Total:** `floor(suma total de segundos / 60)`.
- **Semana:** `calendar.dateInterval(of: .weekOfYear, for: now)`.
- **Racha:** días consecutivos con al menos 60 s, contando desde hoy, o desde ayer si hoy no llega a 60 s.
- **Iniciados:** publicaciones con alguna sesión o con progreso mayor que 0. **Terminados:** `finishedAt != nil` o progreso mayor o igual a 0.98.
- **Más leídos:** solo `publicationID` presentes en `publications`; título tomado del `PublicationRecord`.
- **Mensajes de la mascota** (copia exacta):
  - sin datos: `"Tus estadísticas aparecerán cuando empieces a leer"`
  - racha de 1: `"Llevas 1 día seguido leyendo"`
  - racha de N > 1: `"Llevas N días seguidos leyendo"`
  - con datos y racha 0: `"¿Leemos un rato hoy?"`

- [ ] **Step 1: Write the failing tests**

Datos fijos para las pruebas:
- Calendario gregoriano con `TimeZone(identifier: "America/La_Paz")` y `firstWeekday = 2`.
- `now = 2026-11-18 15:00` (miércoles).
- Helper `session(pub:, start: "yyyy-MM-dd HH:mm", seconds:)`.

Tests:
- `testEmptyInputGivesZerosAndSevenEmptyDays`: `last7Days.count == 7`, todos en 0, `totalMinutes == 0`, `currentStreak == 0`, `hasAnyData == false`, y el mensaje es el de "sin datos".
- `testDedupeKeepsLongestCheckpoint`: 3 sesiones del mismo documento y mismo `startedAt` con 120, 300 y 600 s → `totalMinutes == 10`.
- `testSessionCrossingMidnightCountsOnStartDay`: inicio `2026-11-17 23:50` con 1800 s → el día 17 tiene 30 min y el 18 tiene 0.
- `testStreakEndsYesterdayWhenNoReadingToday`: 16 y 17 con 120 s cada uno y nada el 18 → `currentStreak == 2`, `hasReadToday == false`.
- `testStreakCountsTodayAndIgnoresUnder60Seconds`: 16 (120 s), 17 (59 s), 18 (120 s) → `currentStreak == 1`.
- `testWeekStartsOnCalendarFirstWeekday`: sesión el domingo 2026-11-15 (600 s). Con `firstWeekday = 2`, `weekMinutes == 0`; con `firstWeekday = 1`, `weekMinutes == 10`.
- `testActiveDaysThisMonthExcludesOtherMonths`: días activos el 2026-10-31 y el 2026-11-02 → `activeDaysThisMonth == 1`.
- `testStartedAndFinishedCounts`:
  - A: con sesión y progreso 0.5 → iniciado.
  - B: sin sesión y progreso 0.99 → iniciado y terminado.
  - C: `finishedAt` asignado y sin progreso → terminado, no iniciado.
  - D: nada.
  - Resultado: `startedCount == 2`, `finishedCount == 2`.
- `testTopPublicationsMaxThreeSortedAndSkipsDeleted`: 4 publicaciones y una sesión de un `publicationID` desconocido → 3 elementos ordenados de más a menos y sin el desconocido.
- `testMascotMessages`: racha de 1, racha de 3, y con datos pero racha 0, comparando con la copia exacta.

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test … -only-testing:LectoriaTests/ReadingStatsCalculatorTests`
Expected: FAIL. Los tipos no existen.

- [ ] **Step 3: Implement both files** following the rules above. Usar `calendar.startOfDay(for:)` y `calendar.date(byAdding: .day, …)` para los 7 días y la racha.

- [ ] **Step 4: Run tests to verify they pass**

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Lectoria/Domain/Stats LectoriaTests/DomainTests/ReadingStatsCalculatorTests.swift
git commit -m "feat(stats): add reading stats calculator"
```

---

### Task 3: Pantalla de estadísticas + espacio de la mascota + entrada desde Perfil

**Files:**
- Create: `Lectoria/Features/Profile/StatsView.swift`
- Create: `Lectoria/Features/Profile/MascotSlotView.swift`
- Create: `Lectoria/Assets.xcassets/statsMascot.imageset/Contents.json` (image set vacío: `{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}`)
- Modify: `Lectoria/Features/Profile/ProfileView.swift:166-169` (la fila "Estadísticas" navega a `StatsView`)

**Interfaces:**
- Consumes: `ReadingStatsCalculator.compute`, `ReadingStatsCalculator.mascotMessage`, y de `AppDependencies`: `readingSessionRepository.fetchAll()`, `publicationRepository.fetchAll()` y `readingProgressRepository.fetchProgress(forPublication:)` (una llamada por publicación).
- Produces:
  - `struct StatsView: View` (sin parámetros; lee el entorno).
  - `struct MascotSlotView: View { let message: String; let theme: AppTheme }`.

- [ ] **Step 1: `MascotSlotView`**

Tarjeta con imagen y mensaje:
- Si `UIImage(named: "statsMascot") != nil`, muestra `Image("statsMascot").resizable().scaledToFit()` con `maxHeight: 160`.
- Si no, muestra un marco con `RoundedRectangle(cornerRadius: AppRadius.md).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))`, el ícono `photo.on.rectangle.angled` y el texto `"Espacio para la mascota de Lectoria"`.
- Debajo, `message` en `AppTypography.body`.
- `accessibilityElement(children: .combine)`.

- [ ] **Step 2: `StatsView`**

- Carga en `.task`: obtiene sesiones, publicaciones y progresos y llama a `compute` con `now: Date()` y `calendar: .current`.
- `@AppStorage("weeklyReadingGoalMinutes") var goal = 120`. Se recalcula al cambiar `goal` (no hace falta volver a leer de la base).
- Muestra un `ProgressView` mientras carga.
- Secciones en este orden:
  1. `MascotSlotView`.
  2. Meta semanal: barra `weekMinutes / goal` con el texto `"\(weekMinutes) / \(goal) min"` y un `Stepper` de 15 en 15, en el rango `15...1500`.
  3. Gráfico de los últimos 7 días: `Chart` con `BarMark` (x = día abreviado, y = minutos). La barra de hoy en `AppColor.accent` y el resto con opacidad 0.45.
  4. Cuadrícula de tarjetas: racha, días activos (mes), total (formato `"X h Y min"`, o `"Y min"` si son menos de 60), iniciados y terminados.
  5. "Más leídos": hasta 3 filas solo informativas, con título y minutos. Se oculta si está vacío.
- Título de navegación: `"Estadísticas"`.

- [ ] **Step 3: Conectar Perfil**

En `ProfileView`:
- Agregar `@State private var showStats = false`.
- La acción de la fila "Estadísticas" hace `showStats = true`.
- Agregar `.navigationDestination(isPresented: $showStats) { StatsView() }`. `ProfileView` ya está dentro de un `NavigationStack` en `RootView`.

- [ ] **Step 4: Build and install on the iPhone**

Expected: `** BUILD SUCCEEDED **` y `App installed:`.

- [ ] **Step 5: Manual check on device (with the user)**

- Perfil → Estadísticas abre la pantalla.
- Sin imagen, se ve el marco punteado.
- Los números coinciden con una lectura de prueba: leer 2 o más minutos, salir y volver.
- La meta se edita y se conserva al volver a entrar.
- Se ve bien en los temas claro, oscuro y sepia.

- [ ] **Step 6: Commit**

```bash
git add Lectoria/Features/Profile/StatsView.swift Lectoria/Features/Profile/MascotSlotView.swift Lectoria/Assets.xcassets/statsMascot.imageset Lectoria/Features/Profile/ProfileView.swift
git commit -m "feat(stats): add reading statistics screen with mascot slot"
```
