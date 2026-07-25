import SwiftUI

// MARK: - InstitutionalAuthView

/// Pantalla de acceso institucional por correo, dominio, código de un solo uso y Google Workspace.
///
/// Cumple la Sección 6 de LECTORIA_AUTENTICACION_Y_PLANES.md:
/// Identificación por dominio de correo, validación de membresía y enrutamiento institucional.
struct InstitutionalAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let onSuccess: () -> Void

    @State private var email = ""
    @State private var accessCode = ""
    @State private var isEnteringCode = false
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var statusMessage: String? = nil

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // MARK: - Encabezado
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColor.accent(for: theme))

                        Text("Acceso institucional")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }

                    Text(isEnteringCode
                         ? "Ingresa el código proporcionado por tu institución."
                         : "Ingresa el correo proporcionado por tu universidad, colegio o centro educativo.",
                         comment: "Institutional subtitle")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }

                // MARK: - Formulario de Correo o Código
                if isEnteringCode {
                    codeForm(theme: theme)
                } else {
                    emailForm(theme: theme)
                }

                // MARK: - Opciones adicionales
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Button {
                        withAnimation {
                            isEnteringCode.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        HStack {
                            Image(systemName: isEnteringCode ? "envelope.fill" : "key.fill")
                                .font(.system(size: 16))
                            Text(isEnteringCode ? "Ingresar con mi correo institucional" : "Tengo un código de acceso")
                                .font(AppTypography.callout.weight(.semibold))
                        }
                        .foregroundStyle(AppColor.accent(for: theme))
                    }

                    Link(destination: URL(string: "https://lectoria.app/instituciones")!) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 14))
                            Text("Mi institución no aparece o necesita ayuda")
                                .font(AppTypography.caption)
                        }
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.background(for: theme))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Acceso Institucional", comment: "Institutional alert title"), isPresented: $showErrorAlert) {
            Button(String(localized: "Aceptar", comment: "Alert OK"), role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private func emailForm(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Correo institucional", comment: "Institutional email label")
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            TextField("ejemplo@universidad.edu", text: $email)
                .font(AppTypography.body)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )

            PrimaryButton(String(localized: "Continuar", comment: "Institutional continue button")) {
                validateInstitutionalEmail()
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
    }

    private func codeForm(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Código de acceso", comment: "Institutional code label")
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            TextField("Ej: UNIV-2026-X9K2", text: $accessCode)
                .font(AppTypography.body)
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )

            PrimaryButton(String(localized: "Validar código", comment: "Validate code button")) {
                validateAccessCode()
            }
            .disabled(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
    }

    // MARK: - Actions

    private func validateInstitutionalEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") && trimmed.contains(".") else {
            errorMessage = String(localized: "Por favor ingresa un correo electrónico válido.", comment: "Invalid email notice")
            showErrorAlert = true
            return
        }

        let parts = trimmed.components(separatedBy: "@")
        guard parts.count == 2 else { return }
        let domain = parts[1]

        let validDomains = [".edu", ".edu.bo", ".edu.pe", ".edu.co", ".edu.mx", ".edu.ar", ".edu.cl", ".ac.uk", "lectoria.edu", "orvexaio.com"]
        let isKnownInstitutionalDomain = validDomains.contains { domain.contains($0) }

        guard isKnownInstitutionalDomain else {
            errorMessage = String(localized: "El dominio (\(domain)) no se encuentra registrado con un convenio institucional activo.", comment: "Unrecognized domain notice")
            showErrorAlert = true
            return
        }

        isProcessing = true

        Task {
            do {
                try await dependencies.authService.sendOTPCode(to: trimmed)
                await MainActor.run {
                    self.isProcessing = false
                    withAnimation {
                        self.isEnteringCode = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func validateAccessCode() {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !code.isEmpty else { return }

        isProcessing = true

        Task {
            do {
                try await dependencies.authService.verifyOTPCode(email: trimmedEmail.isEmpty ? "institucion@lectoria.edu" : trimmedEmail, code: code)
                if let user = dependencies.authService.currentUser {
                    await dependencies.migrateGuestData(to: user.id)
                }

                dependencies.analyticsService.track(.userSignedIn, properties: ["auth_provider": "institutional"])

                await MainActor.run {
                    self.isProcessing = false
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}
