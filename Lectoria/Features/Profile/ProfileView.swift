import SwiftUI
import AuthenticationServices
import Observation

// MARK: - ProfileView

/// Pantalla de perfil y ajustes de cuenta.
///
/// Integra Sign in with Apple, visualización de estado de la cuenta,
/// cambio de tema visual, cierre de sesión, migración de datos y eliminación de cuenta.
struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @Bindable private var screenAwake = ScreenAwakeController.shared
    @State private var showPrivacy = false
    @State private var showAbout = false
    @State private var isExporting = false
    @State private var exportedFile: ExportedFile?
    @State private var isProcessing = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showErrorAlert = false
    @State private var showPaywall = false
    @State private var showMyDevices = false
    @State private var showStats = false
    @State private var showAuthMainView = false
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

                        // Copia de seguridad automática: la fila solo informa del estado.
                        let backup = dependencies.autoBackup
                        SettingsRow(
                            icon: "icloud.and.arrow.up",
                            title: String(localized: "Copia de seguridad", comment: "Profile: automatic backup status"),
                            subtitle: String(localized: "Notas, destacados y progreso", comment: "Profile: what the backup includes"),
                            variant: .value(AutoBackupCoordinator.statusText(
                                lastSyncedAt: backup.lastSyncedAt,
                                isRunning: backup.isRunning,
                                failed: backup.lastAttemptFailed
                            ))
                        )

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
                            Text("Inicia sesión o accede con tu institución para sincronizar tus libros y anotaciones en la nube de forma segura.",
                                 comment: "Profile: login prompt explanation")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                                .padding(.bottom, AppSpacing.xs)

                            Button {
                                showAuthMainView = true
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Iniciar sesión / Acceso Institucional")
                                        .font(AppTypography.bodyBold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.md)
                                .frame(height: 48)
                                .background(AppColor.accent(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            }
                        }
                        .padding(.vertical, AppSpacing.md)
                    }

                    Divider()

                    SettingsRow(
                        icon: "crown",
                        title: String(localized: "Plan de suscripción", comment: "Profile: subscription plan"),
                        variant: .value(SubscriptionPlanLabel.text(
                            isPremium: dependencies.subscriptionService.hasActiveSubscription,
                            productID: dependencies.subscriptionService.activeEntitlement?.productID
                        ))
                    ) {
                        showPaywall = true
                    }

                    Divider()

                    SettingsRow(
                        icon: "laptopcomputer.and.iphone",
                        title: String(localized: "Mis dispositivos", comment: "Profile: my devices link")
                    ) {
                        showMyDevices = true
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
                        subtitle: String(localized: "El iPhone no se bloquea mientras lees",
                                         comment: "Profile: keep screen on explanation"),
                        variant: .toggle($screenAwake.isEnabled)
                    )
                }

                // Sección: Datos
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "chart.bar",
                        title: String(localized: "Estadísticas", comment: "Profile: statistics")
                    ) {
                        showStats = true
                    }

                    Divider()

                    SettingsRow(
                        icon: "lock.shield",
                        title: String(localized: "Privacidad", comment: "Profile: privacy settings")
                    ) {
                        showPrivacy = true
                    }

                    Divider()

                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: String(localized: "Exportar notas y destacados", comment: "Profile: export annotations"),
                        variant: isExporting ? .value(String(localized: "Preparando…", comment: "Profile: export in progress")) : .navigation
                    ) {
                        exportAnnotations()
                    }
                }

                // Sección: Info
                profileSection(theme: theme) {
                    SettingsRow(
                        icon: "hand.raised",
                        title: String(localized: "Política de privacidad",
                                      comment: "Profile: privacy policy")
                    ) { openURL(LegalLinks.privacy) }

                    Divider()

                    SettingsRow(
                        icon: "doc.text",
                        title: String(localized: "Términos de uso",
                                      comment: "Profile: terms of use")
                    ) { openURL(LegalLinks.terms) }

                    Divider()

                    SettingsRow(
                        icon: "info.circle",
                        title: String(localized: "Acerca de Lectoria",
                                      comment: "Profile: about"),
                        subtitle: String(localized: "Versión \(AppEnvironment.current().appVersion)",
                                         comment: "Profile: version")
                    ) {
                        showAbout = true
                    }
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
            Text("Al cerrar sesión se detiene la copia de seguridad de tus notas, destacados y progreso hasta que vuelvas a iniciar sesión.",
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
        .navigationDestination(isPresented: $showStats) {
            StatsView()
        }
        .navigationDestination(isPresented: $showPrivacy) {
            PrivacySettingsView()
        }
        .navigationDestination(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(item: $exportedFile) { file in
            ShareSheetView(activityItems: [file.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showMyDevices) {
            MyDevicesView()
        }
        .sheet(isPresented: $showAuthMainView) {
            AuthMainView(
                onContinueAsGuest: {
                    showAuthMainView = false
                },
                onAuthSuccess: {
                    showAuthMainView = false
                }
            )
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

    // MARK: - Exportar

    struct ExportedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    /// Genera el Markdown con todas las notas y destacados y abre el menú de compartir.
    private func exportAnnotations() {
        guard !isExporting else { return }
        isExporting = true
        Task {
            defer { isExporting = false }
            do {
                let now = Date()
                let markdown = AnnotationsExporter.markdown(
                    publications: try await dependencies.publicationRepository.fetchAll(),
                    highlights: try await dependencies.highlightRepository.fetchAll(),
                    notes: try await dependencies.noteRepository.fetchAll(),
                    exportedAt: now
                )
                exportedFile = ExportedFile(url: try AnnotationsExporter.writeFile(markdown, exportedAt: now))
            } catch {
                errorMessage = String(localized: "No se pudieron exportar tus notas. Inténtalo de nuevo.", comment: "Profile: export failed")
                showErrorAlert = true
            }
        }
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
