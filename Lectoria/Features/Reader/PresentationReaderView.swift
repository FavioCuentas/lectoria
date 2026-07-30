import SwiftUI
import QuickLook

// MARK: - PresentationReaderView

/// Vista principal de lectura de presentaciones PowerPoint (`.ppt` y `.pptx`) de alta fidelidad.
///
/// Integra el visor nativo Quick Look con el sistema de navegación, diseño y barra de herramientas de Lectoria.
struct PresentationReaderView: View {
    let record: PublicationRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var fileURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    var body: some View {
        let theme = themeManager.currentTheme

        VStack(spacing: 0) {
            // Barra de herramientas superior personalizada
            HStack(spacing: AppSpacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .frame(width: 36, height: 36)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Volver")

                Text(record.title)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .lineLimit(1)

                Spacer()

                if let fileURL {
                    ShareLink(item: fileURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .frame(width: 36, height: 36)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColor.surface(for: theme))

            Divider()
                .background(AppColor.border(for: theme))

            // Visor principal
            ZStack {
                AppColor.background(for: theme)
                    .ignoresSafeArea()

                if let fileURL, errorMessage == nil {
                    QuickLookPreviewWrapper(fileURL: fileURL)
                } else if isLoading {
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColor.accent(for: theme))
                        Text(String(localized: "Cargando presentación…", comment: "Reader: loading presentation"))
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                } else if let errorMessage {
                    errorView(message: errorMessage, theme: theme)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await resolveAndPrepareFile()
        }
    }

    // MARK: - File Resolution

    private func resolveAndPrepareFile() async {
        isLoading = true
        errorMessage = nil

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            errorMessage = String(localized: "No se pudo acceder al directorio de almacenamiento.", comment: "Storage error")
            isLoading = false
            return
        }

        let targetURL = appSupport.appendingPathComponent("Publications/\(record.localFileName)")

        if FileManager.default.fileExists(atPath: targetURL.path) {
            self.fileURL = targetURL
            self.isLoading = false
        } else {
            // Intentar buscar en directorio temporal si fue recién importado
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(record.localFileName)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                self.fileURL = tempURL
                self.isLoading = false
            } else {
                self.errorMessage = String(localized: "El archivo de la presentación no fue encontrado en el almacenamiento local.", comment: "File missing error")
                self.isLoading = false
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String, theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.warning(for: theme))

            VStack(spacing: AppSpacing.xs) {
                Text(String(localized: "Error de lectura", comment: "Presentation error title"))
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            HStack(spacing: AppSpacing.md) {
                Button {
                    Task {
                        await resolveAndPrepareFile()
                    }
                } label: {
                    Label(String(localized: "Reintentar", comment: "Retry button"), systemImage: "arrow.clockwise")
                        .font(AppTypography.callout.weight(.semibold))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColor.accent(for: theme))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "Volver a la Biblioteca", comment: "Back button"))
                        .font(AppTypography.callout)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColor.surfaceSecondary(for: theme))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppSpacing.xl)
    }
}
