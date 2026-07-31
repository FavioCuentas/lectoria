import SwiftUI
import QuickLook

// MARK: - PresentationReaderView

/// Vista principal de lectura de presentaciones PowerPoint (`.ppt` y `.pptx`) de alta fidelidad.
///
/// Integra el visor nativo Quick Look con el sistema de navegación, barra de progreso por páginas/diapositivas,
/// diálogo "Ir a página" e historial de salto de página de Lectoria.
struct PresentationReaderView: View {
    let record: PublicationRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var fileURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false

    // Control de navegación por páginas / diapositivas
    @State private var currentSlideIndex: Int = 0
    @State private var totalSlides: Int = 1
    @State private var lastJumpOriginIndex: Int? = nil
    @State private var showGoToPageDialog = false
    @State private var goToPageText = ""

    var body: some View {
        let theme = themeManager.currentTheme
        let progressPercent = Double(currentSlideIndex) / Double(max(1, totalSlides - 1))

        VStack(spacing: 0) {
            // 1. Barra de herramientas superior personalizada
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
                .accessibilityLabel(String(localized: "Volver", comment: "Back action label"))

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

            // 2. Visor principal con capas de flotación
            ZStack(alignment: .bottom) {
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

                // Botón flotante para volver a la diapositiva previa tras un salto
                if let originIndex = lastJumpOriginIndex, originIndex != currentSlideIndex {
                    Button {
                        lastJumpOriginIndex = nil
                        currentSlideIndex = originIndex
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.subheadline)
                            Text(String(localized: "Volver a pág. \(originIndex + 1)", comment: "Reader: jump back button"))
                                .font(AppTypography.captionBold)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColor.accent(for: theme))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppShadow.medium(for: theme).color,
                                radius: AppShadow.medium(for: theme).radius,
                                x: AppShadow.medium(for: theme).x,
                                y: AppShadow.medium(for: theme).y)
                    }
                    .padding(.bottom, AppSpacing.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // 3. Panel Inferior Integrado (Navegación por Diapositivas & Progreso)
            VStack(spacing: AppSpacing.xs) {
                Divider()
                    .background(AppColor.border(for: theme))

                HStack {
                    Button {
                        goToPageText = "\(currentSlideIndex + 1)"
                        showGoToPageDialog = true
                    } label: {
                        HStack(spacing: AppSpacing.xxs) {
                            Text(String(localized: "Página \(currentSlideIndex + 1) de \(totalSlides)", comment: "Reader: slide progression"))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColor.textTertiary(for: theme))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ir a número de página. Página actual \(currentSlideIndex + 1) de \(totalSlides)")

                    Spacer()

                    Button {
                        goToPageText = "\(currentSlideIndex + 1)"
                        showGoToPageDialog = true
                    } label: {
                        Text(String(format: "%.0f%%", progressPercent * 100))
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.accent(for: theme))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ir a número de página por porcentaje. Progreso actual \(Int(progressPercent * 100))%")
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xs)

                ProgressView(value: progressPercent, total: 1.0)
                    .tint(AppColor.accent(for: theme))
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
            }
            .background(
                AppColor.surface(for: theme)
                    .shadow(color: AppShadow.subtle(for: theme).color,
                            radius: AppShadow.subtle(for: theme).radius,
                            x: AppShadow.subtle(for: theme).x,
                            y: AppShadow.subtle(for: theme).y)
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .alert(String(localized: "Ir a página", comment: "Presentation jump alert title"), isPresented: $showGoToPageDialog) {
            TextField(String(localized: "Número de página (1-\(totalSlides))", comment: "Page textfield placeholder"), text: $goToPageText)
                .keyboardType(.numberPad)
            Button(String(localized: "Ir", comment: "Go to page confirm")) {
                if let page = Int(goToPageText), page >= 1 && page <= totalSlides {
                    let targetIndex = page - 1
                    if targetIndex != currentSlideIndex {
                        lastJumpOriginIndex = currentSlideIndex
                        currentSlideIndex = targetIndex
                    }
                }
            }
            Button(String(localized: "Cancelar", comment: "Cancel button"), role: .cancel) {}
        } message: {
            Text(String(localized: "Introduce el número de página al que deseas saltar.", comment: "Go to page alert message"))
        }
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

        var finalURL: URL?
        if FileManager.default.fileExists(atPath: targetURL.path) {
            finalURL = targetURL
        } else {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(record.localFileName)
            if FileManager.default.fileExists(atPath: tempURL.path) {
                finalURL = tempURL
            }
        }

        if let validURL = finalURL {
            self.fileURL = validURL
            if let parsedSlides = try? await PPTXParser.parse(url: validURL), !parsedSlides.isEmpty {
                self.totalSlides = parsedSlides.count
            }
            self.isLoading = false
        } else {
            self.errorMessage = String(localized: "El archivo de la presentación no fue encontrado en el almacenamiento local.", comment: "File missing error")
            self.isLoading = false
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
