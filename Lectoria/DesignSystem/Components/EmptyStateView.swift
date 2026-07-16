import SwiftUI

// MARK: - EmptyStateView

/// Vista para estados vacíos con icono, título, subtítulo y acción opcional.
///
/// Usada cuando una sección no tiene datos: biblioteca vacía,
/// sin notas, sin resultados de búsqueda, etc.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .padding(.bottom, AppSpacing.xs)

            Text(title)
                .font(.system(.title3, design: .serif))
                .fontWeight(.bold)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)

            if let actionTitle, let action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.horizontal, AppSpacing.huge)
                    .padding(.top, AppSpacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview("Empty States") {
    let themeManager = ThemeManager()
    TabView {
        EmptyStateView(
            icon: "books.vertical",
            title: "Tu biblioteca está vacía",
            subtitle: "Importa tu primer EPUB, PDF o archivo de texto para comenzar a leer.",
            actionTitle: "Importar documento"
        ) {}

        EmptyStateView(
            icon: "note.text",
            title: "Sin notas todavía",
            subtitle: "Las notas y destacados que crees mientras lees aparecerán aquí."
        )

        EmptyStateView(
            icon: "magnifyingglass",
            title: "Sin resultados",
            subtitle: "No se encontraron documentos que coincidan con tu búsqueda."
        )
    }
    .tabViewStyle(.page)
    .background(AppColor.background(for: themeManager.currentTheme))
    .environment(themeManager)
}
