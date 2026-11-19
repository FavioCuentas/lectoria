import SwiftUI
import UIKit
import Observation

// MARK: - ScreenAwakeController

/// Ajuste "Pantalla activa al leer": mientras haya un lector abierto y el ajuste esté activado,
/// el iPhone no se bloquea solo. Al cerrar el último lector vuelve al comportamiento normal.
@MainActor
@Observable
final class ScreenAwakeController {
    static let shared = ScreenAwakeController()
    static let preferenceKey = "reader.keepScreenOn"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let setIdleTimerDisabled: (Bool) -> Void
    @ObservationIgnored private var openReaders = 0

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.preferenceKey)
            apply()
        }
    }

    init(
        defaults: UserDefaults = .standard,
        setIdleTimerDisabled: @escaping (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }
    ) {
        self.defaults = defaults
        self.setIdleTimerDisabled = setIdleTimerDisabled
        self.isEnabled = defaults.bool(forKey: Self.preferenceKey)
    }

    func readerDidAppear() {
        openReaders += 1
        apply()
    }

    func readerDidDisappear() {
        openReaders = max(0, openReaders - 1)
        apply()
    }

    private func apply() {
        setIdleTimerDisabled(isEnabled && openReaders > 0)
    }
}

extension View {
    /// Mantiene la pantalla encendida mientras esta vista de lectura esté visible, si el ajuste está activo.
    func keepsScreenAwakeWhileReading() -> some View {
        onAppear { ScreenAwakeController.shared.readerDidAppear() }
            .onDisappear { ScreenAwakeController.shared.readerDidDisappear() }
    }
}
