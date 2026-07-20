import SwiftUI

// MARK: - AIResponseSheet

/// Vista modal que gestiona la carga de la petición de IA, muestra la respuesta y permite guardarla como nota.
struct AIResponseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let actionName: String
    let textToProcess: String
    let targetLanguage: String? // Opcional, solo para traducción
    let onSaveAsNote: (String) -> Void

    @State private var responseText = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var isSaved = false

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: AppSpacing.md) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColor.accent(for: theme))
                        
                        Text("Lectoria AI está procesando tu solicitud...",
                             comment: "AI sheet: loading message")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                } else if let errorMessage {
                    VStack(spacing: AppSpacing.md) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColor.error(for: theme))
                        
                        Text(errorMessage)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .multilineTextAlignment(.center)
                        
                        Button {
                            self.errorMessage = nil
                            self.isLoading = true
                            Task {
                                await runAIRequest()
                            }
                        } label: {
                            Text(String(localized: "Reintentar", comment: "Alert action: retry"))
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.lg)
                                .frame(height: 40)
                                .background(AppColor.accent(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.lg)
                } else {
                    // Contenido cargado con éxito
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(actionTitle)
                                .font(AppTypography.title)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                .padding(.top, AppSpacing.md)
                            
                            // Caja de texto de origen (grounding)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Texto seleccionado:")
                                    .font(AppTypography.footnote.weight(.semibold))
                                    .foregroundStyle(AppColor.textTertiary(for: theme))
                                
                                Text("\"\(textToProcess)\"")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                    .lineLimit(3)
                            }
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColor.surface(for: theme).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            
                            Divider()
                            
                            // Respuesta de la IA
                            Text(responseText)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                .lineSpacing(AppTypography.defaultLineSpacing)
                                .textSelection(.enabled)
                                .padding(.vertical, AppSpacing.xs)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    
                    // Barra inferior de acciones
                    VStack(spacing: AppSpacing.md) {
                        Divider()
                        
                        HStack(spacing: AppSpacing.md) {
                            Button {
                                UIPasteboard.general.string = responseText
                            } label: {
                                Label("Copiar", systemImage: "doc.on.doc")
                                    .font(AppTypography.bodyBold)
                                    .foregroundStyle(AppColor.textPrimary(for: theme))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AppColor.surface(for: theme))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.sm)
                                            .stroke(AppColor.accent(for: theme).opacity(0.15), lineWidth: 1)
                                    )
                            }

                            Button {
                                onSaveAsNote(responseText)
                                isSaved = true
                                dismiss()
                            } label: {
                                Label(
                                    isSaved ? "Guardado" : "Guardar como nota",
                                    systemImage: isSaved ? "checkmark" : "note.text.badge.plus"
                                )
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(isSaved ? Color.green : AppColor.accent(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            }
                            .disabled(isSaved)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontal)
                        .padding(.bottom, AppSpacing.lg)
                    }
                    .background(AppColor.background(for: theme))
                }
            }
            .background(AppColor.background(for: theme))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cerrar", comment: "AI response screen: close button")) {
                        dismiss()
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await runAIRequest()
            }
        }
    }

    private var actionTitle: String {
        if actionName.hasPrefix("translate") { return "Traducción de IA" }
        switch actionName {
        case "explain": return "Explicación de IA"
        case "simplify": return "Concepto Simplificado"
        case "summarize": return "Resumen de IA"
        case "generateQuestions": return "Preguntas de Estudio"
        default: return "Lectoria AI"
        }
    }

    private func runAIRequest() async {
        let token = dependencies.authService.sessionToken
        
        do {
            let result: String
            if actionName.hasPrefix("translate") {
                let lang: String
                if actionName.hasPrefix("translate_") {
                    lang = String(actionName.dropFirst("translate_".count))
                } else {
                    lang = targetLanguage ?? "en"
                }
                result = try await dependencies.aiService.translate(text: textToProcess, targetLanguage: lang, sessionToken: token)
            } else {
            switch actionName {
            case "explain":
                result = try await dependencies.aiService.explain(text: textToProcess, sessionToken: token)
            case "simplify":
                result = try await dependencies.aiService.simplify(text: textToProcess, sessionToken: token)
            case "summarize":
                result = try await dependencies.aiService.summarize(text: textToProcess, sessionToken: token)
            case "generateQuestions":
                result = try await dependencies.aiService.generateQuestions(text: textToProcess, sessionToken: token)
            default:
                result = ""
            }
            }

            // Registrar el consumo de IA localmente para control de límites
            let usage = AIUsage(
                id: UUID(),
                userID: dependencies.authService.currentUser?.id,
                operation: actionName,
                creditCost: 1
            )
            try? await dependencies.aiUsageRepository.save(usage)

            await MainActor.run {
                self.responseText = result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview("AI Response") {
    let themeManager = ThemeManager()
    AIResponseSheet(
        actionName: "explain",
        textToProcess: "Este párrafo explica el principio de la relatividad especial y la velocidad de la luz en el vacío.",
        targetLanguage: nil,
        onSaveAsNote: { _ in }
    )
    .environment(themeManager)
    .environment(AppDependencies.preview)
}
