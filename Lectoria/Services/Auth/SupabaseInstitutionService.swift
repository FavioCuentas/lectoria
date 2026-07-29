import Foundation
import CryptoKit
import os

// MARK: - SupabaseInstitutionService

/// Implementación concreta de `InstitutionService` usando peticiones HTTPS seguras a Supabase API, Edge Functions y RPCs.
public final class SupabaseInstitutionService: InstitutionService, @unchecked Sendable {
    private let supabaseURL: String
    private let anonKey: String
    private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "InstitutionService")

    public init(supabaseURL: String, anonKey: String) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
    }

    private func applyHeaders(to request: inout URLRequest, bearerToken: String? = nil) {
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let token = bearerToken ?? anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("lectoria-ios/1.0", forHTTPHeaderField: "X-Client-Info")
    }

    public func validateDomain(email: String) async throws -> InstitutionInfo {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = trimmedEmail.components(separatedBy: "@")
        guard parts.count == 2, !parts[1].isEmpty else {
            throw InstitutionalAuthError.invalidEmail
        }

        let domain = parts[1]

        let queryURLString = "\(supabaseURL)/rest/v1/institution_domains?domain=eq.\(domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? domain)&select=domain,institution_id,institutions(id,name,slug,is_active,plan_type)&is_active=eq.true"
        guard let url = URL(string: queryURLString) else {
            throw InstitutionalAuthError.serviceError(message: "URL inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstitutionalAuthError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw InstitutionalAuthError.domainUnauthorized(domain: domain)
        }

        struct DomainLookupResponse: Codable {
            let domain: String
            let institutions: SupabaseInstitutionData?
        }

        struct SupabaseInstitutionData: Codable {
            let id: UUID
            let name: String
            let slug: String
            let is_active: Bool
            let plan_type: String
        }

        guard let records = try? JSONDecoder().decode([DomainLookupResponse].self, from: data),
              let record = records.first,
              let inst = record.institutions,
              inst.is_active else {
            throw InstitutionalAuthError.domainUnauthorized(domain: domain)
        }

        return InstitutionInfo(id: inst.id, name: inst.name, slug: inst.slug, planType: inst.plan_type)
    }

    public func inspectAccessCode(code: String) async throws -> InstitutionInfo {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else {
            throw InstitutionalAuthError.codeNotFound
        }

        let functionURLString = "\(supabaseURL)/functions/v1/validate-institution-code"
        guard let url = URL(string: functionURLString) else {
            throw InstitutionalAuthError.serviceError(message: "URL de función inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        let body = ["code": cleanCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstitutionalAuthError.networkError
        }

        struct EdgeFunctionResponse: Codable {
            let valid: Bool
            let errorCode: String?
            let message: String?
            let institution: EdgeInstitutionData?

            enum CodingKeys: String, CodingKey {
                case valid
                case errorCode = "error_code"
                case message
                case institution
            }
        }

        struct EdgeInstitutionData: Codable {
            let id: UUID
            let name: String
            let slug: String
            let planType: String?

            enum CodingKeys: String, CodingKey {
                case id, name, slug
                case planType = "plan_type"
            }
        }

        if let edgeResult = try? JSONDecoder().decode(EdgeFunctionResponse.self, from: data) {
            if edgeResult.valid, let inst = edgeResult.institution {
                return InstitutionInfo(id: inst.id, name: inst.name, slug: inst.slug, planType: inst.planType ?? "institutional")
            }

            if let errorCode = edgeResult.errorCode {
                switch errorCode {
                case "INVALID_OR_UNAVAILABLE_CODE":
                    throw InstitutionalAuthError.codeNotFound
                case "TOO_MANY_REQUESTS":
                    throw InstitutionalAuthError.tooManyRequests
                default:
                    throw InstitutionalAuthError.serviceError(message: edgeResult.message ?? "Error al validar el código")
                }
            }
        }

        if httpResponse.statusCode == 429 {
            throw InstitutionalAuthError.tooManyRequests
        }

        throw InstitutionalAuthError.codeNotFound
    }

    public func requestInstitutionalOTP(code: String, email: String) async throws -> AccessCodeValidationResult {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !cleanCode.isEmpty else {
            throw InstitutionalAuthError.codeNotFound
        }
        guard !cleanEmail.isEmpty else {
            throw InstitutionalAuthError.invalidEmail
        }

        let functionURLString = "\(supabaseURL)/functions/v1/validate-institution-code"
        guard let url = URL(string: functionURLString) else {
            throw InstitutionalAuthError.serviceError(message: "URL de función inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)

        let body = ["code": cleanCode, "email": cleanEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstitutionalAuthError.networkError
        }

        struct EdgeFunctionOTPResponse: Codable {
            let valid: Bool
            let validation_ticket: String?
            let errorCode: String?
            let message: String?
            let institution: EdgeInstitutionData?

            enum CodingKeys: String, CodingKey {
                case valid
                case validation_ticket
                case errorCode = "error_code"
                case message
                case institution
            }
        }

        struct EdgeInstitutionData: Codable {
            let id: UUID
            let name: String
            let slug: String
            let planType: String?

            enum CodingKeys: String, CodingKey {
                case id, name, slug
                case planType = "plan_type"
            }
        }

        if let edgeResult = try? JSONDecoder().decode(EdgeFunctionOTPResponse.self, from: data) {
            if edgeResult.valid, let inst = edgeResult.institution, let ticket = edgeResult.validation_ticket {
                let info = InstitutionInfo(id: inst.id, name: inst.name, slug: inst.slug, planType: inst.planType ?? "institutional")
                return AccessCodeValidationResult(validation_ticket: ticket, institution: info)
            }

            if let errorCode = edgeResult.errorCode {
                switch errorCode {
                case "INVALID_OR_UNAVAILABLE_CODE":
                    throw InstitutionalAuthError.codeNotFound
                case "TOO_MANY_REQUESTS":
                    throw InstitutionalAuthError.tooManyRequests
                default:
                    throw InstitutionalAuthError.serviceError(message: edgeResult.message ?? "Error al validar el código o enviar OTP")
                }
            }
        }

        if httpResponse.statusCode == 429 {
            throw InstitutionalAuthError.tooManyRequests
        }

        throw InstitutionalAuthError.serviceError(message: "Error de servidor al solicitar el OTP institucional")
    }

    public func claimMembershipByDomain(email: String) async throws {
        let rpcURLString = "\(supabaseURL)/rest/v1/rpc/claim_institution_membership_by_domain"
        guard let url = URL(string: rpcURLString) else {
            throw InstitutionalAuthError.serviceError(message: "URL RPC inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let token = KeychainHelper.load(key: "sessionToken").flatMap { String(data: $0, encoding: .utf8) }
        applyHeaders(to: &request, bearerToken: token)

        let body = ["p_institutional_email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstitutionalAuthError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw InstitutionalAuthError.serviceError(message: "Error al vincular la membresía por dominio.")
        }
    }

    public func claimMembershipByTicket(ticket: String) async throws {
        let rpcURLString = "\(supabaseURL)/rest/v1/rpc/claim_institution_membership_by_ticket"
        guard let url = URL(string: rpcURLString) else {
            throw InstitutionalAuthError.serviceError(message: "URL RPC inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let token = KeychainHelper.load(key: "sessionToken").flatMap { String(data: $0, encoding: .utf8) }
        applyHeaders(to: &request, bearerToken: token)

        let body = [
            "p_ticket_token": ticket.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw InstitutionalAuthError.networkError
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                if message.contains("no coincide con la sesión") || message.contains("no autorizado") {
                    throw InstitutionalAuthError.serviceError(message: "El ticket no pertenece a tu sesión actual.")
                } else if message.contains("ya fue utilizado") {
                    throw InstitutionalAuthError.serviceError(message: "Este ticket ya fue utilizado.")
                } else if message.contains("ticket") && message.contains("vencido") {
                    throw InstitutionalAuthError.otpExpired
                } else if message.contains("código") && message.contains("vencido") {
                    throw InstitutionalAuthError.codeExpired
                } else if message.contains("límite máximo") {
                    throw InstitutionalAuthError.codeMaxUsesReached
                } else if message.contains("dominio no está autorizado") {
                    throw InstitutionalAuthError.serviceError(message: "El dominio de tu correo no está autorizado.")
                }
            }
            throw InstitutionalAuthError.serviceError(message: "Error al reclamar el ticket de membresía.")
        }
    }
}
