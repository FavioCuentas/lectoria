import XCTest

// MARK: - StoreScreenshotsUITests

/// Genera las capturas para App Store a partir de contenido de ejemplo.
/// Solo corre si se define SCREENSHOT_DIR (carpeta del Mac donde guardar los PNG) y
/// DEMO_DIR (carpeta con los EPUB de ejemplo). Ejemplo:
///   TEST_RUNNER_SCREENSHOT_DIR=/ruta TEST_RUNNER_DEMO_DIR=/ruta xcodebuild test \
///     -only-testing:LectoriaUITests/StoreScreenshotsUITests ...
final class StoreScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL!
    private var demoDir: URL!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["SCREENSHOT_DIR"], let demo = env["DEMO_DIR"] else {
            throw XCTSkip("Define SCREENSHOT_DIR y DEMO_DIR para generar capturas.")
        }
        continueAfterFailure = true
        outDir = URL(fileURLWithPath: out)
        demoDir = URL(fileURLWithPath: demo)
        app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(es)", "-AppleLocale", "es_BO"]
        app.launch()
    }

    private func shot(_ name: String) {
        sleep(1)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: outDir.appendingPathComponent("\(name).png"))
    }

    private func dump(_ name: String) {
        try? app.debugDescription.write(to: outDir.appendingPathComponent("\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func backToRoot() {
        for _ in 0..<3 {
            let back = app.buttons["chevron.left"]
            guard back.exists else { return }
            back.tap()
            sleep(1)
        }
    }

    private func importDemo() throws {
        let files = try FileManager.default.contentsOfDirectory(at: demoDir, includingPropertiesForKeys: nil)
            .filter { ["epub"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in files {
            app.open(file)
            sleep(4)
            backToRoot()
        }
        let text = "La fotosíntesis es el proceso por el cual las plantas, las algas y algunas bacterias transforman la energía de la luz en energía química.\n\nOcurre en los cloroplastos y tiene dos fases. En la fase luminosa, la clorofila capta la luz y se rompe el agua, liberando oxígeno. En la fase oscura, o ciclo de Calvin, el dióxido de carbono se fija para formar glucosa.\n\nImportancia: produce el oxígeno que respiramos y es la base de casi todas las cadenas alimentarias."
        var c = URLComponents(string: "lectoria://import-text")!
        c.queryItems = [URLQueryItem(name: "title", value: "Resumen: la fotosíntesis"), URLQueryItem(name: "text", value: text)]
        app.open(c.url!)
        sleep(4)
        backToRoot()
    }

    /// Mantiene pulsada la palabra en `start` y arrastra el tirador final hasta `end`
    /// (coordenadas normalizadas dentro del lector).
    private func select(in web: XCUIElement, start: CGVector, handle: CGVector, end: CGVector) {
        web.coordinate(withNormalizedOffset: start).press(forDuration: 1.2)
        sleep(1)
        web.coordinate(withNormalizedOffset: handle)
            .press(forDuration: 0.4, thenDragTo: web.coordinate(withNormalizedOffset: end))
        sleep(1)
    }

    /// En iPhone las pestañas están en la barra inferior; en iPad pueden estar arriba o en la barra lateral.
    private func openTab(_ name: String) {
        _ = app.buttons[name].waitForExistence(timeout: 3)
        // Puede haber copias ocultas con la misma etiqueta: se pulsa la que está visible.
        for query in [app.tabBars.buttons, app.buttons, app.cells] {
            if let element = query.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex.first(where: { $0.isHittable }) {
                element.tap()
                return
            }
        }
        dump("tab-missing-\(name)")
    }

    private var colorButtons: [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.frame.minY > 600 && $0.frame.width > 30 && $0.frame.width < 60 }
    }

    func testStoreScreenshots() throws {
        try importDemo()
        dump("start")

        // 1. Biblioteca con portadas
        openTab("Biblioteca")
        sleep(2)
        shot("01-biblioteca")

        // 2. Lector con resaltados y el menú de estudio
        let cell = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Biolog'")).firstMatch
        if cell.waitForExistence(timeout: 5) { cell.tap() }
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.waitForExistence(timeout: 10))
        sleep(4)
        // Posiciones del texto en el lector (normalizadas): distintas en iPhone y en iPad.
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let p1 = pad ? (CGVector(dx: 0.061, dy: 0.129), CGVector(dx: 0.071, dy: 0.139), CGVector(dx: 0.11, dy: 0.219))
                     : (CGVector(dx: 0.11, dy: 0.258), CGVector(dx: 0.13, dy: 0.273), CGVector(dx: 0.45, dy: 0.43))
        let p2 = pad ? (CGVector(dx: 0.07, dy: 0.215), CGVector(dx: 0.097, dy: 0.225), CGVector(dx: 0.233, dy: 0.306))
                     : (CGVector(dx: 0.14, dy: 0.395), CGVector(dx: 0.265, dy: 0.412), CGVector(dx: 0.62, dy: 0.555))
        let p3 = pad ? (CGVector(dx: 0.15, dy: 0.405), CGVector(dx: 0.168, dy: 0.415), CGVector(dx: 0.21, dy: 0.457))
                     : (CGVector(dx: 0.33, dy: 0.74), CGVector(dx: 0.395, dy: 0.757), CGVector(dx: 0.56, dy: 0.835))
        select(in: web, start: p1.0, handle: p1.1, end: p1.2)
        dump("sel1"); shot("debug-sel1")
        if let c = colorButtons.first { c.tap() }
        sleep(1)
        select(in: web, start: p2.0, handle: p2.1, end: p2.2)
        let colors = colorButtons
        if colors.count > 2 { colors[2].tap() } else { colors.first?.tap() }
        sleep(1)
        // Frase sobre las mitocondrias, con el menú de estudio abierto.
        select(in: web, start: p3.0, handle: p3.1, end: p3.2)
        sleep(1)
        shot("02-lector")

        // 3. Asistente de IA
        let ia = app.buttons["IA"]
        if ia.waitForExistence(timeout: 3) {
            ia.tap()
            let explain = app.buttons["Crear preguntas"]
            if explain.waitForExistence(timeout: 3) { explain.tap() }
            sleep(4)
            dump("ia"); shot("03-ia")
        }
        // Cerrar hoja de IA si quedó abierta
        app.swipeDown(velocity: .fast)
        sleep(1)
        backToRoot()

        // 4. Notas
        openTab("Notas")
        sleep(2)
        dump("notas"); shot("04-notas")

        // 5. Inicio
        openTab("Inicio")
        sleep(2)
        shot("05-inicio")

        // 6. Planes
        openTab("Perfil")
        sleep(1)
        let plan = app.staticTexts["Plan de suscripción"]
        if plan.waitForExistence(timeout: 3) { plan.tap() }
        sleep(3)
        dump("planes"); shot("06-planes")
    }
}
