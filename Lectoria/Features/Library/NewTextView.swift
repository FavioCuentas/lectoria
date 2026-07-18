import SwiftUI

struct NewTextView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(String(localized: "Título", comment: "New text: title label"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    TextField(
                        String(localized: "Escribe un título para este documento…", comment: "New text: title placeholder"),
                        text: $title
                    )
                    .font(AppTypography.body)
                    .padding(AppSpacing.md)
                    .background(AppColor.surface(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(AppColor.border(for: theme), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(String(localized: "Contenido", comment: "New text: content label"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    TextEditor(text: $content)
                        .font(AppTypography.body)
                        .padding(AppSpacing.xs)
                        .frame(maxHeight: .infinity)
                        .background(AppColor.surface(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColor.border(for: theme), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, AppSpacing.lg)
            }
            .padding(.top, AppSpacing.md)
            .background(AppColor.background(for: theme))
            .navigationTitle(String(localized: "Nuevo texto", comment: "New text screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancelar", comment: "Generic: cancel")) {
                        dismiss()
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Guardar", comment: "Generic: save")) {
                        saveText()
                    }
                    .font(AppTypography.body.bold())
                    .foregroundStyle(AppColor.accent(for: theme))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    private func saveText() {
        guard !title.isEmpty, !content.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let record = try await dependencies.importService.importPastedText(text: content, title: title)
                isLoading = false
                dismiss()
                // Navegar automáticamente al nuevo texto
                router.selectedPublication = record
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
