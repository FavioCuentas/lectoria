import SwiftUI

// MARK: - TranslationSheetView

/// Hoja interactiva para traducción local offline de fragmentos de lectura.
struct TranslationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let originalText: String

    @State private var targetLanguage = "es"
    @State private var translatedText: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCopied = false
    @State private var showPaywall = false

    private let languages = [
        ("es", "Español"),
        ("en", "Inglés"),
        ("fr", "Francés"),
        ("de", "Alemán"),
        ("pt", "Portugués"),
        ("it", "Italiano")
    ]

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Texto original
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Texto original", comment: "Translation sheet header")
                            .font(AppTypography.caption.weight(.bold))
                            .foregroundStyle(AppColor.textSecondary(for: theme))

                        Text(originalText)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColor.surface(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }

                    // Selección de idioma de destino
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Traducir a:", comment: "Translation sheet target label")
                            .font(AppTypography.caption.weight(.bold))
                            .foregroundStyle(AppColor.textSecondary(for: theme))

                        Picker("Idioma de destino", selection: $targetLanguage) {
                            ForEach(languages, id: \.0) { code, name in
                                Text(name).tag(code)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Botón de acción de traducción
                    Button {
                        performTranslation()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "character.book.closed.fill")
                                Text("Traducir Localmente", comment: "Translate button action")
                            }
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(.white)
                        }
                    }
                    .disabled(isLoading)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColor.accent(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                    // Error o resultado de traducción
                    if let errorMessage {
                        VStack(spacing: AppSpacing.sm) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(Color.orange)
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textPrimary(for: theme))
                            }
                            .padding(AppSpacing.md)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

                            Button("Ver Planes Premium") {
                                showPaywall = true
                            }
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColor.accent(for: theme))
                        }
                    }

                    if let translatedText {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text("Resultado local:", comment: "Translation result header")
                                    .font(AppTypography.caption.weight(.bold))
                                    .foregroundStyle(AppColor.textSecondary(for: theme))

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = translatedText
                                    isCopied = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        await MainActor.run { isCopied = false }
                                    }
                                } label: {
                                    Label(isCopied ? "¡Copiado!" : "Copiar", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                                        .font(AppTypography.caption.weight(.semibold))
                                        .foregroundStyle(AppColor.accent(for: theme))
                                }
                            }

                            Text(translatedText)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                .padding(AppSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColor.surface(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        }
                    }

                    Spacer(minLength: AppSpacing.md)

                    // Advertencia legal obligatoria de IA
                    Text(AIDisclaimer.text)
                        .font(.system(size: 10))
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xs)
                }
                .padding(AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Traducción Local")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(AppTypography.body)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func performTranslation() {
        isLoading = true
        errorMessage = nil

        Task {
            let service = LocalTranslationService(entitlementService: dependencies.entitlementService)
            do {
                let result = try await service.translate(text: originalText, targetLanguage: targetLanguage)
                await MainActor.run {
                    self.translatedText = result
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
}
