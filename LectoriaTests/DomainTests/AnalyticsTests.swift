import Testing
import Foundation
import SwiftData
@testable import Lectoria

struct AnalyticsTests {
    @Test
    func testPropertySanitization() async throws {
        let rawProps: [String: Any] = [
            "format": "epub",
            "title": "Un libro secreto de prueba", // Clave prohibida
            "author": "Autor Anónimo", // Clave prohibida
            "text": "Contenido confidencial", // Clave prohibida
            "duration_seconds": 180,
            "has_cover": true
        ]

        let sanitized = PropertySanitizer.sanitize(rawProps)

        #expect(sanitized["format"] == "epub")
        #expect(sanitized["duration_seconds"] == "180")
        #expect(sanitized["has_cover"] == "true")

        // Verificar que las claves prohibidas se eliminaron por completo
        #expect(sanitized["title"] == nil)
        #expect(sanitized["author"] == nil)
        #expect(sanitized["text"] == nil)
    }

    @Test
    func testPropertyBucketing() async throws {
        #expect(PropertySanitizer.bucketFileSize(500_000) == "<1MB")
        #expect(PropertySanitizer.bucketFileSize(3_000_000) == "1-5MB")
        #expect(PropertySanitizer.bucketFileSize(20_000_000) == ">15MB")

        #expect(PropertySanitizer.bucketDuration(30) == "<1min")
        #expect(PropertySanitizer.bucketDuration(120) == "1-5min")
        #expect(PropertySanitizer.bucketDuration(2000) == ">30min")

        #expect(PropertySanitizer.bucketTextLength(10) == "<50_chars")
        #expect(PropertySanitizer.bucketTextLength(150) == "50-200_chars")
        #expect(PropertySanitizer.bucketTextLength(500) == "200-1000_chars")
        #expect(PropertySanitizer.bucketTextLength(2000) == ">1000_chars")
    }

    @Test
    func testAnonymousInstallationIDPersistence() async throws {
        let id1 = AnonymousIdentityManager.shared.installationID
        let id2 = AnonymousIdentityManager.shared.installationID

        // Debe ser consistente y persistir en Keychain
        #expect(id1 == id2)
    }

    @Test
    func testMockAnalyticsTracking() async throws {
        let mockService = MockAnalyticsService()

        mockService.track(.documentImported, properties: ["format": "pdf"])
        mockService.track(.paywallViewed, properties: ["trigger_source": "ai_limit"])

        #expect(mockService.trackedEvents.count == 2)
        #expect(mockService.trackedEvents[0].name == .documentImported)
        #expect(mockService.trackedEvents[0].properties["format"] as? String == "pdf")
        #expect(mockService.trackedEvents[1].name == .paywallViewed)
    }

    @Test
    func testAnalyticsBackoffPolicyCalculation() async throws {
        // Fallos = 0: sin espera
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 0) == 0.0)

        // Espera progresiva (base 5s, duplicándose hasta un tope de 300s)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 1) == 5.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 2) == 10.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 3) == 20.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 4) == 40.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 5) == 80.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 6) == 160.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 7) == 300.0)
        #expect(AnalyticsBackoffPolicy.delay(forConsecutiveFailures: 10) == 300.0)
    }

    @Test
    func testAnalyticsFlushCoordinatorPreventsConcurrentFlushes() async throws {
        let coordinator = AnalyticsFlushCoordinator()

        let firstAcquired = await coordinator.shouldProceedWithFlush()
        #expect(firstAcquired == true)
        let isFlushing = await coordinator.isFlushing
        #expect(isFlushing == true)

        // Segunda llamada concurrente debe ser rechazada
        let secondAcquired = await coordinator.shouldProceedWithFlush()
        #expect(secondAcquired == false)

        // Al registrar éxito, se libera el flag
        await coordinator.recordSuccess(minInterval: 0)
        let afterSuccessIsFlushing = await coordinator.isFlushing
        #expect(afterSuccessIsFlushing == false)
    }

    @Test
    func testAnalyticsFlushCoordinatorAppliesBackoffOnFailure() async throws {
        let coordinator = AnalyticsFlushCoordinator()
        let t0 = Date()

        let first = await coordinator.shouldProceedWithFlush(now: t0)
        #expect(first == true)

        // Registro de fallo: debe aplicar 5s de espera
        let delay = await coordinator.recordFailure(now: t0)
        #expect(delay == 5.0)
        let failures = await coordinator.consecutiveFailures
        #expect(failures == 1)

        // Intento dentro de la ventana de espera (t0 + 2s) debe ser rechazado
        let tSoon = t0.addingTimeInterval(2.0)
        let blocked = await coordinator.shouldProceedWithFlush(now: tSoon)
        #expect(blocked == false)

        // Intento forzado debe permitirse
        let forced = await coordinator.shouldProceedWithFlush(now: tSoon, force: true)
        #expect(forced == true)
        await coordinator.recordFailure(now: tSoon)

        // Intento tras expirar el retraso debe permitirse
        let tAfter = t0.addingTimeInterval(60.0)
        let allowed = await coordinator.shouldProceedWithFlush(now: tAfter)
        #expect(allowed == true)
    }

    @Test
    func testAnalyticsFlushCoordinatorResetsOnSuccess() async throws {
        let coordinator = AnalyticsFlushCoordinator()
        let now = Date()

        _ = await coordinator.shouldProceedWithFlush(now: now)
        _ = await coordinator.recordFailure(now: now)
        _ = await coordinator.shouldProceedWithFlush(now: now, force: true)
        _ = await coordinator.recordFailure(now: now)

        let twoFailures = await coordinator.consecutiveFailures
        #expect(twoFailures == 2)

        _ = await coordinator.shouldProceedWithFlush(now: now, force: true)
        await coordinator.recordSuccess(now: now, minInterval: 2.0)

        let resetFailures = await coordinator.consecutiveFailures
        #expect(resetFailures == 0)
    }

    @Test
    func testForcedFlushWaitExitsOnCancellationWithoutBusyLoop() async throws {
        let coordinator = AnalyticsFlushCoordinator()

        // Ocupar el candado de flush simulando un envío en vuelo que no termina
        let acquired = await coordinator.shouldProceedWithFlush()
        #expect(acquired == true)

        // Una espera forzada cancelada debe salir devolviendo false, no girar indefinidamente
        let waiter = Task {
            await coordinator.shouldProceedWithFlush(force: true)
        }
        waiter.cancel()
        let proceeded = await waiter.value
        #expect(proceeded == false, "La espera forzada cancelada debe abortar sin adquirir el candado")

        // El flush en vuelo no debe verse afectado por la cancelación del que esperaba
        let stillFlushing = await coordinator.isFlushing
        #expect(stillFlushing == true)
        await coordinator.recordSuccess(minInterval: 0)
    }

    @Test
    func testForcedFlushWaitsForInFlightFlushThenProceeds() async throws {
        let coordinator = AnalyticsFlushCoordinator()

        // Ocupar el candado de flush
        let acquired = await coordinator.shouldProceedWithFlush()
        #expect(acquired == true)

        let waiter = Task {
            await coordinator.shouldProceedWithFlush(force: true)
        }

        // Liberar el candado tras un breve retraso; la espera forzada debe proceder entonces
        try await Task.sleep(nanoseconds: 50_000_000)
        await coordinator.recordSuccess(minInterval: 0)

        let proceeded = await waiter.value
        #expect(proceeded == true, "La espera forzada debe proceder cuando el flush en vuelo termina")
        await coordinator.recordSuccess(minInterval: 0)
    }

    // MARK: - Pruebas de Comportamiento: Persistencia ante fallos DNS y Reintentos Autónomos

    @Test
    @MainActor
    func testEventsPreservedDuringPersistentDNSFailuresExceedingTenRetries() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let mockAuth = MockAuthService()
        let transport = MockAnalyticsTransport { _ in
            throw URLError(.dnsLookupFailed)
        }

        let coordinator = AnalyticsFlushCoordinator()
        let service = SupabaseAnalyticsService(
            container: container,
            authService: mockAuth,
            supabaseURL: "https://test.supabase.co",
            anonKey: "anon-key-test",
            coordinator: coordinator,
            transport: transport,
            flushesOnInit: false
        )

        // 1. Insertar evento en la cola local
        let context = ModelContext(container)
        let eventRecord = AnalyticsEventRecord(
            sessionID: UUID(),
            installationID: UUID(),
            userID: nil,
            eventName: .documentImported,
            properties: ["format": "pdf"],
            appVersion: "1.0.0",
            osVersion: "18.0",
            deviceFamily: "iPhone",
            clientTimestamp: Date()
        )
        context.insert(AnalyticsModel.fromDomain(eventRecord))
        try context.save()

        // Verificar que el evento existe inicialmente
        var models = try context.fetch(FetchDescriptor<AnalyticsModel>())
        #expect(models.count == 1)
        #expect(models.first?.retryCount == 0)

        // 2. Simular 15 caídas consecutivas por fallo de resolución DNS (superando el umbral de 10).
        // Contar por separado llamadas a flush, solicitudes de transporte y fallos persistidos.
        var flushCallsCount = 0
        let targetFailures = 15

        for attempt in 1...targetFailures {
            // Cancelar cualquier reintento automático previo para controlar el determinismo de cada intento
            await coordinator.cancelScheduledRetry()

            flushCallsCount += 1
            let executed = await service.flush(force: true)
            #expect(executed == true, "La llamada a flush #\(attempt) debió proceder con éxito")

            // Esperar que la solicitud sea procesada por el transporte mock
            let currentRequests = await transport.requestCount
            #expect(currentRequests == attempt, "MockAnalyticsTransport debió recibir exactamente \(attempt) solicitudes")

            // Cancelar el reintento automático programado tras este fallo para que no compita con el siguiente ciclo forzado
            await coordinator.cancelScheduledRetry()
        }

        // 3. Comprobar métricas contadas por separado
        let finalRequestsCount = await transport.requestCount
        #expect(flushCallsCount == 15, "Deben haberse registrado 15 llamadas a flush")
        #expect(finalRequestsCount == 15, "MockAnalyticsTransport debió realizar 15 solicitudes efectivas")

        // 4. Comprobar que el evento sigue almacenado después de más de 10 fallos efectivos (>10) y refleja exactamente 15
        models = try context.fetch(FetchDescriptor<AnalyticsModel>())
        #expect(models.count == 1, "El evento debe conservarse durante caídas de DNS sin ser eliminado por retryCount > 10")
        let persistedFailuresCount = models.first?.retryCount ?? 0
        #expect(persistedFailuresCount == 15, "El contador de reintentos debe reflejar 15 intentos")
        #expect(persistedFailuresCount > 10, "El contador de fallos persistidos debe superar 10 sin haber sido purgado")

        // 5. Simular recuperación de red / resolución de DNS exitosa en transporte simulado
        await transport.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        // 6. Despachar tras la recuperación
        await coordinator.cancelScheduledRetry()
        let recoveryExecuted = await service.flush(force: true)
        #expect(recoveryExecuted == true)

        // 7. Comprobar que el evento finalmente fue despachado y eliminado de la cola local
        models = try context.fetch(FetchDescriptor<AnalyticsModel>())
        #expect(models.isEmpty, "El evento debe eliminarse de la cola local únicamente tras un despacho exitoso")
    }

    @Test
    @MainActor
    func testScheduledRetryExecutesAutomaticallyWithoutNewEvents() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let mockAuth = MockAuthService()

        // Política acelerada para test unitario (base 300ms: margen para cambiar el handler antes del reintento)
        let fastPolicy = AnalyticsBackoffPolicy(
            baseDelay: 0.3,
            maxDelay: 0.5,
            minimumFlushInterval: 0.01
        )
        let coordinator = AnalyticsFlushCoordinator(policy: fastPolicy)

        let transport = MockAnalyticsTransport()
        // El primer intento fallará por resolución DNS
        await transport.setHandler { _ in
            throw URLError(.dnsLookupFailed)
        }

        let service = SupabaseAnalyticsService(
            container: container,
            authService: mockAuth,
            supabaseURL: "https://test.supabase.co",
            anonKey: "anon-key-test",
            coordinator: coordinator,
            transport: transport,
            flushesOnInit: false
        )

        // Insertar un evento en SwiftData
        let context = ModelContext(container)
        let record = AnalyticsEventRecord(
            sessionID: UUID(),
            installationID: UUID(),
            userID: nil,
            eventName: .readingSessionEnded,
            properties: ["duration": "120"],
            appVersion: "1.0.0",
            osVersion: "18.0",
            deviceFamily: "iPhone",
            clientTimestamp: Date()
        )
        context.insert(AnalyticsModel.fromDomain(record))
        try context.save()

        // Primer intento de flush (fallará con DNS lookup failed).
        // Nota: el flush de arranque del init puede estar en vuelo; esta llamada puede quedar
        // registrada como solicitud pendiente y despacharse como follow-up, por lo que las
        // comprobaciones se hacen por condición y no de forma síncrona.
        await service.flush()

        let firstRequestDone = await waitUntil(timeout: 2.0) {
            await transport.requestCount >= 1
        }
        #expect(firstRequestDone == true, "El primer intento de envío debió ejecutarse")
        var models = try context.fetch(FetchDescriptor<AnalyticsModel>())
        #expect(models.count == 1, "El evento debe retenerse en la cola tras el primer fallo de red")

        // Comprobar que el reintento ha sido PROGRAMADO en el coordinator
        let isScheduled = await waitUntil(timeout: 2.0) {
            await coordinator.isRetryScheduled
        }
        #expect(isScheduled == true, "Debe existir un reintento programado activo al finalizar el backoff")

        // Configurar el transporte para que la red responda con éxito en el reintento automático
        await transport.setHandler { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        // NO SE LLAMA A track() NI A flush()! Esperamos por condición hasta un plazo máximo
        let executed = await waitUntil(timeout: 2.0) {
            await transport.requestCount >= 2
        }

        #expect(executed == true, "El reintento debió ejecutarse automáticamente sin nuevos eventos")
        // La limpieza de la cola ocurre tras volver la respuesta; esperar por condición
        let queueCleared = await waitUntil(timeout: 2.0) { [container] in
            let checkContext = ModelContext(container)
            return ((try? checkContext.fetchCount(FetchDescriptor<AnalyticsModel>())) ?? -1) == 0
        }
        #expect(queueCleared == true, "El lote debió ser despachado y limpiado por el reintento programado")
        models = try context.fetch(FetchDescriptor<AnalyticsModel>())
        #expect(models.isEmpty, "El lote debió ser despachado y limpiado por el reintento programado")

        let retryStillScheduled = await coordinator.isRetryScheduled
        #expect(retryStillScheduled == false, "El reintento programado debe quedar inactivo tras el éxito")
        let failures = await coordinator.consecutiveFailures
        #expect(failures == 0, "Los fallos consecutivos deben resetearse a 0")
    }

    @Test
    @MainActor
    func testScheduledRetryCancellationOnSuccess() async throws {
        let coordinator = AnalyticsFlushCoordinator()
        let t0 = Date()

        // Simular fallo inicial para que programe un reintento
        _ = await coordinator.shouldProceedWithFlush(now: t0)
        let delay = await coordinator.recordFailure(now: t0)
        await coordinator.scheduleRetry(delay: delay) {
            // Operación dummy
        }

        let isScheduledBefore = await coordinator.isRetryScheduled
        #expect(isScheduledBefore == true)

        // Éxito posterior cancela cualquier reintento
        await coordinator.recordSuccess(now: t0)
        let isScheduledAfter = await coordinator.isRetryScheduled
        #expect(isScheduledAfter == false)
    }

    @Test
    @MainActor
    func testScheduledRetryDoesNotGetLostOnPrematureWakeup() async throws {
        // Sleep provider que simula despertar anticipadamente antes de completar la ventana de backoff
        actor PrematureWakeSleepProvider: AnalyticsSleepProvider {
            private(set) var sleepCalls: Int = 0
            nonisolated var now: Date { Date() }

            func sleep(seconds: TimeInterval) async throws {
                sleepCalls += 1
                // En la primera llamada simula despertar antes del 20% del tiempo para forzar la detección
                let fraction = (sleepCalls == 1) ? max(0.001, seconds * 0.1) : seconds
                try await Task.sleep(nanoseconds: UInt64(fraction * 1_000_000_000))
            }
        }

        let fastPolicy = AnalyticsBackoffPolicy(baseDelay: 0.04, minimumFlushInterval: 0.01)
        let sleepProvider = PrematureWakeSleepProvider()
        let coordinator = AnalyticsFlushCoordinator(policy: fastPolicy, sleepProvider: sleepProvider)

        let t0 = Date()
        _ = await coordinator.shouldProceedWithFlush(now: t0)
        let delay = await coordinator.recordFailure(now: t0)

        let tracker = TestExecutionTracker()
        await coordinator.scheduleRetry(delay: delay) {
            await tracker.mark()
        }

        // Esperar por condición que la operación termine
        let completed = await waitUntil(timeout: 2.0) {
            await tracker.isExecuted
        }

        #expect(completed == true, "La operación no debe perderse si el temporizador despierta antes de tiempo")
        let calls = await sleepProvider.sleepCalls
        #expect(calls >= 2, "El sleep provider debió recibir llamadas adicionales para completar la ventana restante")
    }

    @Test
    @MainActor
    func testCancellingPreviousRetryDoesNotCancelNewRetry() async throws {
        let coordinator = AnalyticsFlushCoordinator(
            policy: AnalyticsBackoffPolicy(baseDelay: 0.05, minimumFlushInterval: 0.01)
        )
        let t0 = Date()
        _ = await coordinator.shouldProceedWithFlush(now: t0)
        let delay = await coordinator.recordFailure(now: t0)

        let firstTracker = TestExecutionTracker()
        let secondTracker = TestExecutionTracker()

        // 1. Programar reintento 1
        await coordinator.scheduleRetry(delay: delay) {
            await firstTracker.mark()
        }

        let isScheduledFirst = await coordinator.isRetryScheduled
        #expect(isScheduledFirst == true)

        // 2. Programar reintento 2 de inmediato (debe cancelar el reintento 1 pero mantener activo el 2)
        await coordinator.scheduleRetry(delay: 0.02) {
            await secondTracker.mark()
        }

        let isScheduledSecond = await coordinator.isRetryScheduled
        #expect(isScheduledSecond == true, "El reintento 2 debe permanecer programado")

        // 3. Esperar que el reintento 2 se ejecute
        let executed = await waitUntil(timeout: 2.0) {
            await secondTracker.isExecuted
        }

        #expect(executed == true, "El reintento 2 debió completarse exitosamente")
        let firstRan = await firstTracker.isExecuted
        #expect(firstRan == false, "El reintento 1 no debió ejecutarse por haber sido cancelado")
    }

    @Test
    @MainActor
    func testContinuousDispatchOfPendingEventsWithoutNewTrack() async throws {
        let container = ModelContainerFactory.create(isStoredInMemoryOnly: true)
        let mockAuth = MockAuthService()
        let fastPolicy = AnalyticsBackoffPolicy(baseDelay: 0.05, minimumFlushInterval: 0.01)
        let coordinator = AnalyticsFlushCoordinator(policy: fastPolicy)
        let transport = MockAnalyticsTransport()

        let service = SupabaseAnalyticsService(
            container: container,
            authService: mockAuth,
            supabaseURL: "https://test.supabase.co",
            anonKey: "anon-key-test",
            coordinator: coordinator,
            transport: transport,
            flushesOnInit: false
        )

        // Insertar 2 eventos en la base de datos
        let context = ModelContext(container)
        for i in 1...2 {
            let record = AnalyticsEventRecord(
                sessionID: UUID(),
                installationID: UUID(),
                userID: nil,
                eventName: .documentOpened,
                properties: ["index": "\(i)"],
                appVersion: "1.0.0",
                osVersion: "18.0",
                deviceFamily: "iPhone",
                clientTimestamp: Date()
            )
            context.insert(AnalyticsModel.fromDomain(record))
        }
        try context.save()

        // Ejecutar flush inicial
        await service.flush()

        // Comprobar que ambos eventos se envían y despachan continuamente
        let allDispatched = await waitUntil(timeout: 2.0) { [container] in
            let checkContext = ModelContext(container)
            guard let count = try? checkContext.fetchCount(FetchDescriptor<AnalyticsModel>()) else { return false }
            return count == 0
        }

        #expect(allDispatched == true, "Todos los eventos pendientes deben despacharse continuamente sin necesidad de otro track()")
        let totalRequests = await transport.requestCount
        #expect(totalRequests >= 1)
    }
}

// MARK: - MockAnalyticsTransport

actor MockAnalyticsTransport: AnalyticsNetworkTransport {
    public nonisolated var isSimulated: Bool { true }
    private var handler: (@Sendable (URLRequest) throws -> (Data, URLResponse))?
    public private(set) var requestCount: Int = 0

    init(handler: (@Sendable (URLRequest) throws -> (Data, URLResponse))? = nil) {
        self.handler = handler
    }

    func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func send(request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1

        guard let handler else {
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }
        return try handler(request)
    }
}

// MARK: - Test Helpers

/// Rastreador concurrente seguro (actor) para verificar la ejecución de operaciones asíncronas en pruebas.
actor TestExecutionTracker {
    var executed: Bool = false
    func mark() { executed = true }
    var isExecuted: Bool { executed }
}

/// Espera de forma asíncrona a que se cumpla una condición hasta alcanzar un plazo máximo (evita sleeps ciegos fijos).
func waitUntil(
    timeout: TimeInterval = 2.0,
    pollingInterval: TimeInterval = 0.01,
    condition: @Sendable () async -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
    }
    return await condition()
}
