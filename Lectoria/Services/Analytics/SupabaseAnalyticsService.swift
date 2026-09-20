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
    private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Analytics")

    public init(
        container: ModelContainer,
        authService: any AuthService,
        supabaseURL: String,
        anonKey: String,
        privacyManager: AnalyticsPrivacyManager = .shared
    ) {
        self.modelContainer = container
        self.authService = authService
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.privacyManager = privacyManager

        // Despachar eventos acumulados en cola al iniciar
        Task.detached(priority: .background) {
            await self.flush()
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

            // Despachar en segundo plano
            await self.flush()
        }
    }

    /// Lee los eventos acumulados en la cola local de SwiftData y los envía por lotes a Supabase.
    public func flush() async {
        guard privacyManager.isAnalyticsEnabled else { return }

        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<AnalyticsModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 50

        guard let models = try? context.fetch(descriptor), !models.isEmpty else { return }

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

        guard !payload.isEmpty else { return }

        let isSuccess = await sendBatchToSupabase(payload)

        if isSuccess {
            // Eliminar eventos enviados exitosamente de la cola local
            for model in models {
                context.delete(model)
            }
            try? context.save()
            logger.info("✅ Despachados \(models.count) eventos de analítica a Supabase.")
        } else {
            // Incrementar contador de reintentos
            for model in models {
                model.retryCount += 1
                // Si ha fallado más de 10 veces, eliminar para no saturar la base local
                if model.retryCount > 10 {
                    context.delete(model)
                }
            }
            try? context.save()
            logger.warning("⚠️ Reintento de envío de analítica programado. Lote retenido en cola local.")
        }
    }

    private func sendBatchToSupabase(_ payload: [[String: Any]]) async -> Bool {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/analytics_events") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("lectoria-ios/1.0", forHTTPHeaderField: "X-Client-Info")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { return false }
            if (200...299).contains(httpResponse.statusCode) {
                return true
            } else {
                let errorStr = String(data: data, encoding: .utf8) ?? "desconocido"
                logger.error("❌ Fallo en envío de analítica REST (\(httpResponse.statusCode)): \(errorStr)")
                return false
            }
        } catch {
            logger.error("❌ Error de red en analítica: \(error.localizedDescription)")
            return false
        }
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
