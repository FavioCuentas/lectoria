import SwiftUI

// MARK: - PresenterNotesView

/// Componente para visualizar las notas originales del presentador extraídas del archivo de la presentación.
/// Mantiene las notas del presentador diferenciadas de las notas personales del usuario.
struct PresenterNotesView: View {
    let slideIndex: Int
    let presenterNote: String?

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColor.accent(for: theme))

                Text(String(localized: "Notas del Presentador (Slide \(slideIndex + 1))", comment: "Presenter notes title"))
                    .font(AppTypography.captionBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
            }

            if let note = presenterNote, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .padding(AppSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surfaceSecondary(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
            } else {
                Text(String(localized: "Este slide no contiene notas del presentador.", comment: "No presenter notes placeholder"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .italic()
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColor.surface(for: theme))
    }
}
