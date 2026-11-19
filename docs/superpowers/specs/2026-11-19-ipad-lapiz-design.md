# iPad: marcar con el Apple Pencil (diseño)

Fecha: 19-11-2026.

> **Actualización (19-11-2026, tras probarlo en el iPad):** el usuario pidió retirar la herramienta **Texto** (resaltador de texto con el Pencil) porque no respondía.
>
> - La paleta queda **solo con íconos**: Pluma, Marcador y Borrador.
> - Como en Notas, mantener presionado un ícono, o tocar otra vez el que ya está elegido, abre su color y grosor.
> - En EPUB y texto no hay herramientas y el botón del lápiz no aparece.
> - Las entregas 2 y 3 (EPUB y texto) quedan en pausa.

## Intención

En el iPad, los lectores de Lectoria quieren estudiar marcando con el Apple Pencil, como en Notability o Notas de Apple. Hay dos tipos de marca:
- **Resaltador de texto (A).** Pasas el lápiz sobre una frase y se convierte en un destacado normal de Lectoria: tiene color y categoría, aparece en Notas, entra en la búsqueda y en la copia de seguridad.
- **Trazo libre (B).** Pluma y marcador que dejan la línea tal como se dibuja, con borrador.

Una paleta propia, con el estilo de Lectoria, permite elegir herramienta y color.

## Objetivos

1. Una paleta flotante dentro del lector, solo en iPad, con estas herramientas:
   - **Texto:** el resaltador que se ajusta a las palabras.
   - **Pluma.**
   - **Marcador:** trazo libre semitransparente.
   - **Borrador.**
   - Colores y grosor.
2. **Resaltador de texto** en PDF, presentaciones (que se abren como PDF), EPUB y texto/Markdown.
3. **Pluma, marcador y borrador** en PDF y presentaciones.

## No objetivos

- Cambiar la navegación principal. El menú de abajo (Inicio, Biblioteca, Notas y Perfil) se queda donde está y como está. La petición es explícita.
- Barras o paneles laterales. Se probaron y se descartaron.
- Cuaderno de notas a mano. Queda en pausa.
- Trazo libre en EPUB y texto. El contenido se reacomoda al cambiar el tamaño de letra y el trazo quedaría fuera de lugar.
- Cambios en el iPhone.

## Anti-objetivos

- Que el dedo deje de servir para pasar páginas, desplazarse o seleccionar como hoy.
- Que el Pencil marque sin querer cuando la paleta está oculta.
- Que algo cambie en el iPhone.

## Enfoques considerados

| Enfoque | Decisión |
|---|---|
| **Paleta propia de Lectoria**: igual en todos los formatos, con los colores de las categorías de destacados | **Elegida** por el usuario |
| Paleta de Apple (`PKToolPicker`) con el resaltador de texto como herramienta personalizada | Descartada: se ve "de Apple" y en EPUB y texto, sin lienzo de dibujo, habría que forzarla |
| Solo trazo libre | Descartada: no funciona en EPUB ni en texto y no es buscable |

## Cómo funciona

### Activar el modo lápiz

- **Botón de lápiz** en la barra superior de cada lector, solo en iPad (`userInterfaceIdiom == .pad`).
  - Al tocarlo aparece la paleta. Al tocarlo otra vez desaparece.
  - Se recuerda la última herramienta y el último color.
- **Con la paleta visible** solo el Pencil marca. El dedo sigue desplazando, pasando páginas y seleccionando.
- **Con la paleta oculta** el Pencil se comporta como hoy.
- *Decisión mía:* se activa con un botón y no automáticamente al tocar con el lápiz, para que nunca marque sin querer.

### La paleta

- Es una cápsula flotante centrada abajo, encima de los controles inferiores del lector. Mientras lees, el lector ya oculta el menú principal, y eso no cambia.
```
┌─────────────────────────────────────────────┐
│ [▓ Texto] [✒︎ Pluma] [🖍 Marcador] [⌫]  ✕   │
│  ● ● ● ● ●   ━ ━━ ━━━                       │
└─────────────────────────────────────────────┘
```
- **Colores de Texto y Marcador:** las 5 categorías de destacados con sus colores actuales: Idea principal (azul), Duda (morado), Evidencia (verde), Acción (naranja) y Cita (rosa).
- **Colores de la Pluma:** esos 5 más negro.
- **Grosor:** 3 opciones para Pluma y Marcador. No aplica al resaltador de texto.
- En EPUB y texto solo aparece "Texto" con sus colores. Las demás herramientas no se muestran.

### Resaltador de texto (A)

- Pasas el Pencil sobre las palabras. Mientras dibujas se ve una sombra provisional. Al levantar el lápiz, las palabras entre el inicio y el final del trazo se convierten en un destacado de la categoría elegida.
- No aparece ningún menú intermedio.
- **El destacado es idéntico a los que se crean hoy con el dedo:**
  - el mismo modelo `Highlight`;
  - el mismo anchor y el mismo color;
  - aparece en Notas;
  - se puede editar o borrar con el flujo actual;
  - entra en la búsqueda y en la copia de seguridad.
- Si el trazo no cae sobre texto, no se crea nada.
- **Por formato:**
  - **PDF y presentaciones:** las palabras salen de la selección de PDFKit entre los dos puntos del trazo.
  - **EPUB:** la selección se calcula dentro de la página web del libro a partir de los puntos del trazo y se guarda con el localizador de Readium, como hoy.
  - **Texto y Markdown:** requiere cambiar cómo se dibuja el texto, porque hoy no se puede saber qué letra hay bajo el lápiz. Es la parte más delicada y va al final.

### Trazo libre (B), solo PDF y presentaciones

- **Pluma:** línea opaca. **Marcador:** línea ancha y semitransparente, como un resaltador físico.
- **Borrador:** borra el trazo completo que toca.
- Los trazos van pegados a cada página. Siguen en su lugar al hacer zoom, desplazarse o girar el iPad.
- **Guardado** (decisión mía):
  - local, en un archivo por documento con los trazos de cada página;
  - se borra cuando se borra el documento;
  - no entra en la copia de seguridad ni en Notas, porque no es texto.
  - Se puede añadir a la copia de seguridad más adelante.

## Entregas

Hay tres entregas, cada una en su rama y su PR, probadas en el iPad antes de fusionar:
1. **PDF y presentaciones:** paleta, resaltador de texto, pluma, marcador y borrador.
2. **EPUB:** resaltador de texto.
3. **Texto y Markdown:** resaltador de texto, incluido el cambio en cómo se muestra el texto.

## Restricciones

- Swift 6 con concurrencia estricta, SwiftUI, iOS 18.0 y PencilKit para el trazo libre.
- Solo se aceptan toques del Pencil para marcar (`allowedTouchTypes = [.pencil]` / `drawingPolicy = .pencilOnly`).
- Pruebas automáticas para la lógica pura:
  - estado de la paleta (herramientas disponibles por formato, color y grosor recordados);
  - del trazo a la selección de texto;
  - guardado y carga de los trazos por página.
- Las pruebas corren en el iPhone. La revisión visual y con el lápiz, en el iPad Pro 11" M2.

## Decisiones que quedan al implementador

- El aspecto exacto de la sombra provisional mientras se dibuja con el resaltador de texto.
- Cómo se integra PencilKit con PDFKit. Lo previsible es `PDFPageOverlayViewProvider` con un `PKCanvasView` por página.
- Cómo se obtiene la selección en el EPUB: por JavaScript en la página web del libro o con la API de selección de Readium.
- El formato del archivo de trazos, por ejemplo los datos de `PKDrawing` por índice de página.
