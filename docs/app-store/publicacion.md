# Lectoria 1.0: guía de publicación en la App Store

Estado al 18-11-2026:
- La app compila en modo Release.
- Pasan las 256 pruebas en el iPhone.
- Lo que se puede resolver en el código ya está hecho (ver "Ya resuelto").

Lo que falta depende de tu cuenta de Apple, de tu dominio y de App Store Connect.

## 1. Bloqueantes (sin esto Apple rechaza o no deja subir la app)

| # | Qué | Por qué | Cómo |
|---|---|---|---|
| 1 | **Apple Developer Program de pago** (99 USD/año) | Con un equipo personal gratuito no se puede subir a la App Store ni a TestFlight. El código indica que hoy el equipo es personal: Sign in with Apple está desactivado porque esa cuenta no lo admite. | Inscribirse en developer.apple.com/programs con la misma cuenta del equipo `MJB9YK4S3T`. |
| 2 | **Iniciar sesión con Apple** | La app ofrece "Continuar con Google". La guía 4.8 de Apple exige ofrecer también un inicio de sesión equivalente que respete la privacidad, en la práctica Sign in with Apple. | Tras inscribirse: activar la capacidad, volver a añadir `com.apple.developer.applesignin` en `Lectoria.entitlements` y poner `isAppleSignInEnabled = true` en `AppEnvironment.swift`. Alternativa: quitar el inicio de sesión con Google. |
| 3 | **Política de privacidad y términos publicados** | La pantalla Premium enlaza a `https://lectoria.app/privacy` y `https://lectoria.app/terms`, y hoy esas direcciones no responden. Las apps con suscripción deben tener ambas páginas accesibles. | Publicar las dos páginas (sirve una web sencilla o páginas de Notion o GitHub Pages) y, si cambian las direcciones, actualizarlas en `PaywallView.swift`. |
| 4 | **Productos de compra en App Store Connect** | Las compras solo funcionan si existen con los mismos identificadores que usa la app. | Crear el grupo de suscripción con `com.lectoria.premium.founder` (anual, 4,99) y `com.lectoria.premium.yearly` (anual, 9,99), y la compra única `com.lectoria.premium.lifetime` (19,99). |
| 5 | **Capturas de pantalla de 6,9"** | App Store Connect exige capturas de iPhone de 6,9" (1320 × 2868). Las de tu iPhone (1206 × 2622) no sirven para ese tamaño. | Puedo generarlas desde el código con datos de ejemplo, o se pueden hacer en un iPhone Pro Max. |

## 2. Importante antes de enviar a revisión

- **Borrar la cuenta:** la app ya tiene "Eliminar cuenta" en Perfil (lo exige la guía 5.1.1). Comprobar con una cuenta de prueba que el servidor (Supabase) borra de verdad los datos.
- **Cuenta de prueba para Apple:** crear un correo y una contraseña de demostración con contenido, para que el revisor pueda entrar. Ver la sección 6.
- **TestFlight:** subir primero una versión de prueba (Xcode → Product → Archive → Distribute App → TestFlight) y probarla unos días con 3 a 5 personas.
- **Clasificación por edad:** responder el cuestionario. La app no tiene contenido sensible propio; los documentos los aporta el usuario.

## 3. Ya resuelto en el código

- La presentación de prueba ("Presentación Demo Lectoria") solo se crea en compilaciones de desarrollo, nunca en la versión de la tienda.
- El manifiesto de privacidad declara el contenido del usuario que se sincroniza: notas, destacados y progreso.
- "Abrir en Lectoria" aparece también para archivos PowerPoint.
- El progreso guarda el identificador real del dispositivo; antes guardaba un texto fijo de pruebas.
- Los documentos internos del proyecto y la configuración de compras de prueba ya no se incluyen en la app.
- Ya existían y se verificaron:
  - el manifiesto de privacidad (`PrivacyInfo.xcprivacy`);
  - la declaración de cifrado (`ITSAppUsesNonExemptEncryption = NO`);
  - el ícono de 1024 px;
  - la versión 1.0 (compilación 1).

## 4. Etiqueta de privacidad (App Store Connect → Privacidad de la app)

Respuestas según lo que la app realmente hace (coinciden con `PrivacyInfo.xcprivacy`):

| Dato | ¿Se recopila? | Vinculado a la persona | Uso | Rastreo |
|---|---|---|---|---|
| Correo electrónico | Sí, al crear cuenta | Sí | Funcionalidad de la app | No |
| ID de usuario | Sí | Sí | Funcionalidad de la app | No |
| Otro contenido del usuario (notas, destacados, progreso de lectura sincronizados) | Sí, con sesión iniciada | Sí | Funcionalidad de la app | No |
| Interacción con el producto (estadísticas de uso anónimas, desactivables en Perfil) | Sí | No | Analítica | No |

- **Archivos de los libros:** los documentos importados **no salen del teléfono**.
- **Búsqueda y estadísticas:** se calculan solo en el dispositivo.

## 5. Textos de la ficha (para copiar)

**Nombre** (máx. 30): `Lectoria`

**Subtítulo** (máx. 30): `Lee, subraya y estudia mejor`

**Texto promocional** (máx. 170):
> Lee EPUB, PDF, PowerPoint y texto en un solo lugar. Busca dentro de toda tu biblioteca, subraya, toma notas y sigue tu racha de lectura.

**Descripción:**
> Lectoria reúne tus libros y documentos en una biblioteca tranquila, pensada para leer y estudiar.
>
> LEE TODOS TUS FORMATOS
> • EPUB, PDF, PowerPoint, TXT y Markdown, o texto pegado.
> • Las presentaciones se abren como PDF, con su diseño original.
> • Temas claro, oscuro y sepia, y ajustes de lectura.
>
> ENCUENTRA CUALQUIER COSA
> • Busca en toda tu biblioteca: títulos, autores, el contenido de cada documento y tus notas.
> • Toca un resultado y el libro se abre justo en esa frase.
> • La búsqueda funciona sin conexión y no distingue acentos.
>
> ESTUDIA CON TUS PROPIAS NOTAS
> • Subraya con colores, añade notas y marcadores.
> • Encuentra todas tus notas en un solo lugar y vuelve a su página con un toque.
>
> TU HÁBITO DE LECTURA
> • Minutos leídos por día, meta semanal, racha y documentos terminados.
> • Sin notificaciones insistentes ni culpas: solo información.
>
> PRIVACIDAD
> • Tus documentos se quedan en tu teléfono.
> • La búsqueda y las estadísticas se calculan en el dispositivo.
>
> LECTORIA PREMIUM
> • Biblioteca sin límites (el plan gratuito incluye 5 documentos activos).
> • Notas, resaltados y herramientas de estudio sin límites.
> • Texto a voz y funciones avanzadas de lectura.
> • Hasta 3 dispositivos.
> Suscripción anual o compra única de por vida. La suscripción se renueva automáticamente salvo que la canceles al menos 24 horas antes del final del periodo, desde Ajustes de tu cuenta de Apple.
>
> Términos: https://lectoria.app/terms · Privacidad: https://lectoria.app/privacy

**Palabras clave** (máx. 100, separadas por comas, sin espacios):
`lector,epub,pdf,libros,leer,notas,subrayar,estudiar,biblioteca,powerpoint,ebook,lectura,resaltar`

**Categoría principal:** Libros. **Secundaria:** Educación.

**URL de soporte:** obligatoria; por ejemplo `https://lectoria.app/soporte` o un correo de contacto publicado en una página.

## 6. Notas para el revisor de Apple (App Review Information)

> Lectoria es un lector de documentos personales (EPUB, PDF, PowerPoint, TXT, Markdown). Para probarla:
> 1. Inicie sesión con la cuenta de demostración: [correo] / [contraseña], o continúe como invitado.
> 2. Biblioteca → botón + para importar un documento desde Archivos (la cuenta de demostración ya incluye algunos).
> 3. Escriba una palabra en el buscador de la Biblioteca para buscar dentro de los documentos.
> 4. Perfil → Estadísticas muestra el historial de lectura.
> Las compras Premium se pueden probar en el entorno sandbox.
