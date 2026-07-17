import Foundation
import Observation

// MARK: - SupabaseAIService

/// Implementación del servicio de IA realizando llamadas directas a las Edge Functions de Supabase.
@Observable
public final class SupabaseAIService: AIService, @unchecked Sendable {
    public var hasConsentedToAI: Bool {
        get {
            accessQueue.sync {
                UserDefaults.standard.bool(forKey: "hasConsentedToAI")
            }
        }
        set {
            accessQueue.sync {
                UserDefaults.standard.set(newValue, forKey: "hasConsentedToAI")
            }
        }
    }
    
    private let supabaseURL: String
    private let anonKey: String
    private let accessQueue = DispatchQueue(label: "com.lectoria.app.ai.consent")
    
    public init(supabaseURL: String, anonKey: String) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
    }
    
    public func explain(text: String, sessionToken: String?) async throws -> String {
        try await callEdgeFunction(action: "explain", text: text, sessionToken: sessionToken)
    }
    
    public func simplify(text: String, sessionToken: String?) async throws -> String {
        try await callEdgeFunction(action: "simplify", text: text, sessionToken: sessionToken)
    }
    
    public func translate(text: String, targetLanguage: String, sessionToken: String?) async throws -> String {
        try await callEdgeFunction(action: "translate", text: text, extraParams: ["targetLanguage": targetLanguage], sessionToken: sessionToken)
    }
    
    public func summarize(text: String, sessionToken: String?) async throws -> String {
        try await callEdgeFunction(action: "summarize", text: text, sessionToken: sessionToken)
    }
    
    public func generateQuestions(text: String, sessionToken: String?) async throws -> String {
        try await callEdgeFunction(action: "generateQuestions", text: text, sessionToken: sessionToken)
    }
    
    // MARK: - Network helper
    
    private func callEdgeFunction(
        action: String,
        text: String,
        extraParams: [String: Any] = [:],
        sessionToken: String?
    ) async throws -> String {
        let url = URL(string: "\(supabaseURL)/functions/v1/lectoria-ai")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let sessionToken {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        
        var payload: [String: Any] = [
            "action": action,
            "text": text
        ]
        for (key, val) in extraParams {
            payload[key] = val
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Error desconocido en el asistente de IA."
            throw NSError(
                domain: "LectoriaAI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }
        
        let apiResponse = try JSONDecoder().decode(SupabaseAIResponse.self, from: data)
        return apiResponse.response
    }
}

// MARK: - Decodable response model

struct SupabaseAIResponse: Codable {
    let response: String
}
