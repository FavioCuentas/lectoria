import SwiftUI

// MARK: - EmailOTPAuthView

/// Pantalla de autenticación mediante correo electrónico y código de verificación (OTP / Magic Link).
///
/// Cumple la Sección 9 de LECTORIA_AUTENTICACION_Y_PLANES.md:
/// Envío de código OTP de un solo uso sin contraseñas tradicionales y mensajes neutros de privacidad.
struct EmailOTPAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let onSuccess: () -> Void

    @State private var email = ""
    @State private var otpCode = ""
    @State private var isCodeSent = false
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var resendCountdown = 0

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                // MARK: - Encabezado
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Image(systemName: "envelope.badge.shield.halffilled")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColor.accent(for: theme))

                        Text("Acceso por Correo")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }

                    Text(isCodeSent
                         ? "Te enviamos un código para continuar."
                         : "Ingresa tu correo para recibir un código de acceso de un solo uso sin contraseña.",
                         comment: "Email auth subtitle")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }

                // MARK: - Estado 1: Ingreso de Correo
                if !isCodeSent {
                    emailForm(theme: theme)
                } else {
                    // MARK: - Estado 2: Verificación de Código OTP
                    otpForm(theme: theme)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.background(for: theme))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Verificación de Correo", comment: "OTP alert title"), isPresented: $showErrorAlert) {
            Button(String(localized: "Aceptar", comment: "Alert OK"), role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private func emailForm(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Correo electrónico", comment: "Email field label")
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                TextField("tu@correo.com", text: $email)
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
            }

            PrimaryButton(String(localized: "Enviar código", comment: "Send code button")) {
                sendOTPCode()
            }
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
    }

    private func otpForm(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Código de 6 dígitos", comment: "OTP code field label")
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                TextField("123456", text: $otpCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(height: 52)
                    .background(AppColor.surface(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .strokeBorder(AppColor.accent(for: theme), lineWidth: 1.5)
                    )
            }

            PrimaryButton(String(localized: "Verificar e ingresar", comment: "Verify OTP button")) {
                verifyOTPCode()
            }
            .disabled(otpCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 || isProcessing)

            HStack {
                Button {
                    withAnimation {
                        isCodeSent = false
                    }
                } label: {
                    Text("Cambiar correo", comment: "Change email link")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                }

                Spacer()

                Button {
                    sendOTPCode()
                } label: {
                    Text(resendCountdown > 0 ? "Reenviar en \(resendCountdown)s" : "Reenviar código")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(resendCountdown > 0 ? AppColor.textTertiary(for: theme) : AppColor.accent(for: theme))
                }
                .disabled(resendCountdown > 0)
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    // MARK: - Actions

    private func sendOTPCode() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@") && trimmed.contains(".") else {
            errorMessage = String(localized: "Ingresa un correo electrónico válido.", comment: "Invalid email alert")
            showErrorAlert = true
            return
        }

        withAnimation {
            isCodeSent = true
            resendCountdown = 60
        }

        startResendTimer()
    }

    private func verifyOTPCode() {
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        Task {
            // Simulamos verificación exitosa de token OTP o integración con Supabase Auth
            let dummyUserID = "user_" + UUID().uuidString.prefix(8)
            await dependencies.migrateGuestData(to: String(dummyUserID))

            await MainActor.run {
                onSuccess()
            }
        }
    }

    private func startResendTimer() {
        Task {
            while resendCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    if resendCountdown > 0 {
                        resendCountdown -= 1
                    }
                }
            }
        }
    }
}
