import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - AuthMainView

/// Pantalla principal de acceso de Lectoria.
///
/// Principios del spec (Sección 5 de LECTORIA_AUTENTICACION_Y_PLANES.md):
/// 1. La primera opción visible es siempre "Continuar con mi institución" (botón principal terracota).
/// 2. Opciones secundarias: Google, Apple, Correo electrónico e Invitado.
/// 3. El modo invitado permite usar la app offline sin obligar a crear una cuenta.
/// 4. Pie de pantalla con información de privacidad y términos de uso.
struct AuthMainView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    
    let onContinueAsGuest: () -> Void
    let onAuthSuccess: () -> Void

    @State private var showInstitutionalAuth = false
    @State private var showEmailAuth = false
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var currentNonce: String? = nil

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // MARK: - Encabezado
                    headerSection(theme: theme)

                    // MARK: - Botón Principal: Acceso Institucional
                    institutionalSection(theme: theme)

                    // Divider discreto con etiqueta
                    dividerSection(theme: theme)

                    // MARK: - Opciones Secundarias (Google, Apple, Correo)
                    secondaryOptionsSection(theme: theme)

                    // MARK: - Opción Invitado
                    guestOptionSection(theme: theme)

                    Spacer(minLength: AppSpacing.xl)

                    // MARK: - Pie de pantalla (Legales y Privacidad)
                    footerSection(theme: theme)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColor.background(for: theme))
            .navigationDestination(isPresented: $showInstitutionalAuth) {
                InstitutionalAuthView(onSuccess: {
                    onAuthSuccess()
                })
            }
            .navigationDestination(isPresented: $showEmailAuth) {
                EmailOTPAuthView(onSuccess: {
                    onAuthSuccess()
                })
            }
            .alert(String(localized: "Error de autenticación", comment: "Auth error title"), isPresented: $showErrorAlert) {
                Button(String(localized: "Aceptar", comment: "Alert OK button"), role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Subviews

    private func headerSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                .padding(.top, AppSpacing.md)

            Text("Lectoria")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(AppColor.textPrimary(for: theme))

            Text("Lee, comprende y aprende mejor.", comment: "Auth header main tagline")
                .font(AppTypography.subtitle.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)

            Text("Accede con tu institución o continúa con una cuenta personal.", comment: "Auth header subtitle")
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .multilineTextAlignment(.center)
        }
    }

    private func institutionalSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button {
                showInstitutionalAuth = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continuar con mi institución")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("Universidad, colegio o centro educativo", comment: "Institutional button subtitle")
                            .font(AppTypography.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 60)
                .background(AppColor.accent(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .shadow(color: AppColor.accent(for: theme).opacity(0.25), radius: 8, x: 0, y: 4)
            }

            Text("Usa el acceso proporcionado por tu universidad, colegio o centro educativo.", comment: "Institutional helper text")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .padding(.horizontal, AppSpacing.xs)
        }
    }

    private func dividerSection(theme: AppTheme) -> some View {
        HStack {
            Rectangle()
                .fill(AppColor.border(for: theme))
                .frame(height: 1)

            Text("o continúa con", comment: "Auth divider text")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .padding(.horizontal, AppSpacing.xs)

            Rectangle()
                .fill(AppColor.border(for: theme))
                .frame(height: 1)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func secondaryOptionsSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Google Sign-In
            Button {
                handleGoogleSignIn()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))

                    Text("Continuar con Google")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 50)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )
            }

            // Apple Sign-In Nativo con Nonce seguro
            SignInWithAppleButton(
                .continue,
                onRequest: { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = sha256(nonce)
                },
                onCompletion: { result in
                    handleAppleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(theme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            // Correo Electrónico OTP
            Button {
                showEmailAuth = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))

                    Text("Continuar con correo electrónico")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 50)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )
            }
        }
    }

    private func guestOptionSection(theme: AppTheme) -> some View {
        Button {
            dependencies.analyticsService.track(.guestModeEntered)
            onContinueAsGuest()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text("Continuar como invitado")
                    .font(AppTypography.callout.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }
            .padding(.vertical, AppSpacing.xs)
        }
    }

    private func footerSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Link("Términos de uso", destination: URL(string: "https://lectoria.app/terms")!)
                Text("•")
                Link("Privacidad", destination: URL(string: "https://lectoria.app/privacy")!)
                Text("•")
                Link("Soporte", destination: URL(string: "https://lectoria.app/support")!)
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColor.textTertiary(for: theme))

            Text("Tus documentos y herramientas de IA permanecen en tu dispositivo.", comment: "Privacy commitment text")
                .font(AppTypography.footnote)
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Handlers

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResult):
            guard let appleIDCredential = authResult.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = String(localized: "No se pudo obtener el token de identificación de Apple.", comment: "Apple sign in token error")
                showErrorAlert = true
                return
            }

            var fullName: String? = nil
            if let nameComponents = appleIDCredential.fullName {
                let formatter = PersonNameComponentsFormatter()
                fullName = formatter.string(from: nameComponents)
            }

            let email = appleIDCredential.email
            let rawNonce = currentNonce

            Task {
                do {
                    try await dependencies.authService.signInWithApple(
                        identityToken: identityToken,
                        rawNonce: rawNonce,
                        email: email,
                        fullName: fullName
                    )
                    
                    // Migrar datos de invitado si existían en este iPhone
                    if let user = dependencies.authService.currentUser {
                        await dependencies.migrateGuestData(to: user.id)
                    }

                    dependencies.analyticsService.track(.userSignedIn, properties: ["auth_provider": "apple"])

                    await MainActor.run {
                        onAuthSuccess()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showErrorAlert = true
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func handleGoogleSignIn() {
        let authURLString = "\(dependencies.authService.supabaseURL)/auth/v1/authorize?provider=google&redirect_to=lectoria://auth-callback"
        guard let authURL = URL(string: authURLString) else { return }

        let contextProvider = WebAuthContextProvider()
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "lectoria"
        ) { callbackURL, error in
            if let error = error {
                if (error as NSError).code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                    }
                }
                return
            }

            guard let callbackURL = callbackURL else { return }

            let urlString = callbackURL.absoluteString.replacingOccurrences(of: "#", with: "?")
            guard let components = URLComponents(string: urlString),
                  let queryItems = components.queryItems else { return }

            // Comprobar si vino un mensaje de error explícito de OAuth/Supabase
            if let errorDescription = queryItems.first(where: { $0.name == "error_description" })?.value ?? queryItems.first(where: { $0.name == "error" })?.value {
                let cleanError = errorDescription.replacingOccurrences(of: "+", with: " ")
                Task { @MainActor in
                    self.errorMessage = cleanError
                    self.showErrorAlert = true
                }
                return
            }

            let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value
            let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value
            let authCode = queryItems.first(where: { $0.name == "code" })?.value

            Task {
                do {
                    if let token = accessToken {
                        try await dependencies.authService.setSessionFromOAuth(accessToken: token, refreshToken: refreshToken)
                    } else if let code = authCode {
                        try await dependencies.authService.exchangeCodeForSession(code: code)
                    } else {
                        await MainActor.run {
                            self.errorMessage = String(localized: "No se pudo recuperar la sesión de Google.", comment: "Google token missing")
                            self.showErrorAlert = true
                        }
                        return
                    }

                    if let user = dependencies.authService.currentUser {
                        await dependencies.migrateGuestData(to: user.id)
                    }

                    dependencies.analyticsService.track(.userSignedIn, properties: ["auth_provider": "google"])

                    await MainActor.run {
                        onAuthSuccess()
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                    }
                }
            }
        }

        session.presentationContextProvider = contextProvider
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    // MARK: - Helpers de Criptografía para Apple Nonce

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("No se pudo generar el nonce aleatorio.")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = String(randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        })
        return nonce
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - WebAuthContextProvider

private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
