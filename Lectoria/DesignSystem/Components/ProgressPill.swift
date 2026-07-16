import SwiftUI

// MARK: - ProgressPill

/// Indicador de progreso de lectura en formato píldora.
///
/// Muestra una barra de progreso con porcentaje. Disponible
/// en modo normal (para cards de cuadrícula) y compacto (para listas).
struct ProgressPill: View {
    let progress: Double
    let compact: Bool

    @Environment(ThemeManager.self) private var themeManager

    init(progress: Double, compact: Bool = false) {
        self.progress = min(max(progress, 0), 1)
        self.compact = compact
    }

    var body: some View {
        let theme = themeManager.currentTheme
        let isComplete = progress >= 1.0

        HStack(spacing: AppSpacing.xs) {
            if !compact {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppRadius.full)
                            .fill(AppColor.border(for: theme))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: AppRadius.full)
                            .fill(isComplete
                                  ? AppColor.success(for: theme)
                                  : AppColor.accent(for: theme))
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Text(isComplete
                 ? String(localized: "Terminado", comment: "Reading progress: finished")
                 : "\(Int(progress * 100))%")
                .font(AppTypography.caption)
                .foregroundStyle(isComplete
                    ? AppColor.success(for: theme)
                    : AppColor.textSecondary(for: theme))
        }
        .accessibilityLabel(String(localized: "Progreso: \(Int(progress * 100)) por ciento",
                                   comment: "Progress accessibility label"))
    }
}

// MARK: - Preview

#Preview("Progress Pills") {
    let themeManager = ThemeManager()
    VStack(spacing: AppSpacing.lg) {
        ProgressPill(progress: 0)
        ProgressPill(progress: 0.25)
        ProgressPill(progress: 0.5)
        ProgressPill(progress: 0.75)
        ProgressPill(progress: 1.0)

        Divider()

        HStack(spacing: AppSpacing.md) {
            ProgressPill(progress: 0.33, compact: true)
            ProgressPill(progress: 0.67, compact: true)
            ProgressPill(progress: 1.0, compact: true)
        }
    }
    .padding()
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
