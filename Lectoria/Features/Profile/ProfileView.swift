import SwiftUI
import AuthenticationServices
import Observation

// MARK: - ProfileView

/// Pantalla de perfil y ajustes de cuenta.
///
/// Integra Sign in with Apple, visualización de estado de la cuenta,
/// cambio de tema visual, cierre de sesión, migración de datos y eliminación de cuenta.
struct ProfileView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var keepScreenOn = false
    @State private var isProcessing = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var showPaywall = false
    @State private var errorMessage: String? = nil

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                if isProcessing {
                    ProgressView()
                        .padding(.vertical, AppSpacing.lg)
                }

                // Sección: Cuenta
                profileSection(theme: theme) {
                    if let user = dependencies.authService.currentUser {
                        SettingsRow(
                            icon: "person.crop.circle",
                            title: user.fullName ?? String(localized: "Usuario de Lectoria", comment: "Profile: default user name"),
                            subtitle: user.email,
                            variant: .value(String(localized: "Activa", comment: "Profile: account status active"))
                        ) {}

                        Divider()

                        let isSyncing = dependencies.syncService.isSyncing
                        let lastSync = dependencies.syncService.lastSyncedAt
                        
                        SettingsRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: String(localized: "Sincronizar ahora", comment: "Profile: manual sync action"),
                            variant: .value(isSyncing ? String(localized: "Sincronizando...", comment: "Sync status: active") : (lastSync != nil ? String(localized: "Sincronizado", comment: "Sync status: done") : String(localized: "Nunca", comment: "Sync status: never")))
                        ) {
                            Task {
                                try? await dependencies.syncService.syncAll()
                            }
                        }

                        Divider()

                        SettingsRow(
                            icon: "arrow.left.square",
                            title: String(localized: "Cerrar sesión", comment: "Profile: sign out action"),
                            variant: .destructive
                        ) {
                            showSignOutAlert = true
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Inicia sesión para sincronizar tus libros y anotaciones en la nube de forma segura.",
                                 comment: "Profile: login prompt explanation")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                                .padding(.bottom, AppSpacing.xs)

                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    request.requestedScopes = [.email, .fullName]
                                },
                                onCompletion: { result in
                                    handleAppleSignIn(result: result)
                                }
                            )
                            .signInWithAppleButtonStyle(theme == .dark ? .white : .black)
                            .frame(height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        }
                        .padding(.vertical, AppSpacing.md)
                    }

                    Divider()

                    let isPremium = dependencies.subscriptionService.hasActiveSubscription
                    SettingsRow(
                        icon: "crown",
                        title: String(localized: "Plan", comment: "Profile: subscription plan"),
                        variant: .value(isPremium ? String(localized: "Premium", comment: "Profile: premium plan") : String(localized: "Gratuito", comment: "Profile: free plan"))
                    ) {
                        if !isPremium {
                            showPaywall = true
                        }
                    }
                }

                // Sección: Apariencia
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "paintbrush",
                        title: String(localized: "Tema", comment: "Profile: theme"),
                        variant: .value(themeManager.currentTheme.displayName)
                    ) {
                        themeManager.cycleTheme()
                    }

                    Divider()

                    SettingsRow(
                        icon: "sun.max",
                        title: String(localized: "Pantalla activa al leer",
                                      comment: "Profile: keep screen on"),
                        variant: .toggle($keepScreenOn)
                    )
                }

                // Sección: Inteligencia Artificial
                profileSection(theme: theme) {
                    let consentBinding = Binding<Bool>(
                        get: { dependencies.aiService.hasConsentedToAI },
                        set: { dependencies.aiService.hasConsentedToAI = $0 }
                    )
                    SettingsRow(
                        icon: "sparkles",
                        title: String(localized: "Consentimiento de IA", comment: "Profile: AI consent toggle"),
                        variant: .toggle(consentBinding)
                    )
                }

                // Sección: Datos
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "chart.bar",
                        title: String(localized: "Estadísticas", comment: "Profile: statistics")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: String(localized: "Exportar datos", comment: "Profile: export data")
                    ) {}
                }

                // Sección: Info
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "hand.raised",
                        title: String(localized: "Política de privacidad",
                                      comment: "Profile: privacy policy")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "doc.text",
                        title: String(localized: "Términos de uso",
                                      comment: "Profile: terms of use")
                    ) {}

                    Divider()

                    SettingsRow(
                        icon: "info.circle",
                        title: String(localized: "Acerca de Lectoria",
                                      comment: "Profile: about"),
                        subtitle: String(localized: "Versión \(AppEnvironment.current().appVersion)",
                                         comment: "Profile: version")
                    ) {}
                }

                // Zona peligrosa
                if dependencies.authService.currentUser != nil {
                    profileSection(theme: theme) {
                        SettingsRow(
                            icon: "trash",
                            title: String(localized: "Eliminar cuenta",
                                          comment: "Profile: delete account"),
                            variant: .destructive
                        ) {
                            showDeleteAlert = true
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Perfil", comment: "Profile screen title"))
        .navigationBarTitleDisplayMode(.large)
        .alert(
            String(localized: "Cerrar sesión", comment: "Profile: alert title sign out"),
            isPresented: $showSignOutAlert
        ) {
            Button(String(localized: "Cancelar", comment: "Alert action: cancel"), role: .cancel) {}
            Button(String(localized: "Cerrar sesión", comment: "Profile: sign out action"), role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("Al cerrar sesión, no podrás sincronizar nuevos libros y anotaciones hasta que inicies sesión de nuevo.",
                 comment: "Profile: sign out alert body")
        }
        .alert(
            String(localized: "Eliminar cuenta", comment: "Profile: alert title delete account"),
            isPresented: $showDeleteAlert
        ) {
            Button(String(localized: "Cancelar", comment: "Alert action: cancel"), role: .cancel) {}
            Button(String(localized: "Eliminar permanentemente", comment: "Profile: delete account action confirm"), role: .destructive) {
                performDeleteAccount()
            }
        } message: {
            Text("Esta acción no se puede deshacer. Se eliminarán de forma definitiva todos tus libros, destacados, notas y datos de usuario en la nube.",
                 comment: "Profile: delete account alert body")
        }
        .alert(
            String(localized: "Error", comment: "Alert title: error"),
            isPresented: $showErrorAlert
        ) {
            Button(String(localized: "Aceptar", comment: "Alert action: ok"), role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Section container

    private func profileSection(
        theme: AppTheme,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Account Actions

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = String(localized: "No se pudo obtener el token de identidad de Apple.", comment: "Profile: error message apple token")
                showErrorAlert = true
                return
            }

            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName.map { name in
                [name.givenName, name.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }

            isProcessing = true
            Task {
                do {
                    try await dependencies.authService.signInWithApple(
                        identityToken: identityToken,
                        email: email,
                        fullName: fullName
                    )

                    // Realizar la migración de datos de invitado a la cuenta y sincronizar
                    if let user = dependencies.authService.currentUser {
                        await dependencies.migrateGuestData(to: user.id)
                        try? await dependencies.syncService.performInitialSync()
                    }

                    isProcessing = false
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    isProcessing = false
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func performSignOut() {
        isProcessing = true
        Task {
            do {
                try await dependencies.authService.signOut()
                isProcessing = false
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isProcessing = false
            }
        }
    }

    private func performDeleteAccount() {
        isProcessing = true
        Task {
            do {
                try await dependencies.authService.deleteAccount()
                isProcessing = false
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isProcessing = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Profile") {
    let themeManager = ThemeManager()
    NavigationStack {
        ProfileView()
    }
    .environment(themeManager)
    .environment(AppDependencies.preview)
}
