# Lectoria iOS
## Especificación integral de producto, UX, arquitectura y desarrollo para Google Antigravity

> **Nombre provisional:** Lectoria  
> **Plataforma inicial:** iPhone  
> **Tipo de producto:** lector digital premium para EPUB, PDF y texto  
> **Modelo:** aplicación freemium con suscripción mediante App Store  
> **Estado:** documento maestro para diseño y desarrollo inicial  
> **Idioma inicial:** español, con arquitectura preparada para inglés  
> **Última actualización:** julio de 2026

---

# 0. Instrucción maestra para Antigravity

Actúa como un equipo senior compuesto por:

- Product Manager especializado en aplicaciones móviles.
- Diseñador UX/UI especializado en iOS y lectura digital.
- Arquitecto de software iOS.
- Desarrollador senior Swift y SwiftUI.
- Especialista en EPUB, PDF y procesamiento de texto.
- Ingeniero de backend y seguridad.
- Ingeniero de calidad y automatización de pruebas.
- Especialista en StoreKit, App Store y monetización.
- Especialista en privacidad y tratamiento de documentos personales.

Tu objetivo es diseñar y construir una aplicación iPhone nativa denominada provisionalmente **Lectoria**, orientada a lectura, estudio y gestión del conocimiento.

La aplicación debe permitir importar, organizar y leer:

- EPUB sin DRM.
- PDF sin DRM.
- TXT.
- Markdown `.md`.
- Texto pegado manualmente por el usuario.

La aplicación debe ofrecer una experiencia de lectura minimalista, elegante, rápida y altamente configurable, inspirada en la facilidad de uso de los lectores electrónicos, pero sin copiar la interfaz, la identidad visual, los recursos gráficos ni los patrones distintivos de Kindle, Apple Books, Kobo u otras aplicaciones.

La aplicación debe tener diseño propio, arquitectura mantenible, soporte offline, persistencia local, sincronización opcional, anotaciones y funciones de inteligencia artificial controladas por el usuario.

No utilizar CrossPoint como base de código. CrossPoint es firmware para dispositivos e-reader específicos y no corresponde a la arquitectura de una aplicación iOS. Solo pueden tomarse como referencia conceptual funciones genéricas como biblioteca, progreso, marcadores, temas y lectura enfocada.

## Reglas obligatorias para la generación

1. Crear una aplicación iOS nativa, no una PWA ni un contenedor web.
2. Usar Swift, SwiftUI y APIs nativas de Apple.
3. Aplicar arquitectura modular, testeable y escalable.
4. Evitar archivos Swift excesivamente grandes.
5. Evitar lógica de negocio dentro de las vistas.
6. No incrustar claves privadas ni secretos en el cliente.
7. No almacenar documentos sensibles sin protección.
8. No implementar eliminación, evasión o manipulación de DRM.
9. No permitir contenido pirateado ni crear una tienda de libros en el MVP.
10. No copiar la apariencia de Kindle.
11. Mantener todas las funcionalidades principales disponibles offline, salvo IA, sincronización y pagos.
12. Generar pruebas unitarias y de interfaz para cada módulo crítico.
13. Ejecutar compilación después de cada fase.
14. Corregir warnings relevantes antes de continuar.
15. Documentar cada decisión arquitectónica no trivial.
16. No reemplazar código estable por completo cuando pueda modificarse de forma incremental.
17. No dejar funciones principales simuladas al finalizar una fase.
18. Usar datos de demostración únicamente en previews, fixtures y pruebas.
19. Mantener accesibilidad con VoiceOver, Dynamic Type y contraste suficiente.
20. Mantener preparada la arquitectura para una futura versión iPad, macOS y Android, sin desarrollarlas en el MVP.

---

# 1. Visión del producto

## 1.1 Problema

Las personas leen libros, investigaciones, manuales, apuntes y documentos en aplicaciones distintas. Frecuentemente encuentran alguno de estos problemas:

- Los PDF son incómodos en una pantalla pequeña.
- Las notas quedan aisladas del contenido.
- Los lectores EPUB tienen pocas herramientas de estudio.
- Los documentos personales no se organizan correctamente.
- La experiencia de lectura se interrumpe con elementos innecesarios.
- Las herramientas de IA no siempre respetan el contexto exacto del documento.
- Las aplicaciones existentes obligan al usuario a permanecer en un ecosistema cerrado.
- Los usuarios no pueden convertir fácilmente sus lecturas en resúmenes, fichas o preguntas de estudio.

## 1.2 Solución

Lectoria será una biblioteca y lector personal que permita:

1. Importar publicaciones y textos propios.
2. Leerlos cómodamente en iPhone.
3. Personalizar la presentación.
4. Guardar progreso, marcadores, destacados y notas.
5. Consultar definiciones, traducciones y explicaciones.
6. Generar material de estudio con IA.
7. Exportar conocimiento sin encerrar al usuario en la plataforma.
8. Mantener los archivos disponibles sin conexión.
9. Sincronizar opcionalmente entre dispositivos en versiones posteriores.

## 1.3 Propuesta de valor

> Lee cualquier documento, comprende lo importante y convierte tus lecturas en conocimiento reutilizable.

## 1.4 Posicionamiento

No posicionar el producto como “un clon de Kindle”.

Posicionarlo como:

> Un lector personal para estudiar, investigar y trabajar con EPUB, PDF y texto.

## 1.5 Usuario objetivo inicial

### Segmento principal

- Estudiantes universitarios.
- Docentes.
- Investigadores.
- Profesionales.
- Lectores de ebooks sin DRM.
- Personas que trabajan con manuales, informes y documentos.

### Segmentos secundarios futuros

- Empresas con material de capacitación.
- Universidades.
- Academias.
- Clubes de lectura.
- Consultores.
- Personas con necesidades de accesibilidad lectora.

---

# 2. Objetivos y métricas

## 2.1 Objetivos del MVP

- Importar y abrir correctamente EPUB, PDF, TXT y Markdown.
- Permitir crear una publicación a partir de texto pegado.
- Guardar la posición de lectura.
- Permitir marcadores, destacados y notas.
- Ofrecer una interfaz propia y atractiva.
- Funcionar offline.
- Implementar suscripción con StoreKit 2.
- Implementar IA con autorización expresa.
- Preparar una versión distribuible mediante TestFlight.

## 2.2 Métricas de producto

Registrar de manera respetuosa y agregada:

- Activación: usuario que importa y abre su primer documento.
- Tiempo hasta primera lectura.
- Documentos importados por usuario.
- Sesiones de lectura por semana.
- Minutos de lectura.
- Porcentaje de usuarios que vuelve en 7 y 30 días.
- Marcadores, destacados y notas por documento.
- Uso de funciones de IA.
- Conversión de plan gratuito a premium.
- Cancelaciones y restauraciones de compra.
- Errores de importación por formato.
- Crash-free sessions.
- Tiempo promedio de apertura.

No registrar el contenido de los libros, notas o consultas sin autorización explícita.

---

# 3. Alcance funcional

## 3.1 Formatos del MVP

### EPUB

- EPUB 2 y EPUB 3 sin DRM.
- Contenido reflowable.
- Fixed layout cuando el toolkit lo permita.
- Tabla de contenido.
- Navegación por capítulos.
- Portada y metadatos.
- Búsqueda.
- Marcadores.
- Destacados.
- Preferencias tipográficas.
- Progreso mediante locator.

### PDF

- PDF sin contraseña o con contraseña suministrada por el usuario.
- Paginación vertical y horizontal.
- Zoom.
- Miniaturas.
- Búsqueda.
- Marcadores.
- Destacados y anotaciones cuando el PDF contenga una capa de texto.
- Selección de texto.
- Progreso por página y posición.
- Modo de recorte de márgenes como mejora posterior.

### TXT

- Codificación UTF-8 como estándar.
- Detección razonable de codificaciones comunes.
- Importación de archivos.
- Creación de título editable.
- Separación visual de párrafos.
- Búsqueda.
- Destacados y notas.
- Preferencias tipográficas.
- Progreso por offset y porcentaje.

### Markdown

- Encabezados.
- Párrafos.
- Listas.
- Citas.
- Negrita.
- Cursiva.
- Enlaces.
- Código inline y bloques de código.
- Separadores.
- Tablas como mejora posterior.
- El HTML embebido debe sanitizarse o ignorarse.

### Texto pegado

El usuario podrá:

1. Presionar “Nuevo texto”.
2. Pegar o escribir contenido.
3. Asignar título.
4. Asignar autor opcional.
5. Seleccionar tipo: texto simple o Markdown.
6. Guardar como publicación local.
7. Leerlo con todas las herramientas disponibles.

## 3.2 Formatos fuera del MVP

No desarrollar inicialmente:

- MOBI.
- AZW/AZW3.
- DOC/DOCX.
- RTF.
- ODT.
- CBR.
- Audiolibros.
- Libros protegidos con DRM.
- Importación desde cuentas Kindle.

La arquitectura debe permitir añadir nuevos adaptadores posteriormente.

---

# 4. Funciones por módulo

## 4.1 Onboarding

Pantallas:

1. Bienvenida.
2. Explicación breve de biblioteca privada.
3. Formatos admitidos.
4. Privacidad e IA opcional.
5. Selección de apariencia inicial.
6. Opción de continuar sin cuenta.
7. Opción de iniciar sesión con Apple para sincronización futura.

Principios:

- Máximo 4 a 6 pasos.
- Permitir omitir.
- No obligar a pagar.
- No pedir permisos sin contexto.
- No pedir acceso completo a archivos; usar selector del sistema.

## 4.2 Inicio

Contenido:

- Saludo contextual discreto.
- “Continuar leyendo”.
- Documento actual con progreso.
- Lista de documentos recientes.
- Meta semanal.
- Acceso rápido a importar.
- Acceso rápido a crear texto.
- Recomendaciones internas basadas solo en la biblioteca del usuario.

No incluir tienda de libros.

## 4.3 Biblioteca

Funciones:

- Vista cuadrícula.
- Vista lista.
- Ordenar por:
  - Última lectura.
  - Fecha de importación.
  - Título.
  - Autor.
  - Progreso.
- Filtrar por:
  - EPUB.
  - PDF.
  - TXT.
  - Markdown.
  - En progreso.
  - Terminados.
  - No iniciados.
  - Favoritos.
- Buscar por título, autor y texto indexado.
- Crear colecciones.
- Editar metadatos.
- Cambiar portada.
- Marcar como terminado.
- Reiniciar progreso.
- Eliminar solo del dispositivo.
- Eliminar de la cuenta y nube cuando exista sincronización.
- Compartir o exportar el archivo original cuando el usuario tenga derecho a hacerlo.

## 4.4 Importación

Fuentes iniciales:

- Aplicación Archivos.
- iCloud Drive.
- “Abrir con Lectoria”.
- Share Sheet.
- Texto pegado.
- Arrastrar y soltar cuando se incorpore iPad.

Proceso:

1. Seleccionar archivo.
2. Obtener acceso temporal mediante security-scoped resource.
3. Copiar a un directorio privado administrado por la app.
4. Calcular hash SHA-256.
5. Detectar duplicado.
6. Extraer metadatos.
7. Generar portada o miniatura.
8. Validar formato.
9. Crear registro local.
10. Indexar texto en segundo plano.
11. Mostrar estado.
12. Abrir o volver a biblioteca.

Errores claros:

- Archivo dañado.
- Formato no compatible.
- EPUB protegido.
- PDF protegido.
- Codificación no compatible.
- Sin espacio disponible.
- Documento duplicado.
- Importación cancelada.

## 4.5 Lector EPUB

Interacciones:

- Toque central: mostrar u ocultar controles.
- Toque lateral derecho: página siguiente.
- Toque lateral izquierdo: página anterior.
- Deslizamiento horizontal opcional.
- Desplazamiento vertical opcional.
- Mantener pulsado o seleccionar texto: menú de acciones.
- Pellizco no debe cambiar tamaño; el tamaño se controla desde apariencia.
- Respetar enlaces, notas al pie e imágenes.

Barra superior:

- Volver.
- Título corto.
- Añadir o quitar marcador.
- Menú adicional.

Barra inferior:

- Capítulo.
- Porcentaje.
- Progreso.
- Índice.
- Búsqueda.
- Apariencia.
- Notas.

Preferencias:

- Fuente.
- Tamaño.
- Peso.
- Interlineado.
- Margen horizontal.
- Espaciado de párrafos.
- Alineación.
- Guiones.
- Tema.
- Brillo dentro de los límites permitidos.
- Paginado o scroll.
- Mantener pantalla activa durante lectura, configurable.

## 4.6 Lector PDF

Interacciones:

- Scroll vertical por defecto.
- Modo paginado horizontal opcional.
- Zoom.
- Doble toque para ajustar.
- Indicador de página.
- Navegador de miniaturas.
- Búsqueda.
- Selección.
- Marcadores.
- Destacados.
- Notas.
- Compartir página o selección, respetando derechos.

Para PDFs escaneados:

- Mostrar que no se detectó texto.
- Permitir lectura visual.
- OCR será una función posterior y debe ejecutarse con consentimiento.

## 4.7 Lector de texto y Markdown

Crear un motor de texto nativo con:

- Renderizado fluido.
- Paginación o desplazamiento.
- Tipografía configurable.
- Selección y anotaciones.
- Índice generado desde encabezados Markdown.
- Búsqueda.
- Estimación de tiempo restante.
- Progreso persistente.
- Protección contra archivos extremadamente grandes.
- Procesamiento incremental.

No cargar todo el contenido en una sola vista si el archivo es muy grande.

## 4.8 Destacados

Colores semánticos propios:

- Idea principal.
- Duda.
- Evidencia.
- Acción.
- Cita.

Permitir personalizar nombres posteriormente.

Cada destacado almacena:

- Documento.
- Ubicación estable.
- Texto seleccionado.
- Prefijo y sufijo contextual.
- Color o categoría.
- Fecha.
- Nota vinculada.
- Estado de sincronización.

## 4.9 Notas

Tipos:

- Nota vinculada a selección.
- Nota vinculada a página o posición.
- Nota general del documento.

Funciones:

- Editar.
- Etiquetar.
- Buscar.
- Ordenar.
- Exportar.
- Navegar al contenido.
- Convertir en flashcard posteriormente.

## 4.10 Marcadores

- Añadir en la posición actual.
- Nombre opcional.
- Fecha.
- Navegación directa.
- Lista por documento.

## 4.11 Búsqueda

Tres niveles:

1. En documento actual.
2. En biblioteca.
3. En notas y destacados.

La búsqueda global debe distinguir:

- Títulos.
- Autores.
- Contenido.
- Notas.
- Destacados.

Usar indexación local. No enviar contenido al servidor para buscar.

## 4.12 Estadísticas

MVP:

- Minutos leídos.
- Días activos.
- Racha.
- Documentos iniciados.
- Documentos terminados.
- Páginas o porcentaje aproximado.
- Meta semanal configurable.

Evitar gamificación invasiva.

## 4.13 Exportación

Permitir exportar:

- Notas y destacados en Markdown.
- Notas y destacados en TXT.
- Resumen del documento.
- Citas con referencia básica.
- Archivo original cuando corresponda.
- Copia de seguridad de datos como fase posterior.

Formato sugerido:

```markdown
# Título del documento
Autor: Nombre
Fecha de exportación: AAAA-MM-DD

## Capítulo o página

> Texto destacado

**Categoría:** Idea principal  
**Nota:** Texto de la nota
```

---

# 5. Inteligencia artificial

## 5.1 Principio

La IA debe ayudar a comprender, no sustituir la lectura.

Ningún documento debe enviarse automáticamente a un proveedor de IA.

Antes del primer uso, mostrar:

- Qué contenido será enviado.
- Con qué finalidad.
- Qué proveedor se usa.
- Si se conserva o no.
- Cómo desactivar la función.

## 5.2 Funciones de IA del MVP premium

Sobre una selección:

- Explicar.
- Simplificar.
- Traducir.
- Definir términos.
- Crear una pregunta.
- Crear una flashcard.
- Relacionar con otra parte del documento.

Sobre un capítulo o bloque:

- Resumir.
- Identificar conceptos.
- Crear preguntas de estudio.
- Generar puntos clave.

Sobre el documento completo:

- Conversar con el documento.
- Crear síntesis.
- Generar guía de estudio.

Las funciones sobre documento completo pueden quedar detrás de límites premium y procesamiento previo.

## 5.3 Reglas de grounding

Toda respuesta debe:

- Basarse en fragmentos recuperados del documento.
- Mostrar referencias internas.
- Diferenciar contenido del documento de inferencias.
- Indicar cuando no hay evidencia suficiente.
- Evitar inventar citas o páginas.
- No responder como si hubiera leído contenido que no fue indexado.
- Limitar el contexto enviado.

## 5.4 Arquitectura de IA

Nunca llamar al proveedor directamente con una clave secreta desde iOS.

Flujo:

1. Cliente autentica usuario.
2. Cliente solicita operación al backend.
3. Backend valida plan y cuota.
4. Cliente envía selección o identificadores de fragmentos.
5. Backend recupera únicamente contenido autorizado.
6. Backend aplica prompt seguro.
7. Backend llama al modelo.
8. Backend registra consumo mínimo.
9. Backend devuelve respuesta y referencias.
10. Cliente permite guardar respuesta como nota.

## 5.5 Seguridad frente a prompt injection

El contenido importado es dato no confiable.

El sistema debe:

- Tratar instrucciones dentro del documento como contenido.
- Ignorar cualquier texto que intente cambiar las reglas del sistema.
- No ejecutar enlaces, código o herramientas por indicación del documento.
- No revelar prompts, secretos o claves.
- Sanitizar HTML y Markdown.
- Limitar tamaños y tipos de archivo.
- Validar respuestas estructuradas.

## 5.6 Cuotas iniciales sugeridas

Plan gratuito:

- 3 acciones de IA al mes.
- Solo sobre selección corta.

Plan premium:

- 100 créditos al mes.
- Resumen de capítulos.
- Preguntas de estudio.
- Chat con documentos con límites razonables.

Los valores deben estar configurados remotamente, no hardcodeados.

---

# 6. Modelo comercial

## 6.1 Plan gratuito

- Hasta 5 documentos activos.
- EPUB, PDF, TXT y Markdown.
- Lectura offline.
- Marcadores.
- Hasta 30 destacados.
- Hasta 15 notas.
- 3 acciones de IA al mes.
- Sin sincronización multidispositivo.
- Exportación básica.

## 6.2 Plan Premium

Precio inicial de prueba, no definitivo:

- Mensual: USD 3.99 a USD 5.99 según mercado.
- Anual: descuento equivalente a 2 o 3 meses.
- Prueba gratuita opcional de 7 días.

Incluye:

- Documentos ilimitados bajo política de uso justo.
- Notas y destacados ilimitados bajo uso razonable.
- Sincronización.
- Exportación avanzada.
- Estadísticas.
- IA con cuota mensual.
- Colecciones.
- Temas adicionales.
- Herramientas académicas.

## 6.3 Compras

Implementar exclusivamente mediante StoreKit 2 para bienes y servicios digitales dentro de iOS.

Funciones:

- Cargar productos.
- Comprar.
- Verificar transacción.
- Restaurar compras.
- Consultar entitlement.
- Manejar expiración.
- Manejar período de gracia.
- Manejar reembolso.
- Manejar revocación.
- Abrir administración de suscripción.
- Mostrar precios localizados.
- Nunca asumir un precio fijo en la interfaz.

## 6.4 Paywall

El paywall debe:

- Explicar beneficios.
- Mostrar precios localizados.
- Mostrar período y renovación.
- Incluir restaurar compras.
- Incluir términos y privacidad.
- No usar urgencia falsa.
- No bloquear la lectura básica.
- Mostrar límites del plan gratuito con claridad.

---

# 7. Identidad visual propia

## 7.1 Dirección creativa

Concepto visual:

> Biblioteca contemporánea, papel cálido, tinta profunda y tecnología silenciosa.

Evitar:

- Copiar la cuadrícula, iconografía, menús o branding de Kindle.
- Usar el color y composición de Amazon.
- Reproducir pantallas de Apple Books.
- Exceso de glassmorphism en lectura.
- Elementos decorativos que reduzcan legibilidad.

## 7.2 Personalidad

- Serena.
- Intelectual.
- Moderna.
- Humana.
- Precisa.
- No infantil.
- No futurista extrema.
- Premium sin ser ostentosa.

## 7.3 Paleta propuesta

Definir colores semánticos mediante Assets y soporte automático claro/oscuro.

### Tema claro

- Fondo principal: marfil cálido.
- Superficie: blanco papel.
- Texto principal: carbón.
- Texto secundario: gris tinta.
- Acento: verde petróleo.
- Acento secundario: terracota suave.
- Bordes: gris cálido tenue.

### Tema oscuro

- Fondo principal: negro azulado.
- Superficie: grafito.
- Texto principal: marfil.
- Texto secundario: gris cálido.
- Acento: verde menta apagado.
- Acento secundario: cobre suave.

### Tema sepia

- Fondo: papel envejecido moderado.
- Texto: marrón oscuro.
- Elementos de interfaz: contraste AA como mínimo.

No usar valores directos en cada vista. Crear tokens.

## 7.4 Tipografía

Interfaz:

- SF Pro mediante tipografía del sistema.

Lectura:

- New York.
- Georgia como fallback conceptual.
- Atkinson Hyperlegible como opción futura.
- Fuentes personalizadas solo si su licencia permite distribución.

Soportar Dynamic Type en interfaz. En el contenido, ofrecer escala controlada y accesible.

## 7.5 Iconografía

- SF Symbols cuando corresponda.
- Iconos propios solo para acciones distintivas.
- Mantener trazos coherentes.
- No usar íconos de Kindle o Amazon.

## 7.6 Componentes

Crear un Design System interno:

- `AppColor`.
- `AppTypography`.
- `AppSpacing`.
- `AppRadius`.
- `AppShadow`.
- `PrimaryButton`.
- `SecondaryButton`.
- `IconButton`.
- `PublicationCard`.
- `ProgressPill`.
- `EmptyStateView`.
- `FilterChip`.
- `ReaderToolbar`.
- `SettingsRow`.
- `PaywallFeatureRow`.
- `ToastView`.
- `LoadingState`.
- `ErrorState`.

## 7.7 Navegación

Tab bar inicial:

1. Inicio.
2. Biblioteca.
3. Notas.
4. Perfil.

Botón de importar destacado sin romper convenciones de iOS.

---

# 8. Arquitectura técnica

## 8.1 Requisitos base

- Lenguaje: Swift 6.
- UI: SwiftUI.
- Herramienta de compilación para distribución: Xcode 26 o posterior estable.
- Deployment target recomendado: iOS 17.0 o superior.
- Concurrencia: async/await y actores.
- Persistencia local: SwiftData.
- Seguridad: Keychain y protección de archivos.
- Suscripciones: StoreKit 2.
- EPUB: Readium Swift Toolkit.
- PDF: PDFKit.
- Texto: TextKit 2, AttributedString y componentes SwiftUI/UIKit cuando sea necesario.
- Importación: `fileImporter`, Uniform Type Identifiers y Share Extension.
- Miniaturas: QuickLookThumbnailing o PDFKit según formato.
- Backend: Supabase.
- Backend functions: Supabase Edge Functions.
- Base vectorial futura: PostgreSQL con pgvector.
- Analítica: capa abstracta, privacidad primero.
- Crash reporting: integrar solo tras consentimiento y revisión de privacidad.

## 8.2 Decisión sobre motores

### EPUB

Usar Readium Swift Toolkit.

Módulos iniciales:

- ReadiumShared.
- ReadiumStreamer.
- ReadiumNavigator.

No implementar Readium LCP en el MVP.

### PDF

Usar PDFKit para:

- Renderizado.
- Paginación.
- Búsqueda.
- Selección.
- Anotaciones.
- Miniaturas.

No usar un webview como lector PDF principal.

### TXT y Markdown

Crear `TextPublicationEngine`.

Responsabilidades:

- Abrir archivo.
- Detectar codificación.
- Normalizar saltos.
- Parsear Markdown seguro.
- Dividir en bloques.
- Indexar.
- Resolver anchors.
- Renderizar.
- Guardar progreso.

## 8.3 Patrón arquitectónico

Usar Clean Architecture pragmática con módulos por feature.

Capas:

- `App`: composición y navegación.
- `Domain`: entidades, contratos y casos de uso.
- `Data`: repositorios, persistencia, archivos y red.
- `Features`: vistas y view models.
- `ReaderCore`: abstracciones comunes de lectura.
- `Engines`: EPUB, PDF y Text.
- `DesignSystem`: tokens y componentes.
- `Services`: autenticación, IA, compras, sincronización y analítica.
- `Extensions`: Share Extension.
- `Tests`: unitarias, integración y UI.

No crear una abstracción excesiva antes de tener al menos dos implementaciones reales.

## 8.4 Protocolos centrales

```swift
protocol PublicationEngine {
    associatedtype Location: Codable & Sendable

    func open(publication: PublicationRecord) async throws
    func close() async
    func currentLocation() async -> Location?
    func go(to location: Location) async throws
    func search(_ query: String) async throws -> [SearchResult]
    func tableOfContents() async throws -> [TOCItem]
}

protocol AnnotationAnchoring {
    func createAnchor(from selection: ReaderSelection) async throws -> AnnotationAnchor
    func resolve(anchor: AnnotationAnchor) async throws -> ResolvedAnnotation?
}

protocol PublicationRepository {
    func fetchAll() async throws -> [PublicationRecord]
    func fetch(id: UUID) async throws -> PublicationRecord?
    func save(_ publication: PublicationRecord) async throws
    func delete(id: UUID) async throws
}
```

Usar type erasure o adaptadores cuando sea necesario para integrar motores heterogéneos.

## 8.5 Estrategia offline-first

Fuente de verdad local:

- SwiftData para metadatos, progreso, notas, destacados y operaciones pendientes.
- Archivos almacenados localmente en Application Support.
- Backend como sincronización y respaldo, no como dependencia para abrir documentos.

Flujo:

1. Escritura local inmediata.
2. Crear operación de sincronización.
3. Intentar sincronizar.
4. Resolver conflictos.
5. Confirmar estado.
6. Reintentar con backoff.

## 8.6 Estructura de carpetas

```text
Lectoria/
├── App/
│   ├── LectoriaApp.swift
│   ├── AppEnvironment.swift
│   ├── AppRouter.swift
│   └── RootView.swift
├── DesignSystem/
│   ├── Tokens/
│   ├── Components/
│   ├── Modifiers/
│   └── Previews/
├── Domain/
│   ├── Entities/
│   ├── Repositories/
│   ├── UseCases/
│   └── Errors/
├── Data/
│   ├── Persistence/
│   ├── Files/
│   ├── Repositories/
│   ├── Networking/
│   └── Mappers/
├── ReaderCore/
│   ├── Models/
│   ├── Protocols/
│   ├── ReaderCoordinator/
│   ├── Annotations/
│   └── Search/
├── Engines/
│   ├── EPUB/
│   ├── PDF/
│   └── Text/
├── Features/
│   ├── Onboarding/
│   ├── Home/
│   ├── Library/
│   ├── Import/
│   ├── Reader/
│   ├── Notes/
│   ├── Search/
│   ├── Statistics/
│   ├── Paywall/
│   └── Profile/
├── Services/
│   ├── Auth/
│   ├── AI/
│   ├── Subscription/
│   ├── Sync/
│   ├── Analytics/
│   └── Security/
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.xcstrings
│   └── SamplePublications/
├── ShareExtension/
├── LectoriaTests/
└── LectoriaUITests/
```

---

# 9. Modelo de datos local

## 9.1 PublicationRecord

Campos:

- `id: UUID`
- `ownerID: String?`
- `title: String`
- `author: String?`
- `publicationType: PublicationType`
- `localFileName: String`
- `originalFileName: String?`
- `mimeType: String`
- `fileSize: Int64`
- `sha256: String`
- `coverPath: String?`
- `language: String?`
- `createdAt: Date`
- `importedAt: Date`
- `lastOpenedAt: Date?`
- `finishedAt: Date?`
- `isFavorite: Bool`
- `isArchived: Bool`
- `isCloudBackedUp: Bool`
- `indexingStatus: IndexingStatus`
- `syncStatus: SyncStatus`

## 9.2 ReadingProgress

- `id`
- `publicationID`
- `locatorJSON`
- `percentage`
- `pageNumber`
- `chapterTitle`
- `updatedAt`
- `deviceID`
- `version`

## 9.3 Bookmark

- `id`
- `publicationID`
- `anchor`
- `title`
- `createdAt`
- `updatedAt`

## 9.4 Highlight

- `id`
- `publicationID`
- `anchor`
- `selectedText`
- `contextBefore`
- `contextAfter`
- `category`
- `colorToken`
- `createdAt`
- `updatedAt`

## 9.5 Note

- `id`
- `publicationID`
- `highlightID`
- `anchor`
- `body`
- `tags`
- `createdAt`
- `updatedAt`

## 9.6 ReadingSession

- `id`
- `publicationID`
- `startedAt`
- `endedAt`
- `activeSeconds`
- `startPercentage`
- `endPercentage`

## 9.7 AIUsage

- `id`
- `userID`
- `operation`
- `creditCost`
- `createdAt`
- `requestID`

## 9.8 SubscriptionEntitlement

- `productID`
- `status`
- `expirationDate`
- `isInGracePeriod`
- `willAutoRenew`
- `lastVerifiedAt`

## 9.9 Anchors por formato

### EPUB

Guardar el locator serializado de Readium.

### PDF

Guardar:

- Número de página.
- Rectángulo normalizado.
- Texto.
- Prefijo y sufijo.
- Hash de página opcional.

### TXT/Markdown

Guardar:

- Rango de caracteres.
- Identificador de bloque.
- Texto seleccionado.
- Contexto.
- Hash de bloque.
- Estrategia de reparación si el texto cambia.

---

# 10. Backend y sincronización

## 10.1 Supabase

Usar para:

- Sign in with Apple.
- Perfil.
- Entitlements verificados.
- Copia opcional de metadatos.
- Sincronización.
- Almacenamiento cifrado o protegido de documentos si el usuario activa nube.
- Proxy seguro para IA.
- Cuotas.
- Configuración remota.

## 10.2 Tablas sugeridas

- `profiles`
- `publications`
- `reading_progress`
- `bookmarks`
- `highlights`
- `notes`
- `reading_sessions`
- `subscription_entitlements`
- `ai_usage`
- `ai_jobs`
- `remote_config`
- `sync_operations`

## 10.3 Seguridad RLS

Activar Row Level Security en todas las tablas de usuario.

Regla principal:

> Un usuario solo puede leer, insertar, modificar y eliminar registros donde `user_id = auth.uid()`.

No exponer service role key en la aplicación.

## 10.4 Almacenamiento

Buckets:

- `publication-files`
- `publication-covers`
- `exports`

Políticas:

- Carpeta por usuario.
- URLs firmadas temporales.
- Límite de tamaño.
- Escaneo o validación.
- Eliminación completa al borrar cuenta.

## 10.5 Conflictos

Progreso:

- Priorizar actualización con versión más nueva.
- Si dos dispositivos leen simultáneamente, conservar ambas posiciones y pedir al usuario elegir cuando la diferencia sea significativa.

Notas:

- Usar versionado.
- Nunca eliminar silenciosamente una edición.
- Crear copia de conflicto si no se puede fusionar.

## 10.6 Cuenta

Permitir:

- Continuar como invitado.
- Iniciar sesión con Apple.
- Migrar datos locales a cuenta.
- Cerrar sesión sin destruir archivos locales, previa advertencia.
- Eliminar cuenta dentro de la app.
- Exportar datos.

---

# 11. Seguridad y privacidad

## 11.1 Principios

- Minimización.
- Consentimiento.
- Control del usuario.
- Cifrado.
- Transparencia.
- Eliminación.
- No venta de datos.
- No entrenamiento con documentos privados sin consentimiento explícito.

## 11.2 Archivos locales

- Guardar en Application Support, no Documents público salvo exportación.
- Aplicar protección de datos adecuada.
- Evitar backups innecesarios para cachés.
- Conservar originales del usuario con integridad.
- Usar nombres internos no predecibles.

## 11.3 Keychain

Guardar:

- Tokens.
- Identificador de dispositivo.
- Estado de autenticación.
- Secretos de sesión.

No guardar:

- API keys maestras.
- Service role keys.
- Prompts secretos.

## 11.4 Logs

No registrar:

- Texto leído.
- Contenido de notas.
- Fragmentos enviados a IA.
- Tokens.
- Rutas privadas completas.
- Datos de pago.

## 11.5 Derechos de autor

Mostrar en onboarding o importación:

- El usuario debe tener derecho a usar el archivo.
- Lectoria no elimina DRM.
- Lectoria no distribuye libros.
- Lectoria no está afiliada a Amazon ni Kindle.

---

# 12. Accesibilidad

Obligatorio:

- VoiceOver.
- Etiquetas y hints.
- Dynamic Type.
- Botones con área mínima adecuada.
- Contraste.
- Reduce Motion.
- Differentiate Without Color.
- Lectura en orientación vertical y horizontal.
- Soporte RTL en arquitectura.
- No depender solo del color para categorías.
- TTS como fase posterior o mediante capacidades de Readium donde resulte estable.

Pruebas:

- Navegar onboarding sin visión.
- Importar y abrir archivo con VoiceOver.
- Ajustar tamaño de texto.
- Añadir marcador.
- Buscar.
- Abrir notas.
- Comprar o restaurar.

---

# 13. Rendimiento

Objetivos:

- Inicio en frío razonable.
- Biblioteca de 1,000 registros sin congelamiento.
- Apertura de EPUB común menor a 2 segundos después del primer procesamiento, según dispositivo.
- PDF grande procesado progresivamente.
- Scroll estable.
- Indexación en background.
- Cancelación de tareas.
- Sin memory leaks.

Usar:

- Instruments.
- Signposts.
- Cachés con límite.
- Thumbnail lazy loading.
- Actors para acceso a archivos compartidos.
- `Task` cancelable.
- No hacer parsing pesado en MainActor.

---

# 14. Manejo de errores

Crear `AppError` tipado y mensajes amigables.

Categorías:

- Importación.
- Archivo.
- Renderizado.
- Persistencia.
- Red.
- Autenticación.
- Sincronización.
- IA.
- Suscripción.
- Permisos.
- Almacenamiento.

Cada error debe definir:

- Título.
- Mensaje.
- Acción de recuperación.
- Si debe registrarse.
- Código interno no expuesto.

Ejemplo:

```swift
enum ImportError: LocalizedError {
    case unsupportedFormat
    case corruptedFile
    case duplicate(existingID: UUID)
    case insufficientStorage
    case accessDenied
}
```

---

# 15. Pruebas

## 15.1 Unitarias

- Hash y duplicados.
- Detección de formato.
- Parsing de metadatos.
- Repositorios.
- Guardado de progreso.
- Resolución de anchors.
- Cálculo de límites gratuitos.
- Entitlements.
- Cuotas de IA.
- Sanitización Markdown.
- Conflictos de sincronización.

## 15.2 Integración

- Importar EPUB real.
- Importar PDF real.
- Importar TXT.
- Importar Markdown.
- Crear texto pegado.
- Reabrir posición.
- Añadir y recuperar anotación.
- Exportar.
- Comprar con StoreKit Configuration.
- Restaurar compra.
- Llamar backend simulado.

## 15.3 UI

- Onboarding.
- Importación.
- Biblioteca.
- Lectura.
- Apariencia.
- Nota.
- Búsqueda.
- Paywall.
- Restaurar.
- Eliminar cuenta.

## 15.4 Fixtures

Incluir archivos pequeños propios o de dominio público:

- EPUB reflowable.
- EPUB fixed layout.
- PDF con texto.
- PDF escaneado.
- TXT UTF-8.
- Markdown.
- Archivo dañado.
- Archivo grande.
- EPUB con RTL.
- Documento con imágenes.

No incluir obras protegidas.

---

# 16. Analítica

Crear protocolo abstracto:

```swift
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}
```

Eventos permitidos:

- onboarding_completed
- import_started
- import_succeeded
- import_failed
- publication_opened
- reading_session_completed
- highlight_created
- note_created
- ai_action_requested
- ai_action_completed
- paywall_viewed
- purchase_completed
- purchase_restored

No enviar:

- Título real.
- Autor real.
- Texto.
- Nombre de archivo.
- Contenido de nota.

Usar identificadores anónimos o categorías.

---

# 17. Localización

Primera versión:

- Español.
- Inglés preparado.

Usar String Catalog.

No escribir cadenas visibles directamente en las vistas.

Considerar:

- Plurales.
- Fechas.
- Porcentajes.
- Monedas.
- Texto RTL futuro.
- Precios provenientes de StoreKit.

---

# 18. Roadmap

## Fase 0 — Preparación

Entregables:

- Repositorio Git.
- Proyecto Xcode.
- Scheme.
- SwiftLint o reglas equivalentes.
- README.
- Architecture Decision Records.
- CI de compilación y pruebas.
- Entornos dev/staging/prod.

## Fase 1 — Design System y navegación

- Tokens.
- Componentes.
- Tab bar.
- Onboarding.
- Home mock.
- Biblioteca mock.
- Perfil mock.
- Previews.

## Fase 2 — Persistencia e importación

- SwiftData.
- File storage.
- UTI.
- Hash.
- Import coordinator.
- Portadas.
- Duplicados.
- TXT/MD.

## Fase 3 — EPUB

- Readium.
- Navegador.
- Preferencias.
- TOC.
- Progreso.
- Búsqueda.
- Marcadores.

## Fase 4 — PDF

- PDFKit.
- Miniaturas.
- Zoom.
- Búsqueda.
- Progreso.
- Marcadores.
- Selección.

## Fase 5 — Texto

- Motor TXT.
- Markdown.
- Texto pegado.
- Anchors.
- Apariencia.
- Búsqueda.

## Fase 6 — Anotaciones

- Destacados.
- Notas.
- Categorías.
- Lista global.
- Exportación.

## Fase 7 — Cuenta y backend

- Supabase.
- Sign in with Apple.
- Perfil.
- Migración invitado.
- Eliminación.

## Fase 8 — StoreKit

- Productos.
- Paywall.
- Entitlements.
- Límites.
- Restaurar.
- Pruebas.

## Fase 9 — IA

- Backend proxy.
- Consentimiento.
- Explicar.
- Resumir.
- Traducir.
- Cuotas.
- Guardar como nota.

## Fase 10 — Sincronización

- Metadatos.
- Progreso.
- Notas.
- Conflictos.
- Archivos opcionales.

## Fase 11 — Calidad y lanzamiento

- Accesibilidad.
- Rendimiento.
- Seguridad.
- TestFlight.
- Metadatos.
- Política de privacidad.
- App Review.

---

# 19. Prompts secuenciales para Antigravity

No ejecutar todo el proyecto mediante un único prompt. Completar cada bloque, compilar, probar y confirmar criterios antes de continuar.

## Prompt 1 — Crear base del proyecto

```text
Crea un proyecto iOS nativo llamado Lectoria usando Swift 6 y SwiftUI. Usa una arquitectura modular por features y un deployment target iOS 17 o superior. El proyecto debe compilar con la versión estable de Xcode requerida actualmente para App Store.

Crea la estructura de carpetas definida en el documento maestro. Implementa AppEnvironment, navegación raíz, tabs Inicio, Biblioteca, Notas y Perfil. Configura SwiftData con un container inicial. Añade README, decisiones arquitectónicas y pruebas mínimas.

No implementes todavía motores de lectura. Crea protocolos base sin sobreabstraer. Compila y corrige errores antes de finalizar. Devuelve lista de archivos creados, decisiones y pruebas ejecutadas.
```

## Prompt 2 — Design System

```text
Implementa el Design System de Lectoria con tokens semánticos de color, tipografía, espaciado, radios, bordes y sombras. Crea soporte claro, oscuro y sepia. Usa SF Pro para interfaz y New York como opción de lectura.

Crea componentes reutilizables: PrimaryButton, SecondaryButton, IconButton, PublicationCard, ProgressPill, EmptyStateView, FilterChip, ReaderToolbar, SettingsRow, PaywallFeatureRow, ToastView, LoadingState y ErrorState.

Añade previews con Dynamic Type, dark mode y español. No copies Kindle ni Apple Books. Mantén una identidad visual propia: papel cálido, tinta profunda y acento verde petróleo.
```

## Prompt 3 — Modelos y persistencia

```text
Implementa los modelos SwiftData PublicationRecord, ReadingProgress, Bookmark, Highlight, Note, ReadingSession, AIUsage y SubscriptionEntitlement según el documento maestro.

Crea repositorios con protocolos en Domain e implementaciones en Data. Añade migración preparada, no destructiva. Implementa fixtures solo para previews y tests.

Crea pruebas unitarias de CRUD, relaciones, borrado y reapertura del ModelContainer.
```

## Prompt 4 — Importación

```text
Implementa el flujo de importación para EPUB, PDF, TXT y Markdown usando fileImporter y Uniform Type Identifiers.

Copia los archivos a Application Support, calcula SHA-256, detecta duplicados, valida tamaño, extrae metadatos básicos y genera miniatura. Usa security-scoped resource correctamente.

Implementa estados de progreso y errores recuperables. No intentes romper DRM. Crea pruebas con fixtures válidos, duplicados y corruptos.
```

## Prompt 5 — Biblioteca

```text
Implementa Inicio y Biblioteca conectados a datos reales.

Biblioteca debe tener cuadrícula/lista, búsqueda, orden, filtros, favoritos, colecciones simples, edición de título/autor, eliminación y detalle del documento. Inicio debe mostrar continuar leyendo, recientes y meta semanal.

Usa consultas eficientes y lazy containers. Añade estados vacíos y errores.
```

## Prompt 6 — EPUB con Readium

```text
Integra Readium Swift Toolkit mediante Swift Package Manager. Usa la versión estable actual y fija una versión exacta después de validar la compilación.

Implementa apertura de EPUB sin DRM, navegación, TOC, progreso con locator, búsqueda, temas, tamaño de fuente, márgenes, interlineado, paginación y scroll cuando estén disponibles.

Integra el navegador Readium en SwiftUI mediante un wrapper limpio. No mezcles lógica Readium en vistas generales. Crea EPUBReaderAdapter dentro de Engines/EPUB.
```

## Prompt 7 — PDF con PDFKit

```text
Implementa PDFReaderAdapter con PDFKit.

Incluye scroll vertical, paginado horizontal opcional, zoom, miniaturas, búsqueda, selección, marcadores y persistencia por página/posición. Para PDFs sin capa de texto, informa al usuario que la selección no está disponible.

Crea UIViewRepresentable o UIViewControllerRepresentable solo donde sea necesario. Mantén el estado en un ViewModel.
```

## Prompt 8 — TXT y Markdown

```text
Implementa TextPublicationEngine para TXT, Markdown y texto creado manualmente.

Soporta UTF-8, normalización de párrafos, encabezados, listas, citas, énfasis, enlaces y bloques de código. Sanitiza o ignora HTML. Implementa procesamiento por bloques para archivos grandes.

Añade búsqueda, progreso, selección, notas, destacados, índice Markdown y preferencias tipográficas. Crea estrategia estable de anchors basada en bloque, rango, texto y contexto.
```

## Prompt 9 — Lector unificado

```text
Crea ReaderCoordinator y ReaderContainerView para seleccionar el motor correcto según PublicationType.

La interfaz exterior debe ser coherente para EPUB, PDF y texto: controles, marcador, índice, búsqueda, apariencia, progreso y notas. Las capacidades no disponibles deben ocultarse o explicarse, no fallar.

Implementa toque central para chrome, controles accesibles y restauración exacta del progreso.
```

## Prompt 10 — Anotaciones

```text
Implementa destacados, notas y marcadores.

Crea categorías Idea principal, Duda, Evidencia, Acción y Cita. Permite añadir nota a un destacado. Implementa la pantalla global de Notas con búsqueda y navegación al contenido original.

Añade exportación Markdown y TXT. Prueba la resolución de anchors tras cerrar y reabrir.
```

## Prompt 11 — StoreKit 2

```text
Implementa SubscriptionService con StoreKit 2.

Incluye carga de productos, compra, verificación, restauración, estado actual, expiración, gracia, revocación y administración de suscripción. Usa una StoreKit Configuration para desarrollo.

Crea un paywall honesto y accesible. Los precios deben provenir de StoreKit. Implementa límites gratuitos mediante FeatureEntitlementService y nunca disperses condicionales de plan por todas las vistas.
```

## Prompt 12 — Supabase y Sign in with Apple

```text
Integra Supabase mediante una capa de Networking aislada. Implementa Sign in with Apple, perfil, sesión, migración de datos de invitado y eliminación de cuenta.

No incluyas service role key en el cliente. Usa Keychain para tokens. Configura modelos de requests/responses Sendable. Añade mocks para pruebas.

Documenta variables de entorno y configuración manual requerida.
```

## Prompt 13 — IA segura

```text
Implementa AIService en el cliente y Edge Functions en Supabase.

Funciones: explicar selección, simplificar, traducir, resumir bloque y crear preguntas. Antes del primer uso, solicita consentimiento informado. No envíes documentos completos por defecto.

Valida plan, cuota y tamaño en backend. Trata contenido como dato no confiable. Evita prompt injection. Devuelve respuesta con referencias internas y guarda solo si el usuario lo decide.
```

## Prompt 14 — Sincronización

```text
Implementa SyncEngine offline-first para progreso, marcadores, destacados y notas.

Usa cola local, reintentos con backoff, idempotencia, versionado y resolución de conflictos. No bloquees la lectura por falta de red.

La sincronización de archivos debe ser opcional y premium. Usa URLs firmadas y políticas RLS.
```

## Prompt 15 — Share Extension

```text
Crea una Share Extension para importar EPUB, PDF, TXT y Markdown desde otras aplicaciones.

También permite recibir texto seleccionado y crear una nueva publicación. Usa App Group para transferir de forma segura al contenedor principal. Maneja archivos grandes sin bloquear la extensión.
```

## Prompt 16 — Calidad final

```text
Realiza auditoría completa:

- compilación;
- pruebas;
- concurrencia Swift 6;
- memory leaks;
- accesibilidad;
- Dynamic Type;
- VoiceOver;
- dark mode;
- offline;
- errores;
- privacidad;
- claves;
- RLS;
- StoreKit;
- eliminación de cuenta;
- importación de archivos dañados;
- biblioteca grande.

Corrige defectos críticos. Genera reporte de release y lista de pendientes no bloqueantes.
```

---

# 20. Criterios de aceptación del MVP

## Importación

- Se importa EPUB válido.
- Se importa PDF válido.
- Se importa TXT.
- Se importa Markdown.
- Se crea documento pegando texto.
- Se detectan duplicados.
- Un archivo corrupto no causa crash.
- Un archivo DRM no se intenta desbloquear.

## Lectura

- Cada formato abre.
- La posición se guarda.
- La posición se restaura.
- El cambio de tema persiste.
- El contenido sigue disponible offline.
- El lector no pierde progreso al cerrar abruptamente.

## Anotaciones

- Se crea marcador.
- Se crea destacado.
- Se crea nota.
- Se navega desde nota a contenido.
- Se exportan notas.

## Pago

- Se muestra precio localizado.
- Se compra en sandbox.
- Se restaura.
- La expiración cambia entitlement.
- El usuario gratuito conserva lectura básica.

## IA

- Requiere consentimiento.
- No contiene clave en cliente.
- Respeta cuotas.
- Cita fragmentos.
- Indica falta de evidencia.
- Puede guardarse como nota.

## Privacidad

- Se elimina cuenta.
- Se eliminan datos remotos.
- Se puede usar sin cuenta.
- No se registran textos.
- Se muestra política de privacidad.

---

# 21. Definition of Done por tarea

Una tarea se considera terminada solo cuando:

- El código compila.
- No añade errores de concurrencia.
- Tiene pruebas relevantes.
- Tiene accesibilidad.
- Tiene estados loading, empty, error y success.
- Está localizada.
- No expone secretos.
- Usa Design System.
- No duplica lógica.
- Está documentada cuando corresponde.
- Cumple criterios de aceptación.
- Se registra en changelog técnico.

---

# 22. Backlog posterior al MVP

Prioridad alta:

- iPad.
- Sincronización completa.
- TTS.
- OCR.
- Flashcards.
- Chat documental.
- Exportación PDF/DOCX.
- Widgets.
- Atajos de Siri.
- Metas avanzadas.

Prioridad media:

- OPDS.
- Audiolibros.
- CBZ.
- Modo enfoque.
- Lectura biónica opcional.
- Diccionarios descargables.
- Integración con Zotero.
- Integración con Obsidian.
- Citación APA.
- Plan docente.

Prioridad baja:

- Marketplace.
- Lectura social.
- Clubes.
- Marca blanca.
- DRM propio.
- Android.

---

# 23. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---:|---|
| EPUB complejos | Alto | Readium, fixtures diversos y fallback |
| PDF escaneados | Medio | Informar; OCR posterior |
| Anchors frágiles | Alto | Ubicación + texto + contexto + hash |
| Costos de IA | Alto | Cuotas, caché y procesamiento por selección |
| Rechazo App Store | Alto | StoreKit 2, privacidad y revisión temprana |
| Pérdida de datos | Alto | Offline-first, backups y sync idempotente |
| Copia visual de Kindle | Alto | Design System propio |
| Archivos maliciosos | Alto | Límites, sandbox, sanitización |
| Dependencia de toolkit | Medio | Adapter y versión fijada |
| Scope excesivo | Alto | Fases y criterios estrictos |

---

# 24. Entregables del proyecto

Antigravity debe producir:

1. Repositorio Git completo.
2. Proyecto Xcode compilable.
3. Código fuente.
4. Tests.
5. Assets.
6. README de instalación.
7. Configuración Supabase.
8. Migraciones SQL.
9. Edge Functions.
10. StoreKit Configuration.
11. Guía de App Store Connect.
12. Política de privacidad borrador.
13. Términos borrador.
14. Documento de arquitectura.
15. Reporte de seguridad.
16. Reporte de accesibilidad.
17. Checklist TestFlight.
18. Lista de variables y secretos.
19. Changelog.
20. Roadmap posterior.

---

# 25. Exclusiones explícitas

No construir en la primera versión:

- Tienda de ebooks.
- Importación Kindle.
- Eliminación de DRM.
- Scraping de bibliotecas comerciales.
- Android.
- macOS.
- iPad optimizado.
- Portal institucional.
- Publicidad.
- Red social.
- DRM propio.
- Conversión masiva de formatos.
- OCR completo.
- Audiolibros.
- Sincronización con Amazon.

---

# 26. Decisión final sobre CrossPoint

CrossPoint no debe incluirse como dependencia ni copiarse como aplicación base.

Razones:

- Es firmware para hardware e-reader específico.
- Está escrito principalmente en C/C++.
- Está optimizado para memoria limitada y pantalla e-ink.
- Su arquitectura de caché y navegación responde a restricciones distintas.
- No resuelve integración con SwiftUI, StoreKit, App Store, PDFKit o iOS.
- Migrarlo aumentaría el riesgo y el costo.

Sí pueden estudiarse conceptos generales:

- Lectura sin distracciones.
- Biblioteca simple.
- Progreso persistente.
- Temas.
- Marcadores.
- Caché.
- Tipografías configurables.

La aplicación deberá construirse desde cero con arquitectura iOS y diseño propio.

---

# 27. Primer resultado esperado

El primer hito no será una aplicación completa.

Debe ser un prototipo funcional que permita:

1. Abrir la app.
2. Completar onboarding.
3. Importar un EPUB, PDF, TXT o Markdown.
4. Verlo en biblioteca.
5. Abrirlo.
6. Leerlo.
7. Cerrar.
8. Reabrir en la misma posición.
9. Cambiar tema.
10. Añadir marcador.
11. Crear un texto pegado.

Después de validar este hito se desarrollarán destacados, notas, pagos, IA y sincronización.

---

# 28. Comando inicial para Antigravity

Copiar primero el archivo completo al repositorio como:

```text
/docs/LECTORIA_PRODUCT_AND_BUILD_SPEC.md
```

Después enviar a Antigravity:

```text
Lee completamente /docs/LECTORIA_PRODUCT_AND_BUILD_SPEC.md.

No intentes desarrollar todo en una sola ejecución. Comienza únicamente con Fase 0 y Fase 1. Antes de escribir código, resume las decisiones técnicas que aplicarás, identifica dependencias y riesgos, y crea un plan de archivos.

Luego implementa la base del proyecto, Design System y navegación inicial. Compila, ejecuta pruebas y corrige errores. No continúes a la Fase 2 hasta que la base compile y los criterios de esta fase estén cumplidos.

Al finalizar entrega:
1. resumen de lo construido;
2. estructura de archivos;
3. dependencias;
4. pruebas ejecutadas;
5. errores pendientes;
6. instrucciones para abrir y ejecutar el proyecto.
```

---

# 29. Nota de producto

El éxito de Lectoria no dependerá únicamente de admitir muchos formatos. La ventaja competitiva deberá estar en:

- calidad de lectura;
- facilidad de importación;
- organización;
- notas;
- recuperación de conocimiento;
- privacidad;
- experiencia de estudio;
- IA con referencias;
- diseño propio;
- funcionamiento offline.

No sacrificar estabilidad por añadir demasiadas funciones.

La prioridad es construir el mejor flujo posible:

> importar → leer → comprender → anotar → recuperar → continuar.
