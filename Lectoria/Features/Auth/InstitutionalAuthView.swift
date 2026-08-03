import SwiftUI

// MARK: - InstitutionalAuthView

/// Pantalla de Acceso Institucional de Lectoria con arquitectura MVVM y separación estricta de rutas.
///
/// Soporta dos rutas independientes:
/// 1. Acceso mediante correo institucional con verificación de dominio en Supabase.
/// 2. Acceso mediante código de convenio institucional con validación en Edge Function `validate-institution-code`.
struct InstitutionalAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let onSuccess: () -> Void

    @State private var viewModel: InstitutionalAuthViewModel? = nil

    var body: some View {
        let theme = themeManager.currentTheme

        Group {
            if let viewModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        // MARK: - Encabezado Principal
                        headerView(theme: theme, viewModel: viewModel)

                        // MARK: - Contenido según Estado
                        switch viewModel.state {
                        case .idle, .validatingInstitution, .failed:
                            if viewModel.route == .code {
                                codeStepView(theme: theme, viewModel: viewModel)
                            } else {
                                emailStepView(theme: theme, viewModel: viewModel)
                            }

                            routeSelectorButtons(theme: theme, viewModel: viewModel)

                        case .institutionValidated(let institution):
                            emailForValidatedCodeView(theme: theme, viewModel: viewModel, institution: institution)

                        case .sendingOTP:
                            loadingStateView(theme: theme, message: "Enviando código de verificación...")

                        case .awaitingOTP(let email, let institution):
                            otpVerificationStepView(theme: theme, viewModel: viewModel, email: email, institution: institution)

                        case .verifyingOTP:
                            loadingStateView(theme: theme, message: "Verificando código de acceso...")

                        case .linkingMembership:
                            loadingStateView(theme: theme, message: "Vinculando membresía institucional...")

                        case .authenticated:
                            loadingStateView(theme: theme, message: "¡Acceso concedido! Redirigiendo...")
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.lg)
                }
                .background(AppColor.background(for: theme))
                .navigationBarTitleDisplayMode(.inline)
                .alert(String(localized: "Acceso Institucional", comment: "Institutional alert title"), isPresented: Binding(
                    get: { viewModel.showErrorAlert },
                    set: { viewModel.showErrorAlert = $0 }
                )) {
                    Button(String(localized: "Aceptar", comment: "Alert OK"), role: .cancel) {}
                } message: {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = InstitutionalAuthViewModel(
                    institutionService: dependencies.institutionService,
                    authService: dependencies.authService,
                    onGuestMigrate: { userID in
                        await dependencies.migrateGuestData(to: userID)
                    },
                    onSuccess: { @MainActor in
                        dependencies.analyticsService.track(.userSignedIn, properties: ["auth_provider": "institutional"])
                        onSuccess()
                    }
                )
                self.viewModel = vm
            }
        }
    }

    // MARK: - Encabezado

    @ViewBuilder
    private func headerView(theme: AppTheme, viewModel: InstitutionalAuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColor.accent(for: theme))
                    .accessibilityHidden(true)

                Text("Acceso institucional")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
            }

            Text(headerSubtitle(for: viewModel))
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func headerSubtitle(for viewModel: InstitutionalAuthViewModel) -> String {
        switch viewModel.state {
        case .awaitingOTP:
            return "Ingresa el código de 6 dígitos enviado a tu correo institucional."
        case .institutionValidated(let inst):
            return "Código válido para \(inst.name). Ingresa tu correo para continuar."
        default:
            return viewModel.route == .code
                ? "Ingresa el código proporcionado por tu universidad o institución."
                : "Ingresa el correo proporcionado por tu universidad, colegio o centro educativo."
        }
    }

    // MARK: - Componentes de Formulario

    @ViewBuilder
    private func emailStepView(theme: AppTheme, viewModel: InstitutionalAuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Correo institucional", comment: "Institutional email label")
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            TextField("ejemplo@universidad.edu", text: Binding(
                get: { viewModel.email },
                set: { viewModel.email = $0 }
            ))
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
                Task {
                    await viewModel.validateEmailAndSendOTP()
                }
            }
            .disabled(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy(viewModel: viewModel))
        }
    }

    @ViewBuilder
    private func codeStepView(theme: AppTheme, viewModel: InstitutionalAuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Código de acceso", comment: "Institutional code label")
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            TextField("Ej: UCB-2026-X9K2", text: Binding(
                get: { viewModel.accessCode },
                set: { viewModel.accessCode = $0 }
            ))
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

            PrimaryButton(String(localized: "Continuar", comment: "Institutional continue code button")) {
                Task {
                    await viewModel.validateAccessCode()
                }
            }
            .disabled(viewModel.accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy(viewModel: viewModel))
        }
    }

    @ViewBuilder
    private func emailForValidatedCodeView(theme: AppTheme, viewModel: InstitutionalAuthViewModel, institution: InstitutionInfo) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Institución verificada: \(institution.name)")
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
            }
            .padding(AppSpacing.sm)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            Text("Correo institucional", comment: "Institutional email for validated code")
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            TextField("ejemplo@\(institution.slug).edu", text: Binding(
                get: { viewModel.email },
                set: { viewModel.email = $0 }
            ))
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

            PrimaryButton(String(localized: "Enviar código de verificación", comment: "Send verification code")) {
                Task {
                    await viewModel.validateEmailAndSendOTP()
                }
            }
            .disabled(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy(viewModel: viewModel))

            Button {
                viewModel.resetToInitialStep()
            } label: {
                Text("Volver e ingresar otro código")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.accent(for: theme))
            }
        }
    }

    // MARK: - Paso de OTP

    @ViewBuilder
    private func otpVerificationStepView(
        theme: AppTheme,
        viewModel: InstitutionalAuthViewModel,
        email: String,
        institution: InstitutionInfo?
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let institution {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(AppColor.accent(for: theme))
                    Text(institution.name)
                        .font(AppTypography.callout.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Código de verificación de 6 dígitos")
                    .font(AppTypography.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                TextField("123456", text: Binding(
                    get: { viewModel.otpCode },
                    set: { viewModel.otpCode = String($0.prefix(6)) }
                ))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 52)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )
            }

            PrimaryButton(String(localized: "Verificar e ingresar", comment: "Verify OTP button")) {
                Task {
                    await viewModel.verifyOTPAndLinkMembership()
                }
            }
            .disabled(viewModel.otpCode.trimmingCharacters(in: .whitespacesAndNewlines).count != 6 || isBusy(viewModel: viewModel))

            HStack {
                Button {
                    Task {
                        await viewModel.resendOTP()
                    }
                } label: {
                    if viewModel.resendCountdown > 0 {
                        Text("Reenviar código (\(viewModel.resendCountdown)s)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    } else {
                        Text("Reenviar código de verificación")
                            .font(AppTypography.callout.weight(.semibold))
                            .foregroundStyle(AppColor.accent(for: theme))
                    }
                }
                .disabled(viewModel.resendCountdown > 0)

                Spacer()

                Button {
                    viewModel.resetToInitialStep()
                } label: {
                    Text("Cambiar correo")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.accent(for: theme))
                }
            }
        }
    }

    // MARK: - Pantalla de Carga y Opciones de Ruta

    @ViewBuilder
    private func routeSelectorButtons(theme: AppTheme, viewModel: InstitutionalAuthViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Button {
                withAnimation {
                    let nextRoute: InstitutionalRoute = (viewModel.route == .code) ? .email : .code
                    viewModel.selectRoute(nextRoute)
                }
            } label: {
                HStack {
                    Image(systemName: viewModel.route == .code ? "envelope.fill" : "key.fill")
                        .font(.system(size: 16))
                    Text(viewModel.route == .code ? "Ingresar con mi correo institucional" : "Tengo un código de acceso")
                        .font(AppTypography.callout.weight(.semibold))
                }
                .frame(minHeight: 44)
                .foregroundStyle(AppColor.accent(for: theme))
            }

            Link(destination: URL(string: "https://lectoria.app/instituciones")!) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14))
                    Text("Mi institución no aparece o necesita ayuda")
                        .font(AppTypography.caption)
                }
                .frame(minHeight: 44)
                .foregroundStyle(AppColor.textTertiary(for: theme))
            }
        }
    }

    @ViewBuilder
    private func loadingStateView(theme: AppTheme, message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }

    private func isBusy(viewModel: InstitutionalAuthViewModel) -> Bool {
        switch viewModel.state {
        case .validatingInstitution, .sendingOTP, .verifyingOTP, .linkingMembership:
            return true
        default:
            return false
        }
    }
}
