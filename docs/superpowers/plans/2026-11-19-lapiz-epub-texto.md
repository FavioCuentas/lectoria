# Pencil en EPUB y texto — plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** Marcador y Borrador del Pencil en EPUB (palabras) y texto/Markdown (párrafos completos), solo en iPad.

**Spec:** `docs/superpowers/specs/2026-11-19-lapiz-epub-texto-design.md`

## Global Constraints
- Solo iPad. El iPhone y el menú principal no cambian.
- Solo el Pencil marca. El dedo y los toques del Pencil sin arrastrar se comportan como hoy.
- Las herramientas para EPUB, TXT, Markdown y texto pegado son `[.marker, .eraser]`. Para PDF y PPTX no cambian: `[.pen, .marker, .eraser]`.
- Las opciones del Marcador en EPUB y texto muestran solo los colores, sin grosor.
- Pruebas: `xcodebuild test … -only-testing:LectoriaTests` en el iPhone `00008150-000525580A33401C`.

## Review Focus
1. Un trazo del borrador en EPUB no debe borrar destacados de otro capítulo (otro `href`). La prueba va en la Task 2.
2. En texto, el borrador solo borra los párrafos que cruza el trazo. La prueba va en la Task 2.
3. Un trazo sobre una zona sin texto no crea nada.
4. Los toques del Pencil sin arrastrar siguen pasando página en EPUB.

### Task 1: herramientas por formato
- Modify: `PencilPaletteState.swift`. `tools(for:)` devuelve `[.marker, .eraser]` para los formatos de texto. Se añade `var showsWidth: Bool`, que es verdadero en PDF y PPTX.
- Modify: `PencilPaletteView.swift`. El grosor solo se muestra si `showsWidth`.
- Tests: se actualiza `testToolsPerFormat` y se añade `testWidthOnlyForFixedLayout`.

### Task 2: lógica del trazo
- Create: `Lectoria/Features/Reader/Pencil/PencilTextMarking.swift`:
  - `static func blocks(crossedBy span: ClosedRange<CGFloat>, frames: [Int: CGRect]) -> [Int]`: los bloques cuyo marco se solapa en vertical con el trazo, ordenados.
  - `static func highlightsToErase(_ highlights: [Highlight], strokeText: String, href: String) -> [UUID]`: los del mismo `href` cuyo texto, normalizado (minúsculas y espacios), contiene el texto del trazo o está contenido en él. Un texto de trazo vacío o de menos de 2 caracteres no borra nada.
- Tests: `PencilTextMarkingTests`, con bloques cruzados, otro href, solapamiento en ambos sentidos y texto vacío.

### Task 3: reconocedor del trazo
- Create: `Lectoria/Features/Reader/Pencil/PencilStrokeGesture.swift`:
  - `final class PencilStrokeRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate`: solo acepta el Pencil, admite un solo toque y hace que los demás gestos esperen a que falle.
  - `struct PencilStrokeGesture: UIGestureRecognizerRepresentable` para SwiftUI, que devuelve el inicio, el movimiento y el final en coordenadas del espacio dado.

### Task 4: EPUB
- `EPUBNavigatorWrapper` recibe:
  - `pencilTool: PencilTool?`;
  - `onPencilMark: (Selection) -> Void`;
  - `onPencilErase: (String, String) -> Void` (texto y href).
- Añade el `PencilStrokeRecognizer` a `navigator.view`, activo solo con herramienta. En cada movimiento ejecuta JavaScript en el `WKWebView` bajo el punto: selección entre el inicio y el punto actual, ampliada a palabras. Al terminar, espera la selección de Readium (hasta 300 ms) y llama al callback que corresponda. Después limpia la selección.
- `EPUBReaderView`:
  - botón de lápiz y paleta, como en el PDF;
  - `createHighlight(from: Selection, category:)`;
  - el borrador borra con `highlightRepository.delete` y llama a `loadHighlights()`.

### Task 5: texto y Markdown
- `TextReaderView`:
  - guarda el marco de cada bloque (`onGeometryChange` en el espacio con nombre `textContent`);
  - añade `PencilStrokeGesture` al contenido, activo solo con herramienta;
  - al terminar, calcula `blocks(crossedBy:)`:
    - con el Marcador, crea un destacado por bloque (`createHighlight(category:blockIndex:text:)`) y antes borra el que ya tenga;
    - con el Borrador, borra los destacados de esos bloques;
  - botón de lápiz y paleta.
