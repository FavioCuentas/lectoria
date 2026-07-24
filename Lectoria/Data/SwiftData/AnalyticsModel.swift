import Foundation
import SwiftData

// MARK: - AnalyticsModel

/// Modelo persistente de SwiftData para almacenar la cola local de eventos de analítica en modo offline.
@Model
public final class AnalyticsModel {
    @Attribute(.unique) public var id: UUID
    public var sessionID: UUID
    public var installationID: UUID
    public var userID: String?
    public var eventNameRaw: String
    public var propertiesJSON: String
    public var appVersion: String
    public var osVersion: String
    public var deviceFamily: String
    public var clientTimestamp: Date
    public var retryCount: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        installationID: UUID,
        userID: String? = nil,
        eventNameRaw: String,
        propertiesJSON: String,
        appVersion: String,
        osVersion: String,
        deviceFamily: String,
        clientTimestamp: Date,
        retryCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.installationID = installationID
        self.userID = userID
        self.eventNameRaw = eventNameRaw
        self.propertiesJSON = propertiesJSON
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceFamily = deviceFamily
        self.clientTimestamp = clientTimestamp
        self.retryCount = retryCount
        self.createdAt = createdAt
    }
}

extension AnalyticsModel {
    public func toDomain() -> AnalyticsEventRecord? {
        guard let name = AnalyticsEventName(rawValue: eventNameRaw) else { return nil }
        let dict = (try? JSONSerialization.jsonObject(with: Data(propertiesJSON.utf8)) as? [String: String]) ?? [:]
        return AnalyticsEventRecord(
            id: id,
            sessionID: sessionID,
            installationID: installationID,
            userID: userID,
            eventName: name,
            properties: dict,
            appVersion: appVersion,
            osVersion: osVersion,
            deviceFamily: deviceFamily,
            clientTimestamp: clientTimestamp
        )
    }

    public static func fromDomain(_ domain: AnalyticsEventRecord) -> AnalyticsModel {
        let json = (try? JSONSerialization.data(withJSONObject: domain.properties)) ?? Data()
        let jsonStr = String(data: json, encoding: .utf8) ?? "{}"
        return AnalyticsModel(
            id: domain.id,
            sessionID: domain.sessionID,
            installationID: domain.installationID,
            userID: domain.userID,
            eventNameRaw: domain.eventName.rawValue,
            propertiesJSON: jsonStr,
            appVersion: domain.appVersion,
            osVersion: domain.osVersion,
            deviceFamily: domain.deviceFamily,
            clientTimestamp: domain.clientTimestamp,
            retryCount: 0,
            createdAt: Date()
        )
    }
}
