import Foundation
import CryptoKit

// MARK: - FileStorageError

public enum FileStorageError: LocalizedError, Sendable {
    case directoryCreationFailed(String)
    case copyFailed(String)
    case deletionFailed(String)
    case fileNotFound(String)
    case hashCalculationFailed(String)
    case insufficientDiskSpace

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let msg):
            return String(localized: "No se pudo crear el directorio de almacenamiento: \(msg)", comment: "Error message")
        case .copyFailed(let msg):
            return String(localized: "Error al copiar el archivo: \(msg)", comment: "Error message")
        case .deletionFailed(let msg):
            return String(localized: "Error al eliminar el archivo: \(msg)", comment: "Error message")
        case .fileNotFound(let msg):
            return String(localized: "Archivo no encontrado: \(msg)", comment: "Error message")
        case .hashCalculationFailed(let msg):
            return String(localized: "Error al calcular el hash SHA-256: \(msg)", comment: "Error message")
        case .insufficientDiskSpace:
            return String(localized: "Espacio en disco insuficiente para importar el documento.", comment: "Error message")
        }
    }
}

// MARK: - FileStorageService

/// Servicio encargado del guardado, hash y mantenimiento físico de los archivos de lectura.
public final class FileStorageService: Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Directorio base en `Application Support/Publications/`
    public var publicationsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Publications", isDirectory: true)
    }

    /// Crea el directorio de publicaciones si no existe.
    public func ensurePublicationsDirectoryExists() throws {
        let directory = publicationsDirectory
        if !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw FileStorageError.directoryCreationFailed(error.localizedDescription)
            }
        }
    }

    /// Copia un archivo desde una ubicación temporal al directorio persistente de publicaciones.
    /// - Parameters:
    ///   - sourceURL: URL del archivo origen (debe ser accesible).
    ///   - fileName: Nombre destino con el que se guardará el archivo.
    /// - Returns: La URL final del archivo copiado.
    public func store(fileAt sourceURL: URL, withName fileName: String) throws -> URL {
        try ensurePublicationsDirectoryExists()
        
        let destinationURL = publicationsDirectory.appendingPathComponent(fileName)
        
        // Si el archivo ya existe en destino, se elimina previamente para evitar colisiones
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        // Validar espacio en disco
        let fileSize = try getFileSize(at: sourceURL)
        if !hasAvailableDiskSpace(forSize: fileSize) {
            throw FileStorageError.insufficientDiskSpace
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            throw FileStorageError.copyFailed(error.localizedDescription)
        }
    }

    /// Elimina un archivo físico del almacenamiento.
    /// - Parameter fileName: Nombre del archivo a eliminar.
    public func delete(fileName: String) throws {
        let fileURL = publicationsDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw FileStorageError.deletionFailed(error.localizedDescription)
        }
    }

    /// Calcula de manera eficiente (por chunks) el hash SHA-256 de un archivo en disco.
    /// - Parameter fileURL: URL del archivo.
    /// - Returns: String con el hash en formato hexadecimal.
    public func calculateSHA256(for fileURL: URL) throws -> String {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw FileStorageError.fileNotFound(fileURL.path)
        }

        do {
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer { try? fileHandle.close() }

            var hasher = SHA256()
            let bufferSize = 1024 * 64 // 64 KB buffers
            
            while let data = try fileHandle.read(upToCount: bufferSize), !data.isEmpty {
                hasher.update(data: data)
            }
            
            let digest = hasher.finalize()
            return digest.map { String(format: "%02hhx", $0) }.joined()
        } catch {
            throw FileStorageError.hashCalculationFailed(error.localizedDescription)
        }
    }

    /// Obtiene el tamaño de un archivo en bytes.
    public func getFileSize(at fileURL: URL) throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? Int64 {
                return size
            }
            return 0
        } catch {
            throw FileStorageError.fileNotFound(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Verifica si hay suficiente espacio disponible en disco.
    private func hasAvailableDiskSpace(forSize requiredSize: Int64) -> Bool {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        do {
            let values = try appSupport.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableSpace = values.volumeAvailableCapacityForImportantUsage {
                return availableSpace > requiredSize
            }
        } catch {
            // Si falla la API moderna, usar la antigua
            if let attributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let freeSize = attributes[.systemFreeSize] as? Int64 {
                return freeSize > requiredSize
            }
        }
        return true
    }
}
