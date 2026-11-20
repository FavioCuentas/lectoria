# iPad Pencil — entrega 1 (PDF y presentaciones): plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** En el iPad, dentro del lector PDF (y por tanto de las presentaciones), un botón de lápiz muestra una paleta propia con estas herramientas:
- **Texto:** resaltador que crea destacados normales.
- **Pluma** y **Marcador:** trazo libre con PencilKit, guardado por página.
- **Borrador.**

**Architecture:**
- **Lógica pura y probada:**
  - `PencilPaletteState`: herramientas por formato, colores, grosor y persistencia.
  - `InkStore`: trazos por documento y página en disco.
  - `PencilTextSelection`: del trazo a una `PDFSelection`.
- **`PDFNavigatorWrapper`** recibe el estado de la paleta y añade dos cosas:
  - un gesto de arrastre solo para el Pencil, que maneja la herramienta Texto;
  - un `PDFPageOverlayViewProvider` con un `PKCanvasView` por página, que maneja la Pluma, el Marcador y el Borrador.
- **`PDFReaderView`** muestra el botón y la paleta, y crea el destacado.

**Tech Stack:** Swift 6 (concurrencia estricta), SwiftUI, PDFKit, PencilKit, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-19-ipad-lapiz-design.md`

## Global Constraints

- **El iPhone no cambia nada.** El botón y la paleta solo existen si `UIDevice.current.userInterfaceIdiom == .pad`. El menú de abajo (Inicio, Biblioteca, Notas y Perfil) no se toca.
- **Solo el Pencil marca:**
  - el gesto de Texto usa `allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]`;
  - los lienzos usan `drawingPolicy = .pencilOnly`;
  - el dedo sigue desplazando, pasando páginas y seleccionando.
- **Con la paleta oculta no hay gesto de Pencil ni lienzo interactivo.** `isInMarkupMode` es `false` y el Pencil se comporta como hoy.
- **Herramientas** (`enum PencilTool: String { case text, pen, marker, eraser }`):
  - en `.pdf` y `.pptx`: las cuatro;
  - en `.epub`, `.txt`, `.markdown` y `.pastedText`: solo `.text`.
- **Colores:**
  - Texto y Marcador: las 5 categorías de `HighlightCategory.userSelectableCases`, con los mismos tonos que `PDFNavigatorWrapper.highlightColor(for:)`;
  - Pluma: esas 5 más negro.
  - El Marcador usa alfa 0.35. La Pluma es opaca.
- **Grosores** (`enum PencilWidth: Int { case thin, medium, thick }`):
  - Pluma: 2, 4 y 7 pt;
  - Marcador: 12, 20 y 30 pt.
- **Preferencias** en `UserDefaults`: `pencil.tool`, `pencil.category`, `pencil.penColor` y `pencil.width`.
- **Trazos** en `Application Support/Ink/<publicationID>.json`:
  - formato JSON `{ "<pageIndex>": "<base64 de PKDrawing.dataRepresentation()>" }`;
  - se borran al borrar el documento.
- **Texto exacto de la interfaz:**
  - el botón tiene la etiqueta de accesibilidad "Lápiz";
  - la paleta tiene "Texto", "Pluma", "Marcador", "Borrador" y "Cerrar".
- **Pruebas:** `xcodebuild test -project Lectoria.xcodeproj -scheme Lectoria -destination "platform=iOS,id=00008150-000525580A33401C" -derivedDataPath "/Volumes/FavStudio/Developer/Xcode/DerivedData/Lectoria" -allowProvisioningUpdates -only-testing:LectoriaTests`
- **Revisión con el lápiz** en el iPad `00008112-0019701C212A201E`.

## Review Focus

1. **Trazo de Texto que empieza o termina fuera del texto** (en el margen): se debe seleccionar el texto que cruza, sin crear nada si no toca texto. La prueba va en la Task 3.
2. **Trazo de Texto que cruza dos páginas** en modo continuo: el destacado se crea solo en la página donde empezó el trazo, recortado a esa página. La prueba va en la Task 3.
3. **Zoom y giro** con trazos guardados: los trazos siguen en su sitio.
4. **Archivo de trazos corrupto o ilegible:** el documento abre sin trazos y no falla. La prueba va en la Task 2.
5. **Cambiar de herramienta mientras se dibuja, u ocultar la paleta:** el trazo en curso se guarda y no queda ningún lienzo interactivo.

---

### Task 1: Estado de la paleta

**Files:**
- Create: `Lectoria/Features/Reader/Pencil/PencilPaletteState.swift`
- Test: `LectoriaTests/PencilPaletteStateTests.swift`

**Interfaces:**
- Produces:
  - `enum PencilTool: String, CaseIterable { case text, pen, marker, eraser }`
  - `enum PencilWidth: Int, CaseIterable { case thin, medium, thick }`
  - `enum PencilPenColor: Equatable { case category(HighlightCategory), black }`
  - `@MainActor @Observable final class PencilPaletteState`, con:
    - `init(publicationType: PublicationType, defaults: UserDefaults = .standard)`;
    - `availableTools: [PencilTool]`;
    - `var tool: PencilTool`, `var category: HighlightCategory`, `var penColor: PencilPenColor` y `var width: PencilWidth`, que se guardan en cada cambio;
    - `func strokeWidth() -> CGFloat`, que devuelve el grosor en pt de la herramienta actual (0 para Texto y Borrador);
    - `func inkColor() -> UIColor`, que devuelve el color del trazo con su alfa.

- [ ] **Step 1: Escribir pruebas que fallen**
  - `testToolsPerFormat`: en PDF y PPTX las 4 herramientas; en EPUB y TXT solo `[.text]`.
  - `testDefaults`: valores iniciales `.text`, `.mainIdea`, `.category(.mainIdea)` y `.medium`.
  - `testPersistsAcrossInstances`: cambiar a `.pen` con `.black` y `.thick` y crear un nuevo estado con los mismos defaults recupera esos valores.
  - `testUnavailableSavedToolFallsBackToText`: con `.pen` guardado, un estado EPUB arranca en `.text`.
  - `testStrokeWidths`: Pluma medium → 4 y Marcador thick → 30.
  - `testMarkerColorIsTranslucent`: el alfa de `inkColor()` del Marcador es 0.35 y el de la Pluma es 1.
- [ ] **Step 2:** Correr. Expected: no compila.
- [ ] **Step 3:** Implementar.
- [ ] **Step 4:** Correr la suite. Expected: verde.
- [ ] **Step 5:** Commit `Lápiz: estado de la paleta`.

### Task 2: Guardado de trazos

**Files:**
- Create: `Lectoria/Services/Ink/InkStore.swift`
- Modify: `Lectoria/DesignSystem/Components/PublicationCard.swift`
- Modify: `Lectoria/Features/Home/HomeView.swift`
- Test: `LectoriaTests/InkStoreTests.swift`

En los dos archivos que se modifican, cada flujo "Borrar libro" llama a `InkStore.shared.delete(publicationID:)`.

**Interfaces:**
- Produces: `actor InkStore`, con:
  - `static let shared`;
  - `init(directory: URL)`;
  - `func drawings(for publicationID: UUID) -> [Int: Data]`;
  - `func save(_ data: Data?, page: Int, publicationID: UUID) throws`, donde `nil` o vacío borra esa página;
  - `func delete(publicationID: UUID)`.

- [ ] **Step 1: Escribir pruebas que fallen**
  - `testRoundTripPerPage`: guardar las páginas 0 y 3 y leer exactamente esas dos.
  - `testNilRemovesPage`.
  - `testDeleteRemovesFile`.
  - `testCorruptFileReturnsEmpty`: escribir basura en el archivo da `[:]`.
  - `testDocumentsAreIsolated`.
- [ ] **Step 2:** Correr. Expected: no compila.
- [ ] **Step 3:** Implementar con escritura atómica. Integrar el borrado en los dos flujos.
- [ ] **Step 4:** Correr la suite. Expected: verde.
- [ ] **Step 5:** Commit `Lápiz: guardado de trazos por página`.

### Task 3: Del trazo a la selección de texto

**Files:**
- Create: `Lectoria/ReaderCore/Engines/PDF/PencilTextSelection.swift`
- Test: `LectoriaTests/PencilTextSelectionTests.swift`. Genera en la prueba un PDF de una página con `UIGraphicsPDFRenderer` que dibuja "Llamadme Ismael" en una línea conocida y otro texto en una segunda línea.

**Interfaces:**
- Produces: `enum PencilTextSelection { static func selection(on page: PDFPage, from start: CGPoint, to end: CGPoint) -> PDFSelection? }`.
  - Los puntos están en coordenadas de página. Si están fuera del texto se proyectan a la línea más cercana dentro de los límites del texto.
  - Devuelve `nil` si la selección queda vacía o solo con espacios.
  - Recorta a esa página.

- [ ] **Step 1: Escribir pruebas que fallen**
  - `testStrokeOverLineSelectsIt`: de un extremo a otro de la línea, el texto es "Llamadme Ismael".
  - `testStrokeStartingInMarginSelectsLine`: empezar 30 pt a la izquierda del texto da el mismo resultado.
  - `testStrokeOnEmptyAreaReturnsNil`: un trazo en zona sin texto da `nil`.
  - `testPartialStrokeSelectsPartOfLine`: un trazo sobre "Ismael" contiene "Ismael" y no "Llamadme".
- [ ] **Step 2:** Correr. Expected: no compila.
- [ ] **Step 3:** Implementar con `page.selection(from:to:)`, más el ajuste de puntos al contenido y la comprobación de texto vacío.
- [ ] **Step 4:** Correr la suite. Expected: verde.
- [ ] **Step 5:** Commit `Lápiz: selección de texto desde el trazo`.

### Task 4: Paleta y botón

**Files:**
- Create: `Lectoria/Features/Reader/Pencil/PencilPaletteView.swift`

**Interfaces:**
- Consumes: `PencilPaletteState` (Task 1).
- Produces:
  - `struct PencilPaletteView: View { init(state: PencilPaletteState, theme: AppTheme, onClose: () -> Void) }`:
    - cápsula flotante;
    - fila de herramientas (solo `availableTools`, cada una con ícono y nombre);
    - fila de colores: categorías para Texto y Marcador, más negro para la Pluma;
    - fila de 3 grosores solo para Pluma y Marcador;
    - botón "Cerrar";
    - la selección actual se marca con el acento.
  - `struct PencilModeButton: View { @Binding var isOn: Bool; let theme: AppTheme }`:
    - solo en iPad;
    - ícono `pencil.tip.crop.circle`;
    - acento cuando está activo;
    - etiqueta "Lápiz".

- [ ] **Step 1:** Implementar. Es solo interfaz; la lógica está probada en la Task 1.
- [ ] **Step 2:** Compilar. Expected: `BUILD SUCCEEDED` sin avisos nuevos.
- [ ] **Step 3:** Commit `Lápiz: paleta y botón`.

### Task 5: Resaltador de texto en el lector PDF

**Files:**
- Modify: `Lectoria/ReaderCore/Engines/PDF/PDFNavigatorWrapper.swift`
- Modify: `Lectoria/Features/Reader/PDFReaderView.swift`

**Interfaces:**
- Consumes: `PencilTextSelection` (Task 3), `PencilPaletteState`, `PencilPaletteView` y `PencilModeButton` (Tasks 1 y 4).
- Produces: dos parámetros nuevos del wrapper:
  - `pencilTool: PencilTool?`, que es `nil` con la paleta oculta;
  - `onPencilTextStroke: ((PDFSelection) -> Void)?`.

En el wrapper:
- Un `UIPanGestureRecognizer` solo para el Pencil, activo cuando `pencilTool == .text`.
- **Al empezar:** guarda la página y el punto, convertidos con `pdfView.page(for:nearest:)` y `convert(_:to:)`.
- **Al moverse:** calcula `PencilTextSelection` y la muestra como `pdfView.currentSelection`. Esa es la sombra provisional.
- **Al terminar:** si hay selección, llama a `onPencilTextStroke` y limpia la selección.

En `PDFReaderView`:
- `@State var pencilMode = false` y `@State var palette = PencilPaletteState(publicationType: record.publicationType)`.
- `PencilModeButton` en la barra superior, junto a los botones actuales.
- `PencilPaletteView` abajo al centro cuando `pencilMode` está activo. Mientras lo está, la interfaz no se oculta al tocar.
- Nueva función `createHighlight(from selection: PDFSelection, category:)`, que extrae lo común de `createHighlight(category:)`: anchor con `pageIndex` y `selectionBounds`, texto, color de la categoría y `loadHighlights()`.

- [ ] **Step 1:** Implementar y compilar para el iPad. Expected: `BUILD SUCCEEDED`.
- [ ] **Step 2:** Correr la suite en el iPhone. Expected: verde.
- [ ] **Step 3:** Commit `Lápiz: resaltador de texto en PDF`.

### Task 6: Pluma, marcador y borrador en el lector PDF

**Files:**
- Create: `Lectoria/ReaderCore/Engines/PDF/InkOverlayProvider.swift`
- Modify: `Lectoria/ReaderCore/Engines/PDF/PDFNavigatorWrapper.swift`

**Interfaces:**
- Consumes: `InkStore` (Task 2) y `PencilPaletteState` (Task 1).
- Produces: `@MainActor final class InkOverlayProvider: NSObject, PDFPageOverlayViewProvider, PKCanvasViewDelegate`, con:
  - `init(publicationID: UUID, document: PDFDocument, store: InkStore)`;
  - `func apply(tool: PencilTool?, color: UIColor, width: CGFloat)`;
  - `func loadDrawings() async`.

Comportamiento:
- **Un `PKCanvasView` transparente por página visible:**
  - `drawingPolicy = .pencilOnly`;
  - interactivo solo con Pluma, Marcador o Borrador;
  - `PKInkingTool(.pen)`, `PKInkingTool(.marker)` o `PKEraserTool(.vector)`.
- **Al cargar:** se cargan los dibujos guardados.
- **Al cambiar:** se guarda con 0,5 s de espera.
- **Al terminar** (`overlayViewDidDisappear`, cambio de herramienta u ocultar la paleta): se guarda de inmediato.
- `pdfView.isInMarkupMode` es `true` solo con Pluma, Marcador o Borrador.
- El wrapper recibe `publicationID` y el color y grosor actuales.
- Los dibujos se muestran también con la paleta oculta, pero no son interactivos.

- [ ] **Step 1:** Implementar y compilar para el iPad. Expected: `BUILD SUCCEEDED`.
- [ ] **Step 2:** Correr la suite en el iPhone. Expected: verde.
- [ ] **Step 3:** Instalar en el iPad para la revisión con el lápiz (Review Focus 3 y 5).
- [ ] **Step 4:** Commit `Lápiz: pluma, marcador y borrador en PDF`.
