import SwiftUI

// MARK: - FilterChip

/// Chip de filtro seleccionable para la biblioteca.
///
/// Usado para filtrar por formato, estado de lectura o favoritos.
/// Admite selección múltiple mediante binding booleano.
struct FilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    init(
        _ title: String,
        icon: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        let theme = themeManager.currentTheme

        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(AppTypography.caption)
                }
                Text(title)
                    .font(AppTypography.captionBold)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .foregroundStyle(
                isSelected
                ? Color.white
                : AppColor.textSecondary(for: theme)
            )
            .background(
                isSelected
                ? AppColor.accent(for: theme)
                : AppColor.surfaceSecondary(for: theme)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                        ? Color.clear
                        : AppColor.border(for: theme),
                        lineWidth: 1
                    )
            )
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview("Filter Chips") {
    let themeManager = ThemeManager()
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: AppSpacing.sm) {
            FilterChip("Todos", isSelected: true) {}
            FilterChip("EPUB", icon: "book", isSelected: false) {}
            FilterChip("PDF", icon: "doc.richtext") {}
            FilterChip("En progreso", icon: "clock") {}
            FilterChip("Favoritos", icon: "heart.fill", isSelected: true) {}
        }
        .padding()
    }
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
