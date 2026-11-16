import Foundation
import SwiftData
import os

// MARK: - SupabaseAnalyticsService

/// Implementación aislada del servicio de analítica de producto con soporte offline-first mediante SwiftData.
public final class SupabaseAnalyticsService: AnalyticsService, @unchecked Sendable {
    public let currentSessionID: UUID = UUID()

    private let modelContainer: ModelContainer
    private let authService: any AuthService
    private let supabaseURL: String
    private let anonKey: String
    private let privacyManager: AnalyticsPrivacyManager
    public let coordinator: AnalyticsFlushCoordinator
    public let transport: any AnalyticsNetworkTransport
    private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Analytics")

    public init(
        container: ModelContainer,
        authService: any AuthService,
        supabaseURL: String,
        anonKey: String,
        privacyManager: AnalyticsPrivacyManager = .shared,
        coordinator: AnalyticsFlushCoordinator = AnalyticsFlushCoordinator(),
        transport: any AnalyticsNetworkTransport = URLSessionAnalyticsTransport(),
        flushesOnInit: Bool = true
    ) {
        self.modelContainer = container
        self.authService = authService
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.privacyManager = privacyManager
        self.coordinator = coordinator
        self.transport = transport

        // Despachar eventos acumulados en cola al iniciar
        // (desactivable en pruebas para evitar carreras con flushes controlados)
        if flushesOnInit {
            Task.detached(priority: .background) {
                await self.flush()
            }
        }
    }

    deinit {
        Task { [coordinator] in
            await coordinator.cancelScheduledRetry()
        }
    }

    /// Registra un evento de analítica. Sanitiza las propiedades y las encola localmente o envía de inmediato.
    public func track(_ name: AnalyticsEventName, properties: [String: Any] = [:]) {
        guard privacyManager.isAnalyticsEnabled else { return }

        let sanitizedProps = PropertySanitizer.sanitize(properties, for: name)
        let installationID = AnonymousIdentityManager.shared.installationID
        let userID = authService.currentUser?.id
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceFamily = "iPhone"

        let record = AnalyticsEventRecord(
            sessionID: currentSessionID,
            installationID: installationID,
            userID: userID,
            eventName: name,
            properties: sanitizedProps,
            appVersion: appVersion,
            osVersion: osVersion,
            deviceFamily: deviceFamily,
            clientTimestamp: Date()
        )

        // Encolar en SwiftData de forma asíncrona sin bloquear el hilo principal
        Task.detached(priority: .utility) { [container = self.modelContainer] in
            let context = ModelContext(container)
            let model = AnalyticsModel.fromDomain(record)
            context.insert(model)
            try? context.save()

            // Despachar en segundo plano respetando la cadencia y reintentos
            await self.flush()
        }
    }

    /// Lee los eventos acumulados en la cola local de SwiftData y los envía por lotes a Supabase.
    public func flush() async {
        _ = await flush(force: false)
    }

    /// Lee los eventos acumulados en la cola local de SwiftData con opción de forzar el despacho ignorando la cadencia.
    @discardableResult
    public func flush(force: Bool) async -> Bool {
        guard privacyManager.isAnalyticsEnabled else { return false }

        // Si se fuerza el despacho, cancelar cualquier reintento automático previo para evitar colisiones
        if force {
            await coordinator.cancelScheduledRetry()
        }

        // Evitar ejecuciones concurrentes o envíos antes de cumplir la espera progresiva / intervalo mínimo
        guard await coordinator.shouldProceedWithFlush(force: force) else { return false }

        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<AnalyticsModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 50

        guard let models = try? context.fetch(descriptor), !models.isEmpty else {
            await coordinator.recordSuccess(minInterval: 0)
            // No descartar solicitudes llegadas mientras este ciclo veía la cola vacía:
            // el evento recién encolado quedaría retenido hasta el próximo track() o reinicio.
            if await coordinator.hasPendingFlushRequest {
                await coordinator.scheduleFollowUpFlush { [weak self] in
                    await self?.flush()
                }
            }
            return true
        }

        let payload: [[String: Any]] = models.compactMap { m in
            guard let record = m.toDomain() else { return nil }
            var dict: [String: Any] = [
                "id": record.id.uuidString.lowercased(),
                "session_id": record.sessionID.uuidString.lowercased(),
                "installation_id": record.installationID.uuidString.lowercased(),
                "event_name": record.eventName.rawValue,
                "properties": record.properties,
                "app_version": record.appVersion,
                "os_version": record.osVersion,
                "device_family": record.deviceFamily,
                "client_timestamp": ISO8601DateFormatter().string(from: record.clientTimestamp)
            ]
            if let uid = record.userID {
                dict["user_id"] = uid
            }
            return dict
        }

        guard !payload.isEmpty else {
            await coordinator.recordSuccess(minInterval: 0)
            if await coordinator.hasPendingFlushRequest {
                await coordinator.scheduleFollowUpFlush { [weak self] in
                    await self?.flush()
                }
            }
            return true
        }

        let isSuccess = await sendBatchToSupabase(payload)

        if isSuccess {
            await coordinator.recordSuccess()
            await coordinator.cancelScheduledRetry()
            // Eliminar eventos enviados exitosamente de la cola local
            for model in models {
                context.delete(model)
            }
            try? context.save()
            if transport.isSimulated {
                logger.info("🧪 [Transporte Simulado] Despachados exitosamente \(models.count) eventos de analítica de prueba.")
            } else {
                logger.info("✅ Despachados \(models.count) eventos de analítica a Supabase.")
            }

            // Comprobar si quedaron eventos remanentes en cola o si entraron nuevos mientras este envío estaba en vuelo
            let remainingDescriptor = FetchDescriptor<AnalyticsModel>()
            let remainingCount = (try? context.fetchCount(remainingDescriptor)) ?? 0
            let hasPendingRequest = await coordinator.hasPendingFlushRequest

            if remainingCount > 0 || hasPendingRequest {
                await coordinator.scheduleFollowUpFlush { [weak self] in
                    await self?.flush()
                }
            }
            return true
        } else {
            let backoffDelay = await coordinator.recordFailure()
            // Incrementar contador de reintentos con fines de observabilidad/telemetría.
            // IMPORTANTE: NO se eliminan los eventos aunque retryCount supere 10,
            // garantizando su conservación durante caídas prolongadas de backend o fallos de DNS.
            for model in models {
                model.retryCount += 1
            }
            try? context.save()
            if transport.isSimulated {
                logger.warning("🧪 [Transporte Simulado] Fallo simulado en analítica (reintento programado en \(Int(backoffDelay))s). Lote retenido.")
            } else {
                logger.warning("⚠️ Reintento de envío de analítica programado en \(Int(backoffDelay))s. Lote retenido en cola local.")
            }

            // Programar reintento automático al finalizar el backoff, incluso si no se registra otro evento.
            await coordinator.scheduleRetry(delay: backoffDelay) { [weak self] in
                await self?.flush()
            }
            return true
        }
    }

    private func sendBatchToSupabase(_ payload: [[String: Any]]) async -> Bool {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/analytics_events") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("lectoria-ios/1.0", forHTTPHeaderField: "X-Client-Info")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await transport.send(request: request)

            guard let httpResponse = response as? HTTPURLResponse else { return false }
            if (200...299).contains(httpResponse.statusCode) {
                return true
            } else {
                let errorStr = String(data: data, encoding: .utf8) ?? "desconocido"
                if transport.isSimulated {
                    logger.warning("🧪 [Transporte Simulado] Respuesta HTTP \(httpResponse.statusCode): \(errorStr)")
                } else {
                    logger.error("❌ Fallo en envío de analítica REST (\(httpResponse.statusCode)): \(errorStr)")
                }
                return false
            }
        } catch {
            if transport.isSimulated {
                logger.warning("🧪 [Transporte Simulado] Error de red simulado: \(error.localizedDescription)")
            } else {
                logger.error("❌ Error de red en analítica: \(error.localizedDescription)")
            }
            return false
        }
    }
}

// MARK: - AnalyticsNetworkTransport

/// Abstracción del transporte de red para permitir pruebas deterministas ante fallos de conectividad o DNS.
public protocol AnalyticsNetworkTransport: Sendable {
    func send(request: URLRequest) async throws -> (Data, URLResponse)
    var isSimulated: Bool { get }
}

extension AnalyticsNetworkTransport {
    public var isSimulated: Bool { false }
}

/// Implementación estándar de transporte basada en URLSession.
public struct URLSessionAnalyticsTransport: AnalyticsNetworkTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

// MARK: - AnalyticsSleepProvider

/// Proveedor de temporización y suspensión asíncrona desacoplado para evitar pruebas dependientes de sleeps fijos.
public protocol AnalyticsSleepProvider: Sendable {
    func sleep(seconds: TimeInterval) async throws
    var now: Date { get }
}

public struct SystemAnalyticsSleepProvider: AnalyticsSleepProvider {
    public init() {}
    public var now: Date { Date() }
    public func sleep(seconds: TimeInterval) async throws {
        if seconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
}

// MARK: - AnalyticsBackoffPolicy

/// Política de espera progresiva (exponential backoff) y limitación de frecuencia para el despacho de analítica.
public struct AnalyticsBackoffPolicy: Sendable {
    public static let baseDelay: TimeInterval = 5.0
    public static let maxDelay: TimeInterval = 300.0
    public static let maxExponent: Int = 6
    public static let minimumFlushInterval: TimeInterval = 2.0

    public static let `default` = AnalyticsBackoffPolicy()

    public let baseDelayValue: TimeInterval
    public let maxDelayValue: TimeInterval
    public let maxExponentValue: Int
    public let minimumFlushInterval: TimeInterval

    public init(
        baseDelay: TimeInterval = AnalyticsBackoffPolicy.baseDelay,
        maxDelay: TimeInterval = AnalyticsBackoffPolicy.maxDelay,
        maxExponent: Int = AnalyticsBackoffPolicy.maxExponent,
        minimumFlushInterval: TimeInterval = AnalyticsBackoffPolicy.minimumFlushInterval
    ) {
        self.baseDelayValue = baseDelay
        self.maxDelayValue = maxDelay
        self.maxExponentValue = maxExponent
        self.minimumFlushInterval = minimumFlushInterval
    }

    /// Calcula la espera progresiva en segundos según el número de fallos consecutivos usando la configuración por defecto.
    public static func delay(forConsecutiveFailures failures: Int) -> TimeInterval {
        AnalyticsBackoffPolicy.default.delay(forConsecutiveFailures: failures)
    }

    /// Calcula la espera progresiva en segundos según el número de fallos consecutivos configurado para esta política.
    public func delay(forConsecutiveFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        let exponent = min(failures - 1, maxExponentValue)
        let computed = baseDelayValue * pow(2.0, Double(exponent))
        return min(maxDelayValue, computed)
    }
}

// MARK: - AnalyticsFlushCoordinator

/// Coordina la concurrencia y la cadencia de reintentos del servicio de analítica para evitar peticiones duplicadas y saturación.
public actor AnalyticsFlushCoordinator {
    public private(set) var isFlushing: Bool = false
    public private(set) var consecutiveFailures: Int = 0
    public private(set) var nextAllowedAttemptDate: Date = .distantPast
    public private(set) var isRetryScheduled: Bool = false
    public private(set) var hasPendingFlushRequest: Bool = false

    public let policy: AnalyticsBackoffPolicy
    private let sleepProvider: any AnalyticsSleepProvider
    private var scheduledRetryTask: Task<Void, Never>?
    private var retryGeneration: UInt64 = 0

    public init(
        policy: AnalyticsBackoffPolicy = .default,
        sleepProvider: any AnalyticsSleepProvider = SystemAnalyticsSleepProvider()
    ) {
        self.policy = policy
        self.sleepProvider = sleepProvider
    }

    /// Determina si un nuevo ciclo de `flush()` puede proceder según la política de cadencia y estado de ejecución actual.
    public func shouldProceedWithFlush(now: Date = Date(), force: Bool = false) async -> Bool {
        if force {
            cancelScheduledRetry()
            while isFlushing {
                // Si la tarea llamante fue cancelada, Task.sleep lanza de inmediato;
                // salir aquí evita un bucle activo que giraría sin ceder el hilo.
                if Task.isCancelled { return false }
                do {
                    try await Task.sleep(nanoseconds: 5_000_000)
                } catch {
                    return false
                }
            }
        } else {
            guard !isFlushing else {
                hasPendingFlushRequest = true
                return false
            }
            // Margen de tolerancia de 2ms para evitar rechazos por redondeo de temporizadores del sistema
            if now < nextAllowedAttemptDate.addingTimeInterval(-0.002) {
                return false
            }
        }
        isFlushing = true
        hasPendingFlushRequest = false
        return true
    }

    /// Registra un despacho exitoso, reseteando el contador de fallos y aplicando el intervalo mínimo de enfriamiento.
    public func recordSuccess(now: Date = Date(), minInterval: TimeInterval? = nil) {
        isFlushing = false
        consecutiveFailures = 0
        let interval = minInterval ?? policy.minimumFlushInterval
        nextAllowedAttemptDate = now.addingTimeInterval(interval)
        cancelScheduledRetry()
    }

    /// Registra un fallo de despacho, actualizando el contador y calculando la próxima fecha permitida mediante espera progresiva.
    @discardableResult
    public func recordFailure(now: Date = Date()) -> TimeInterval {
        isFlushing = false
        consecutiveFailures += 1
        let delay = policy.delay(forConsecutiveFailures: consecutiveFailures)
        nextAllowedAttemptDate = now.addingTimeInterval(delay)
        return delay
    }

    /// Comprueba si el reintento despertó antes de tiempo y calcula el tiempo restante.
    public func checkPrematureWakeup(generation: UInt64, now: Date = Date()) -> (shouldSleep: Bool, remaining: TimeInterval) {
        guard generation == self.retryGeneration else { return (false, 0) }
        let remaining = nextAllowedAttemptDate.timeIntervalSince(now)
        if remaining > 0.002 {
            return (true, remaining)
        }
        return (false, 0)
    }

    /// Marca el reintento como activado asegurando que coincide con la generación actual.
    @discardableResult
    public func markRetryTriggered(generation: UInt64) -> Bool {
        guard generation == self.retryGeneration else { return false }
        isRetryScheduled = false
        scheduledRetryTask = nil
        return true
    }

    /// Marca el reintento como terminado o cancelado asegurando que coincide con la generación actual.
    public func markRetryFinished(generation: UInt64) {
        guard generation == self.retryGeneration else { return }
        isRetryScheduled = false
        scheduledRetryTask = nil
    }

    /// Programa la ejecución de una operación de reintento con control de generación y prevención de pérdidas por despertar prematuro.
    public func scheduleRetry(
        delay: TimeInterval,
        operation: @escaping @Sendable () async -> Void
    ) {
        retryGeneration += 1
        let currentGeneration = retryGeneration
        scheduledRetryTask?.cancel()
        isRetryScheduled = true

        let currentSleepProvider = self.sleepProvider

        scheduledRetryTask = Task { [weak self, currentSleepProvider, currentGeneration] in
            // Si el temporizador despierta antes de finalizar la ventana, vuelve a suspender por el remanente
            while !Task.isCancelled {
                guard let coordinator = self else { return }
                let (shouldSleep, remaining) = await coordinator.checkPrematureWakeup(
                    generation: currentGeneration,
                    now: currentSleepProvider.now
                )
                if !shouldSleep {
                    break
                }
                do {
                    try await currentSleepProvider.sleep(seconds: remaining)
                } catch {
                    await self?.markRetryFinished(generation: currentGeneration)
                    return
                }
            }

            guard !Task.isCancelled else {
                await self?.markRetryFinished(generation: currentGeneration)
                return
            }

            guard let coordinator = self else { return }
            let isCurrent = await coordinator.markRetryTriggered(generation: currentGeneration)
            if isCurrent {
                await operation()
            }
        }
    }

    /// Programa el despacho continuo de eventos que quedaron en cola o ingresaron durante un envío previo.
    public func scheduleFollowUpFlush(
        delay: TimeInterval? = nil,
        operation: @escaping @Sendable () async -> Void
    ) {
        let interval = delay ?? policy.minimumFlushInterval
        scheduleRetry(delay: interval, operation: operation)
    }

    /// Cancela de inmediato cualquier reintento automático programado, invalidando generaciones previas.
    public func cancelScheduledRetry() {
        retryGeneration += 1
        scheduledRetryTask?.cancel()
        scheduledRetryTask = nil
        isRetryScheduled = false
    }

    /// Permite reiniciar el estado del coordinador (útil para pruebas unitarias).
    public func reset() {
        cancelScheduledRetry()
        isFlushing = false
        consecutiveFailures = 0
        hasPendingFlushRequest = false
        nextAllowedAttemptDate = .distantPast
    }
}

// MARK: - MockAnalyticsService

public final class MockAnalyticsService: AnalyticsService, @unchecked Sendable {
    public let currentSessionID: UUID = UUID()
    public private(set) var trackedEvents: [(name: AnalyticsEventName, properties: [String: Any])] = []

    public init() {}

    public func track(_ name: AnalyticsEventName, properties: [String: Any]) {
        trackedEvents.append((name, properties))
    }

    public func flush() async {}
}
