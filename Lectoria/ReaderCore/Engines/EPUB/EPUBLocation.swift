import Foundation
import ReadiumShared

// MARK: - EPUBLocation

/// Representa la posición actual de lectura en un libro EPUB.
///
/// Envuelve el `Locator` nativo de Readium para facilitar la serialización
/// y el desacoplamiento en la persistencia local de Lectoria.
struct EPUBLocation: Codable, Sendable, Hashable {
    /// Objeto localizador nativo de Readium.
    let locator: Locator

    nonisolated init(locator: Locator) {
        self.locator = locator
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case locatorJSON
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let jsonString = try container.decode(String.self, forKey: .locatorJSON)
        
        guard let data = jsonString.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonValue = try? JSONValue(jsonString: jsonString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .locatorJSON,
                in: container,
                debugDescription: "String JSON no válido para deserializar Locator."
            )
        }
        
        guard let locator = try? Locator(json: jsonValue, warnings: nil) else {
            throw DecodingError.dataCorruptedError(
                forKey: .locatorJSON,
                in: container,
                debugDescription: "Fallo al inicializar el objeto Locator de Readium."
            )
        }
        
        self.locator = locator
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        guard let jsonString = try? locator.jsonString() else {
            throw EncodingError.invalidValue(
                locator,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "No se pudo codificar el Locator de Readium a String JSON."
                )
            )
        }
        
        try container.encode(jsonString, forKey: .locatorJSON)
    }
}
