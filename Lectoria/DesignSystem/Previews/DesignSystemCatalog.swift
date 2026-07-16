import SwiftUI

// MARK: - DesignSystemCatalog

/// Vista catálogo que muestra todos los componentes del Design System.
///
/// Útil para desarrollo, revisión visual y verificación de temas.
/// No se incluye en el build de producción.
struct DesignSystemCatalog: View {
    @State private var themeManager = ThemeManager()
    @State private var toggleValue = true

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                    // Theme selector
                    themeSelectorSection(theme: theme)

                    Divider()

                    // Colors
                    colorsSection(theme: theme)

                    Divider()

                    // Typography
                    typographySection(theme: theme)

                    Divider()

                    // Buttons
                    buttonsSection(theme: theme)

                    Divider()

                    // Cards
                    cardsSection(theme: theme)

                    Divider()

                    // Components
                    componentsSection(theme: theme)

                    Divider()

                    // States
                    statesSection(theme: theme)
                }
                .padding(AppSpacing.screenHorizontal)
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Design System")
            .preferredColorScheme(theme.colorScheme)
        }
        .environment(themeManager)
    }

    // MARK: - Theme Selector

    private func themeSelectorSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Tema", theme: theme)

            HStack(spacing: AppSpacing.md) {
                ForEach(AppTheme.allCases) { appTheme in
                    Button {
                        withAnimation { themeManager.currentTheme = appTheme }
                    } label: {
                        Text(appTheme.displayName)
                            .font(AppTypography.captionBold)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(appTheme == theme ? AppColor.accent(for: theme) : AppColor.surface(for: theme))
                            .foregroundStyle(appTheme == theme ? .white : AppColor.textPrimary(for: theme))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Colors

    private func colorsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Colores", theme: theme)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: AppSpacing.sm) {
                colorSwatch("Background", AppColor.background(for: theme), theme: theme)
                colorSwatch("Surface", AppColor.surface(for: theme), theme: theme)
                colorSwatch("Surface 2", AppColor.surfaceSecondary(for: theme), theme: theme)
                colorSwatch("Accent", AppColor.accent(for: theme), theme: theme)
                colorSwatch("Accent 2", AppColor.accentSecondary(for: theme), theme: theme)
                colorSwatch("Border", AppColor.border(for: theme), theme: theme)
                colorSwatch("Success", AppColor.success(for: theme), theme: theme)
                colorSwatch("Warning", AppColor.warning(for: theme), theme: theme)
                colorSwatch("Error", AppColor.error(for: theme), theme: theme)
            }

            sectionTitle("Destacados", theme: theme)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: AppSpacing.sm) {
                colorSwatch("Idea", AppColor.highlightMainIdea(for: theme), theme: theme)
                colorSwatch("Duda", AppColor.highlightQuestion(for: theme), theme: theme)
                colorSwatch("Evidencia", AppColor.highlightEvidence(for: theme), theme: theme)
                colorSwatch("Acción", AppColor.highlightAction(for: theme), theme: theme)
                colorSwatch("Cita", AppColor.highlightQuote(for: theme), theme: theme)
            }
        }
    }

    private func colorSwatch(_ name: String, _ color: Color, theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .fill(color)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 0.5)
                )
            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
    }

    // MARK: - Typography

    private func typographySection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Tipografía", theme: theme)

            Text("Large Title").font(AppTypography.largeTitle)
            Text("Title").font(AppTypography.title)
            Text("Title 2").font(AppTypography.title2)
            Text("Subtitle").font(AppTypography.subtitle)
            Text("Body").font(AppTypography.body)
            Text("Body Bold").font(AppTypography.bodyBold)
            Text("Callout").font(AppTypography.callout)
            Text("Footnote").font(AppTypography.footnote)
            Text("Caption").font(AppTypography.caption)
            Text("Reader (New York)").font(AppTypography.readerFont(size: 18))
        }
        .foregroundStyle(AppColor.textPrimary(for: theme))
    }

    // MARK: - Buttons

    private func buttonsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Botones", theme: theme)

            PrimaryButton("Botón primario", icon: "plus.circle.fill") {}
            PrimaryButton("Cargando…", isLoading: true) {}
            SecondaryButton("Botón secundario", icon: "arrow.right") {}

            HStack(spacing: AppSpacing.md) {
                IconButton(icon: "bookmark", label: "Marcador") {}
                IconButton(icon: "magnifyingglass", label: "Buscar") {}
                IconButton(icon: "ellipsis", label: "Más", size: .small) {}
                IconButton(icon: "textformat.size", label: "Apariencia", size: .large) {}
            }
        }
    }

    // MARK: - Cards

    private func cardsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Publication Cards", theme: theme)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: AppSpacing.md) {
                PublicationCard(publication: .previewEPUB, progress: 0.45) {}
                PublicationCard(publication: .previewPDF, progress: 0.12) {}
            }

            PublicationCard(publication: .previewTXT, style: .list, progress: 0.8) {}
            PublicationCard(publication: .previewMarkdown, style: .list) {}
        }
    }

    // MARK: - Components

    private func componentsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Componentes", theme: theme)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    FilterChip("Todos", isSelected: true) {}
                    FilterChip("EPUB", icon: "book") {}
                    FilterChip("PDF", icon: "doc.richtext") {}
                    FilterChip("Favoritos", icon: "heart", isSelected: true) {}
                }
            }

            // Progress pills
            HStack(spacing: AppSpacing.lg) {
                ProgressPill(progress: 0.33)
                ProgressPill(progress: 0.67, compact: true)
                ProgressPill(progress: 1.0, compact: true)
            }

            // Settings rows
            VStack(spacing: 0) {
                SettingsRow(icon: "paintbrush", title: "Apariencia", variant: .value("Claro")) {}
                Divider()
                SettingsRow(icon: "bell", title: "Notificaciones", variant: .toggle($toggleValue)) {}
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

            // Paywall features
            PaywallFeatureRow(icon: "infinity", title: "Documentos ilimitados", subtitle: "Sin límite en tu biblioteca")
            PaywallFeatureRow(icon: "brain", title: "IA con cuota", subtitle: "Resúmenes y preguntas de estudio")

            // Reader toolbar
            ReaderToolbar()

            // Toasts
            VStack(spacing: AppSpacing.sm) {
                ToastView("Marcador añadido")
                ToastView("Error al guardar", icon: "xmark.circle.fill", style: .error)
                ToastView("Importado", icon: "doc.badge.plus", style: .info)
            }
        }
    }

    // MARK: - States

    private func statesSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionTitle("Estados", theme: theme)

            LoadingStateView("Importando documento…")
                .frame(height: 150)

            ErrorStateView(.corruptedFile(fileName: "libro.epub")) {}
                .frame(height: 200)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, theme: AppTheme) -> some View {
        Text(text)
            .font(AppTypography.title)
            .foregroundStyle(AppColor.textPrimary(for: theme))
    }
}

// MARK: - Preview

#Preview("Design System Catalog") {
    DesignSystemCatalog()
}
