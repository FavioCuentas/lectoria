import SwiftUI

// MARK: - AboutView

/// Perfil → Acerca de Lectoria: versión, qué es la app y licencias de código abierto.
struct AboutView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        let theme = themeManager.currentTheme
        let environment = AppEnvironment.current()

        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityHidden(true)
                    .padding(.top, AppSpacing.lg)

                VStack(spacing: AppSpacing.xxs) {
                    Text(verbatim: "Lectoria")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text(String(localized: "Versión \(environment.appVersion) (\(environment.buildNumber))",
                                comment: "About: version and build"))
                        .font(AppTypography.footnote)
                        .monospacedDigit()
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }

                Text(String(localized: "Una biblioteca tranquila para leer y estudiar tus libros y documentos: EPUB, PDF, PowerPoint y texto, con destacados, notas y búsqueda en todo lo que guardas.",
                            comment: "About: app description"))
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    NavigationLink {
                        LicensesView()
                    } label: {
                        HStack {
                            Label(String(localized: "Licencias de código abierto", comment: "About: open source licenses"),
                                  systemImage: "doc.plaintext")
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColor.textTertiary(for: theme))
                        }
                        .font(AppTypography.body)
                        .padding(.vertical, AppSpacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Acerca de", comment: "About screen title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - LicensesView

/// Texto completo de las licencias de las librerías incluidas (`Resources/Licencias.txt`).
struct LicensesView: View {
    @Environment(ThemeManager.self) private var themeManager

    private var text: String {
        guard let url = Bundle.main.url(forResource: "Licencias", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return content
    }

    var body: some View {
        let theme = themeManager.currentTheme
        ScrollView {
            Text(verbatim: text)
                .font(.caption.monospaced())
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Licencias", comment: "Licenses screen title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
