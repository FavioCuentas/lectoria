import SwiftUI

// MARK: - PresentationAnnotationEditorSheet

/// Hoja modal para guardar una nota o resaltado sobre el texto seleccionado de la diapositiva,
/// permitiendo elegir cualquiera de las 5 categorías de estudio académicas de Lectoría.
struct PresentationAnnotationEditorSheet: View {
    let selectedText: String
    let slideIndex: Int
    let documentID: String
    let onSave: (PresentationAnnotation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedCategory: StudyCategory = .importante
    @State private var commentText: String = ""

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Fragmento de texto seleccionado
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(String(localized: "Texto seleccionado:", comment: "Selected text label"))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    Text("“\(selectedText)”")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .italic()
                        .padding(AppSpacing.xs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                }

                // Selector de Categoría de Estudio (5 Categorías)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(String(localized: "Categoría de estudio:", comment: "Study category label"))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    HStack(spacing: AppSpacing.xs) {
                        ForEach(StudyCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 10))
                                    Text(category.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(selectedCategory == category ? category.color.opacity(0.2) : AppColor.surfaceSecondary(for: theme))
                                .foregroundStyle(selectedCategory == category ? category.color : AppColor.textSecondary(for: theme))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == category ? category.color : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Campo de comentario personal opcional
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(String(localized: "Comentario u observación (opcional):", comment: "User comment label"))
                        .font(AppTypography.captionBold)
                        .foregroundStyle(AppColor.textSecondary(for: theme))

                    TextField(String(localized: "Añade un comentario a esta nota...", comment: "Comment placeholder"), text: $commentText, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(AppSpacing.xs)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                }

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColor.background(for: theme))
            .navigationTitle(String(localized: "Añadir Nota (Slide \(slideIndex + 1))", comment: "Add note sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancelar", comment: "Cancel button")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Guardar", comment: "Save button")) {
                        let annotation = PresentationAnnotation(
                            documentID: documentID,
                            slideID: "slide_\(slideIndex + 1)",
                            slideIndex: slideIndex,
                            selectedText: selectedText,
                            categoryID: selectedCategory.rawValue,
                            userComment: commentText.isEmpty ? nil : commentText
                        )
                        onSave(annotation)
                        dismiss()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppColor.accent(for: theme))
                }
            }
        }
    }
}
