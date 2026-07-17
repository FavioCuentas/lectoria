import SwiftUI

// MARK: - AIConsentView

/// Vista de consentimiento informado para las funciones de IA.
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    
    let onCompletion: (Bool) -> Void

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Icono y título
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 54))
                                .foregroundStyle(AppColor.accent(for: theme))
                                .padding(.bottom, AppSpacing.xs)

                            Text("Asistente de IA")
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("Privacidad y términos del servicio",
                                 comment: "Consent screen: subtitle description")
                                .font(AppTypography.subtitle)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }
                        .padding(.top, AppSpacing.lg)

                        // Puntos informativos
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            infoRow(
                                icon: "arrow.up.right.circle.fill",
                                title: "Datos Enviados",
                                desc: "Únicamente se enviará a la IA el fragmento o párrafo del documento que selecciones activamente. Nunca se enviará tu biblioteca completa.",
                                theme: theme
                            )

                            infoRow(
                                icon: "lock.shield.fill",
                                title: "Privacidad y Procesamiento",
                                desc: "El procesamiento se realiza a través de Gemini API en la nube segura de Supabase. Los fragmentos se procesan temporalmente en memoria y no son almacenados ni utilizados para entrenar modelos de IA.",
                                theme: theme
                            )

                            infoRow(
                                icon: "slider.horizontal.3",
                                title: "Control Total",
                                desc: "Puedes revocar o volver a otorgar este consentimiento en cualquier momento desde los ajustes de tu perfil.",
                                theme: theme
                            )
                        }
                        .padding(AppSpacing.lg)
                        .background(AppColor.surface(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                }

                // Botones de acción
                VStack(spacing: AppSpacing.md) {
                    Button {
                        dependencies.aiService.hasConsentedToAI = true
                        onCompletion(true)
                        dismiss()
                    } label: {
                        Text(String(localized: "Aceptar y Activar IA", comment: "Consent action: accept"))
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(AppColor.accent(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }

                    Button {
                        dependencies.aiService.hasConsentedToAI = false
                        onCompletion(false)
                        dismiss()
                    } label: {
                        Text(String(localized: "Ahora no", comment: "Consent action: skip"))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    .padding(.bottom, AppSpacing.xs)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColor.background(for: theme))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cerrar", comment: "Consent screen: close button")) {
                        onCompletion(false)
                        dismiss()
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func infoRow(icon: String, title: String, desc: String, theme: AppTheme) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppColor.accent(for: theme))

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                Text(desc)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .lineLimit(nil)
            }
        }
    }
}

// MARK: - Preview

#Preview("Consent") {
    let themeManager = ThemeManager()
    AIConsentView { _ in }
        .environment(themeManager)
        .environment(AppDependencies.preview)
}
