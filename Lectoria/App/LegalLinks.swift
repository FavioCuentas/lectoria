import Foundation

/// Enlaces públicos que muestra la app (pantalla de planes, login, acceso institucional).
/// Apple exige que los de privacidad y términos funcionen en la pantalla de suscripción.
/// `lectoria.app` NO es nuestro dominio (es una página aparcada): no usarlo.
enum LegalLinks {
    /// Política de privacidad publicada en la web de Lectoria (también la URL de App Store Connect).
    static let privacy = URL(string: "https://lectoria.orvexaio.com/privacidad")!
    /// Lectoria usa el EULA estándar de Apple para las compras.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportEmail = "favio.cuentas@orvexaio.com"
    static let support = URL(string: "mailto:\(supportEmail)?subject=Soporte%20Lectoria")!
    static let institutionsHelp = URL(string: "mailto:\(supportEmail)?subject=Mi%20instituci%C3%B3n%20en%20Lectoria")!
}
