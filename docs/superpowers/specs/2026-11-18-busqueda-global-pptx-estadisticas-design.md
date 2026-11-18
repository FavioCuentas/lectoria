# Búsqueda global, búsqueda en PowerPoint y Estadísticas: diseño

Fecha: 2026-11-18 · Estado: borrador para aprobación

## 1. Intención y porqué

Terminar dos secciones de la especificación del producto (`Lectoria/docs/LECTORIA_PRODUCT_AND_BUILD_SPEC.md`):

- **4.11 Búsqueda.** Los tres niveles: dentro del documento, en toda la biblioteca y en notas y destacados. El nivel 1 ya existe para PDF, EPUB y texto/Markdown, pero no para PowerPoint. El nivel 2 hoy solo busca por título y autor.
- **4.12 Estadísticas.** Hoy no existen. La fila "Estadísticas" de Perfil (que hace de Ajustes) no hace nada al tocarla.

El usuario pidió las tres partes y le dio **prioridad a las estadísticas**. Pidió también un **espacio en la pantalla de estadísticas para poner una imagen o gráfica de la mascota de Lectoria**. Todo debe funcionar dentro del teléfono: la especificación prohíbe enviar contenido al servidor para buscar.

## 2. Objetivos, no-objetivos y anti-objetivos

**Objetivos**
1. Estadísticas de lectura visibles desde Perfil → Estadísticas, con números correctos.
2. Búsqueda dentro de PowerPoint con la misma experiencia que en PDF: lista de resultados, salto a la coincidencia, sombreado y barra "N de M".
3. Búsqueda global desde la Biblioteca: títulos y autores, contenido de los documentos, notas y destacados. Al tocar un resultado de contenido, el documento se abre en esa coincidencia.

**No-objetivos**
- Sincronizar estadísticas o el índice con el servidor.
- Búsqueda difusa, sinónimos o búsqueda semántica con IA.
- Conservar animaciones, transiciones o videos de PowerPoint (QuickLook tampoco los muestra hoy).
- Estadísticas por hora del día, comparativas entre usuarios o exportar estadísticas.

**Anti-objetivos** (fracaso aunque "funcione")
- **Estadísticas con números inflados o inventados.** Hoy sería el caso (ver 4.3.1). Es mejor mostrar menos datos que mostrar datos falsos.
- **Gamificación invasiva** (la especificación lo pide explícitamente): nada de notificaciones, medallas, mensajes de culpa al perder la racha ni bloqueos.
- **Un PowerPoint que se vea peor que hoy.** Si la conversión falla o queda incompleta, se abre con QuickLook como ahora.
- **Importación más lenta para el usuario.** Indexar y convertir no puede bloquear el flujo actual de "Importando documento…" más de lo que ya tarda.

## 3. Restricciones

- iOS 18+, Swift 6 con concurrencia estricta, SwiftUI, SwiftData como base local. Readium para EPUB, PDFKit para PDF.
- Sin simuladores instalados: la verificación manual se hace en el iPhone del usuario (ver la memoria del proyecto para compilar e instalar).
- Sin dependencias nuevas de terceros. `sqlite3` (incluido en el SDK) y Swift Charts (framework de Apple) están permitidos.
- Los archivos importados viven en `Application Support/Publications/<localFileName>`.
- La interfaz está en español, con `String(localized:)` como el resto de la app, y usa el sistema de diseño existente (`AppColor`, `AppTypography`, `AppSpacing`, `AppRadius`, temas claro, oscuro y sepia).

## 4. Diseño

### 4.1 Estadísticas (prioridad)

#### 4.1.1 Corregir los datos de sesiones antes de mostrarlos

Hoy `ReadingSessionCoordinator` (`Lectoria/Services/Analytics/ReadingSessionCoordinator.swift`) crea un `ReadingSession` **con un UUID nuevo** en cada `saveCheckpoint()` (al pasar a segundo plano o quedar inactiva la app) y otro más en `endSession()`. Cada uno lleva los segundos acumulados, así que una misma lectura se cuenta varias veces. Además, `startPercentage` y `endPercentage` se guardan siempre en `0.0`.

Cambios:
- El coordinador genera **un solo `id` de sesión** al iniciar y lo reutiliza en checkpoints y en el cierre.
- `SwiftDataReadingSessionRepository.save` pasa a ser un **upsert por `id`**: si existe, actualiza `endedAt`, `activeSeconds` y los porcentajes; si no, inserta.
- **Datos antiguos ya duplicados:** el cálculo de estadísticas los deduplica. Si varias sesiones del mismo documento tienen el **mismo `startedAt`**, solo cuenta la de mayor `activeSeconds`, porque son checkpoints de la misma lectura. No se borra nada de la base.
- **Porcentajes:** el coordinador acepta un proveedor opcional del progreso actual (closure `() -> Double?`). Cada lector se lo pasa a partir del progreso que ya calcula, y se guarda al iniciar y al cerrar. Si no hay dato, queda en 0 como hoy. Las estadísticas **no dependen** de estos porcentajes (ver 4.1.3); solo enriquecen el registro.

#### 4.1.2 Pantalla

Entrada: Perfil → fila "Estadísticas" (`ProfileView.swift`, hoy con acción vacía) → `NavigationLink` a `StatsView`.

```
┌──────────────────────────────────────┐
│ ‹ Perfil        Estadísticas         │
│ ┌──────────────────────────────────┐ │
│ │  [  imagen de la mascota  ]      │ │  ← espacio para la mascota
│ │  "Llevas 3 días seguidos leyendo"│ │     (mensaje amable, sin culpa)
│ └──────────────────────────────────┘ │
│  Meta semanal                        │
│  ███████████░░░░  84 / 120 min       │  ← barra/anillo + "Editar meta"
│                                      │
│  Últimos 7 días (min)                │
│  ▂ ▅ ▁ ▇ ▃ ▆ █                       │  ← Swift Charts, hoy resaltado
│  L M M J V S D                       │
│                                      │
│ ┌────────┐ ┌────────┐ ┌────────┐     │
│ │ 🔥 3   │ │ 12 días│ │ 14 h   │     │  racha · días activos (mes) · total
│ └────────┘ └────────┘ └────────┘     │
│ ┌────────┐ ┌────────┐                │
│ │ 9      │ │ 4      │                │  documentos iniciados · terminados
│ └────────┘ └────────┘                │
│  Más leídos                          │
│  1. Título A ·········· 3 h 10 min   │  ← top 3 por minutos (solo informativo)
│  2. Título B ·········· 1 h 05 min   │
└──────────────────────────────────────┘
```

**Espacio de la mascota.** Es una tarjeta arriba de todo que muestra la imagen del recurso **`statsMascot`** de `Assets.xcassets`, si existe (se comprueba con `UIImage(named:)`). Mientras no exista, muestra un marco con borde punteado, un ícono (`photo.on.rectangle.angled`) y el texto "Espacio para la mascota de Lectoria". Así el usuario solo tiene que arrastrar su imagen al recurso en Xcode. Se crea el *image set* vacío `statsMascot` para que el lugar sea evidente. La imagen se ajusta con `scaledToFit` a una altura máxima de unos 160 pt, y se aceptan PNG con transparencia o JPG. Junto a la imagen va un mensaje corto que depende del estado: con racha, "Llevas N días seguidos leyendo"; sin lectura hoy, "¿Leemos un rato hoy?"; sin datos, "Tus estadísticas aparecerán cuando empieces a leer". Ya existe `lectoriaPremiumMascot`, que usa el paywall, pero **no se reutiliza**: el usuario pidió un espacio propio.

**Estado vacío.** Si no hay sesiones, se muestra la tarjeta de la mascota con el mensaje de "sin datos", la meta en 0 y el gráfico con barras vacías. Los demás números quedan en 0 sin ocultarse.

#### 4.1.3 Definiciones de cada número

Se calculan en un tipo puro `ReadingStatsCalculator` (entrada: sesiones deduplicadas, publicaciones, progresos, `now`, `Calendar`; salida: un `ReadingStats`), para poder probarlo sin interfaz. Usa el calendario y la zona horaria del usuario. La semana empieza según `Calendar.current.firstWeekday`.

| Métrica | Definición |
|---|---|
| Minutos por día | Suma de `activeSeconds` de las sesiones cuyo `startedAt` cae en ese día, dividida entre 60 y redondeada hacia abajo. Una sesión que cruza la medianoche cuenta entera en el día en que empezó. |
| Día activo | Día con al menos **60 s** de lectura. |
| Racha actual | Días activos consecutivos que terminan **hoy**, o **ayer** si hoy aún no hay lectura, para no "romper" la racha por la mañana. |
| Días activos (mes) | Días activos del mes calendario en curso. |
| Total leído | Suma de todas las sesiones, mostrada en h y min. |
| Meta semanal | Minutos leídos en la semana en curso frente a la meta. Por defecto 120 min, editable con un `Stepper` de 15 en 15 entre 15 y 1500. Se guarda en `@AppStorage("weeklyReadingGoalMinutes")`. |
| Documentos iniciados | Publicaciones con al menos una sesión, o con progreso mayor que 0. |
| Documentos terminados | Publicaciones con `finishedAt != nil` o con progreso mayor o igual a 0.98. Hoy ningún lector asigna `finishedAt`, así que el umbral de progreso es la fuente real. |
| Más leídos | Las 3 publicaciones con más minutos totales. Se excluyen las borradas; las archivadas **sí cuentan**, porque su historial es real. Las filas son **solo informativas**: no abren el documento desde Perfil, para no agregar navegación al lector desde ahí ni la alerta de archivado. *(Decisión del constructor.)* |

No hay límite para sesiones "olvidadas" (por ejemplo, la app abierta con "Pantalla activa al leer"): queda como limitación conocida, no se corrige ahora.

#### 4.1.4 Acceso

Es para todos los planes (Free y Premium); la especificación no la restringe.

### 4.2 Búsqueda dentro de PowerPoint (convertir a PDF)

**Validado con una prueba previa** en el iPhone, usando dos presentaciones del usuario:
- `WKWebView` abre el `.pptx` con el motor de QuickLook de WebKit, que genera HTML con un `div.slide` de 960×540 por diapositiva, con texto real e imágenes.
- `webView.pdf(configuration:)`, con `rect` igual al rectángulo de cada `div.slide`, genera una página PDF por diapositiva con texto buscable.
- La fidelidad es igual a la de QuickLook actual.

**Detalles aprendidos en la prueba:**
- Las diapositivas se cargan **de forma perezosa**.
- Siempre queda **un `div.loading-slide` sobrante** que nunca desaparece, así que no sirve como señal de que terminó la carga.
- La señal correcta es: la cantidad de `div.slide` **igual** al número de diapositivas que reporta `PPTXParser`, más una pausa breve de estabilización. Mientras falten, se hace scroll al último `div.slide` o al `loading-slide` para forzar la carga.
- Hay que fijar un tiempo máximo (unos 30 s).
- La vista web debe estar dentro de una `UIWindow` (aunque no sea visible) para que pinte.

**Flujo:**
1. Nuevo servicio `PresentationPDFConverter` (en `@MainActor`, porque usa WebKit). Recibe la URL del `.pptx` y el número esperado de diapositivas, y escribe `Publications/<localFileName>.rendered.pdf` junto al original. El original **no se borra**: sirve para "abrir original" y para exportar.
2. **Al importar** un PPTX: después de guardar el registro, la conversión se lanza en segundo plano, sin bloquear el aviso "¡Documento importado!".
3. **Presentaciones ya importadas** o conversión pendiente: al abrir la presentación, si no existe `.rendered.pdf`, se muestra QuickLook enseguida, como hoy, y se convierte en segundo plano. **La vista no cambia mientras está abierta.** La ruta PDF se usa desde la **siguiente apertura**, para no interrumpir la lectura ni duplicar la sesión. *(Decisión del constructor.)* Excepción: si se llega desde la búsqueda global y aún no hay PDF, ver 4.3.3.
   - **El PDF se escribe una sola vez:** nunca se regenera un `.rendered.pdf` válido, porque los resaltados hechos sobre él dependen de posiciones en la página. Solo se vuelve a generar si falta o si `PDFDocument` no lo puede abrir, y en ese caso los resaltados de esa presentación pueden quedar desplazados (limitación aceptada). *(Decisión del constructor.)*
   - **Progreso:** en la ruta PDF, la presentación **guarda `ReadingProgress`** (diapositiva actual dividida entre el total) como los demás lectores, y lo usa para reanudar. Así una presentación puede contar como "terminada" en las estadísticas. QuickLook no informa la diapositiva, así que en ese modo no se guarda progreso (limitación aceptada). *(Decisión del constructor.)*
4. **Si falla** (tiempo agotado, número de diapositivas distinto o PDF vacío): no se guarda nada, se registra el error en `os.Logger` y se sigue usando QuickLook. Se reintenta en la siguiente apertura, como máximo una vez por sesión de app.
5. `PresentationReaderView` ya tiene la ruta PDF (`PDFPresentationPreviewWrapper`, con resaltado, notas y miniaturas), que hoy solo se usa cuando el archivo es `.pdf`. Ahora también se usa cuando existe `.rendered.pdf`.
6. Se agrega búsqueda a la ruta PDF de `PresentationReaderView`, reutilizando `PDFTextSearch` y `ReaderSearchNavigatorBar`, con el mismo patrón que `PDFReaderView`: lupa, hoja de resultados con "Diapositiva N", salto al cerrar la hoja y barra "N de M". El texto del resumen es "N coincidencias en M diapositivas".
7. Las **notas del presentador** no están en el PDF. La búsqueda también las recorre con el `PresentationSearchEngine` ya existente (hoy sin conectar) y las muestra en una sección aparte, "En notas del presentador". Tocar uno de esos resultados lleva a la diapositiva y abre el panel de notas existente, sin sombreado.

**Anotaciones existentes** hechas en modo QuickLook: QuickLook solo permite notas generales o por diapositiva (por índice), y esos índices coinciden con las páginas del PDF, así que siguen siendo válidos.

### 4.3 Búsqueda global en la biblioteca

#### 4.3.1 Índice de contenido

- Base SQLite **separada**, en `Application Support/SearchIndex.sqlite`, con una tabla virtual **FTS5**:
  `CREATE VIRTUAL TABLE chunks USING fts5(publication_id UNINDEXED, locator UNINDEXED, label UNINDEXED, text, tokenize='unicode61 remove_diacritics 2');`
  Así la búsqueda ignora mayúsculas y acentos y es rápida con muchos libros. No toca el esquema de SwiftData.
- Un tipo `SearchIndexStore` (un `actor`) se encarga de abrir y crear la tabla, `replace(publicationID:, chunks:)`, `delete(publicationID:)` y `search(query:, limit:)`. Este último devuelve hasta 5 fragmentos por documento con `snippet()` de FTS5 (contexto de unas 12 palabras) y el total de coincidencias por documento.
- La consulta del usuario se escapa: cada palabra va entre comillas y la última admite prefijo (`"pala"*`). Los caracteres especiales de FTS5 nunca rompen la consulta.
- **Fragmentos por formato** (`ContentChunker`):
  - **PDF:** un fragmento por página (`PDFPage.string`), con `locator = número de página` y `label = "Página N"`.
  - **EPUB:** un fragmento por recurso o capítulo del *reading order*, extrayendo el texto del XHTML de Readium. `locator = href` y `label =` título del capítulo según la tabla de contenidos (o "Capítulo N"). Un capítulo muy largo se divide en trozos de unos 4.000 caracteres con el mismo `locator`.
  - **TXT / Markdown / texto pegado:** trozos de unos 4.000 caracteres a partir de los `TextBlock`, con `locator =` índice del primer bloque.
  - **PPTX:** un fragmento por diapositiva desde `PPTXParser` (título, cuerpo y notas), con `locator = índice de diapositiva` y `label = "Diapositiva N"`. Así funciona aunque la conversión a PDF no haya terminado.
- **Ciclo de vida:**
  - Tras importar, se indexa en segundo plano y se actualiza `indexingStatus` (`pending` → `indexing` → `completed` o `failed`), un campo que ya existe.
  - Al arrancar la app, una tarea de baja prioridad indexa todo lo que esté en `pending` o `failed`. Los documentos ya importados quedan en `pending` porque nunca se indexaron.
  - Al borrar una publicación, se borran sus fragmentos.
  - El índice se puede reconstruir siempre desde los archivos. Si la base está corrupta, se borra y se marca todo como `pending`.

#### 4.3.2 Notas y destacados

No usan el índice: se consultan directamente en SwiftData (`NoteModel.body` y `tags`, `HighlightModel.selectedText`), con coincidencia que ignora mayúsculas y acentos (`localizedStandardContains`).

#### 4.3.3 Pantalla

Se usa el `.searchable` existente de `LibraryView`. Con el texto vacío, la biblioteca funciona como hoy. Con texto, la cuadrícula se reemplaza por una lista agrupada. La búsqueda arranca 300 ms después de dejar de escribir o al pulsar "Buscar", y se cancela si llega otra.

```
Títulos y autores        (el filtro actual, como filas)
Dentro de documentos
  📕 Título A · 12 coincidencias
     Capítulo 3 · "…la **palabra** aparece aquí…"
  📄 Título B · 3 coincidencias
     Página 14 · "…"
Notas y destacados
  ✎ "texto de la nota…" · Título A
```

- **Tocar un resultado de contenido** abre el lector con una **búsqueda inicial**: el lector recibe la consulta y la ubicación del fragmento, ejecuta su propia búsqueda dentro del documento (la que ya existe) y se coloca en la primera coincidencia **dentro de ese capítulo, página o diapositiva**, con la barra "N de M" activa. Así se reutiliza toda la búsqueda por documento en lugar de tener localizadores duplicados. Si no encuentra la coincidencia en ese lugar, va a la primera del documento.
- **PowerPoint sin PDF todavía:** si el resultado es de una presentación sin `.rendered.pdf`, el lector muestra "Preparando búsqueda…" y lanza la conversión (máximo unos 30 s). Si termina, abre en modo PDF con la búsqueda inicial. Si falla, abre en QuickLook como hoy y avisa: "Esta presentación no permite saltar a la coincidencia". Los resultados que solo están en las **notas del presentador** llevan a esa diapositiva y abren el panel de notas. *(Decisión del constructor.)*
- **Tocar una nota o destacado** abre el documento **en su ubicación** siempre que sea posible. PDF y Texto ya lo hacen desde Notas. EPUB gana un parámetro de ubicación inicial (el mismo que usa la búsqueda inicial, construido desde el `anchor` del destacado o la nota). En las presentaciones en ruta PDF se va a la diapositiva del `anchor`. Si no hay ubicación, se abre en la última posición guardada. *(Decisión del constructor.)*
- **Documentos archivados** del plan Free: **se indexan** y aparecen en los resultados, pero al tocarlos se muestra la alerta de "archivado" que ya existe. *(Decisión del constructor.)*
- Mientras haya documentos sin indexar, aparece al pie de la sección: "Indexando N documentos… algunos resultados pueden faltar".

## 5. Enfoques considerados

| Parte | Elegido | Descartado y por qué |
|---|---|---|
| PowerPoint | **Convertir PPTX a PDF con WebKit** al importar o al abrir, y usar la ruta PDF existente | (A) Lista de resultados sin salto sobre QuickLook: el usuario la aceptó solo como plan B si la conversión no era fiel, y la prueba demostró que sí lo es. Renderizar el PPTX por cuenta propia: enorme y menos fiel. |
| Índice global | **SQLite FTS5 en una base separada** | Guardar el texto en SwiftData y recorrerlo en cada búsqueda: más simple, pero lento con muchos libros y sin *snippets* ni ranking. Core Spotlight: no permite consultar dentro de la app con este control. |
| Salto desde la búsqueda global | **Abrir el lector con búsqueda inicial** y reutilizar la búsqueda por documento | Guardar un localizador exacto por coincidencia: duplica lógica de Readium y PDFKit y se rompe con facilidad. |
| Estadísticas | **Calcular al vuelo desde las sesiones** (corregidas) y el progreso | Tabla de agregados diarios: innecesaria con este volumen de datos. |

El usuario aprobó estas opciones y pidió avanzar con todas, con prioridad a las estadísticas.

## 6. Orden de construcción

1. Estadísticas: corregir las sesiones (4.1.1), el calculador con pruebas, la pantalla y el espacio de la mascota. Instalar en el iPhone para revisión.
2. PowerPoint: conversor, integración en importación y apertura, y búsqueda en la ruta PDF de presentaciones. Instalar para revisión.
3. Búsqueda global: índice, fragmentadores, indexado de lo existente, pantalla y apertura con búsqueda inicial. Instalar para revisión.

Cada parte es un commit (o varios) independiente y se prueba en el iPhone antes de pasar a la siguiente.

## 7. Pruebas

- **Unitarias:** `ReadingStatsCalculator` (racha que cruza la medianoche, racha con hoy sin lectura, deduplicación de checkpoints, semana según `firstWeekday`, umbral de 60 s), upsert del repositorio de sesiones, `SearchIndexStore` (acentos, prefijo, escape de comillas o `*`, borrado) y `ContentChunker` con TXT y PDF de ejemplo.
- **Manuales en el iPhone:** conversión con las presentaciones reales del usuario (fidelidad y número de diapositivas), *fallback* a QuickLook, búsqueda global abriendo cada formato en la coincidencia y la pantalla de estadísticas en tema claro, oscuro y sepia.

## 8. Decisiones del constructor (mis decisiones, revisables)

- Nombre del recurso de la mascota: `statsMascot`.
- Meta semanal: 120 min por defecto.
- Umbral de "terminado": 98 %. Umbral de día activo: 60 s.
- Tamaño de fragmento: unos 4.000 caracteres. Hasta 5 fragmentos por documento en los resultados.
- Nombre del PDF convertido: `<localFileName>.rendered.pdf`.
- Quedan al criterio de quien construya: la disposición fina de las tarjetas, las animaciones, el diseño exacto del gráfico (colores del tema y resaltado de hoy) y los textos secundarios. Deben respetar el sistema de diseño existente.
