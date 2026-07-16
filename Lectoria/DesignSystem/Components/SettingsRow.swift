import SwiftUI

// MARK: - SettingsRow

/// Fila reutilizable para pantallas de ajustes y perfil.
///
/// Soporta variantes: navegación (chevron), toggle, valor y destructiva.
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let variant: Variant
    let action: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    enum Variant {
        case navigation
        case value(String)
        case toggle(Binding<Bool>)
        case destructive
    }

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        variant: Variant = .navigation,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.variant = variant
        self.action = action
    }

    var body: some View {
        let theme = themeManager.currentTheme
        let isDestructive = if case .destructive = variant { true } else { false }

        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(AppTypography.body)
                    .foregroundStyle(
                        isDestructive
                        ? AppColor.error(for: theme)
                        : AppColor.accent(for: theme)
                    )
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.body)
                        .foregroundStyle(
                            isDestructive
                            ? AppColor.error(for: theme)
                            : AppColor.textPrimary(for: theme)
                        )

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }

                Spacer()

                trailingContent(for: theme)
            }
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func trailingContent(for theme: AppTheme) -> some View {
        switch variant {
        case .navigation:
            Image(systemName: "chevron.right")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textTertiary(for: theme))

        case .value(let value):
            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))

        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(AppColor.accent(for: theme))

        case .destructive:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Settings Rows") {
    let themeManager = ThemeManager()
    VStack(spacing: 0) {
        SettingsRow(icon: "person.circle", title: "Cuenta", subtitle: "Iniciar sesión con Apple") {}
        Divider()
        SettingsRow(icon: "paintbrush", title: "Apariencia", variant: .value("Claro")) {}
        Divider()
        SettingsRow(icon: "bell", title: "Notificaciones", variant: .toggle(.constant(true))) {}
        Divider()
        SettingsRow(icon: "globe", title: "Idioma", variant: .value("Español")) {}
        Divider()
        SettingsRow(icon: "trash", title: "Eliminar cuenta", variant: .destructive) {}
    }
    .padding(.horizontal)
    .background(AppColor.surface(for: themeManager.currentTheme))
    .environment(themeManager)
}
