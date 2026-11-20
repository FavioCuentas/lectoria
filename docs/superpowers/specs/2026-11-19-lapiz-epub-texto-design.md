# iPad: marcar con el Pencil en EPUB y texto (diseño)

Fecha: 19-11-2026. Continúa `2026-11-19-ipad-lapiz-design.md`, cuya entrega 1 (pluma, marcador y borrador en PDF) ya está fusionada.

## Intención

En el iPad, marcar texto con el Apple Pencil también en EPUB y en texto/Markdown. La paleta es la misma: solo íconos y, al mantener presionado, el color.

## Qué hace el Pencil

Solo con la paleta visible, y solo el Pencil. El dedo sigue pasando páginas, desplazándose y seleccionando igual que hoy.

- **Marcador:** pasas el lápiz sobre el texto y se crea un destacado normal del color o categoría elegidos. Aparece en Notas, entra en la búsqueda y en la copia de seguridad.
  - **EPUB:** se marcan las palabras entre el inicio y el final del trazo, ampliadas a palabras completas.
  - **Texto y Markdown:** se marcan **párrafos completos**, todos los que cruza el trazo, igual que hoy con el dedo. Lo decidió el usuario.
- **Borrador:** pasas el lápiz sobre un subrayado y se borra.
  - **EPUB:** se borran los destacados del capítulo actual cuyo texto se solapa con el texto del trazo.
  - **Texto y Markdown:** se borran los destacados de los párrafos que cruza el trazo.
- **Opciones del Marcador:** mantener presionado abre solo los 5 colores, porque el grosor no aplica al texto. El Borrador no tiene opciones.

## No objetivos

- Trazo libre (pluma) en EPUB y texto: el texto se reacomoda.
- Marcar palabras sueltas en el lector de texto: haría falta rehacer cómo se muestra.
- Cambios en el iPhone o en el menú principal.

## Decisiones técnicas

- **El reconocedor del trazo** es un `UIPanGestureRecognizer` que solo acepta el Pencil, y los demás gestos esperan a que falle (`shouldBeRequiredToFailBy`). Así, un toque del Pencil sin arrastrar sigue funcionando como siempre y el dedo no se ve afectado.
- **EPUB:** el punto del trazo se convierte en coordenadas de la página web. Con JavaScript (`caretRangeFromPoint`) se arma la selección y se amplía a palabras completas. Readium la recoge como `currentSelection`, con su localizador, y el destacado se crea igual que con el dedo.
- **Texto:** se usa el marco de cada párrafo dentro del contenido, y el gesto se monta con `UIGestureRecognizerRepresentable` (iOS 18).
- **Verificación:** la lógica pura tiene pruebas. El comportamiento real con el Pencil lo prueba el usuario en el iPad antes de la PR.
