import SwiftUI
import UniformTypeIdentifiers

// MARK: - RootView

/// Vista raíz de la aplicación con TabView de 4 tabs.
///
/// Controla la navegación principal entre Inicio, Biblioteca,
/// Notas y Perfil. Incluye un botón de importar accesible
/// sin romper las convenciones de iOS.
struct RootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies

    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var importedRecord: PublicationRecord? = nil
    @State private var showImportStatus = false

    var body: some View {
        @Bindable var router = router
        let theme = themeManager.currentTheme

        ZStack {
            TabView(selection: $router.selectedTab) {
                Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
                    NavigationStack {
                        HomeView()
                    }
                }

                Tab(AppTab.library.title, systemImage: AppTab.library.systemImage, value: .library) {
                    NavigationStack {
                        LibraryView()
                    }
                }

                Tab(AppTab.notes.title, systemImage: AppTab.notes.systemImage, value: .notes) {
                    NavigationStack {
                        NotesView()
                    }
                }

                Tab(AppTab.profile.title, systemImage: AppTab.profile.systemImage, value: .profile) {
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            .tint(AppColor.accent(for: theme))
            .preferredColorScheme(theme.colorScheme)
            
            // Globo de estado de importación con blur y opciones
            if showImportStatus {
                importStatusOverlay(theme: theme)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .fileImporter(
            isPresented: $router.isShowingImport,
            allowedContentTypes: [
                .pdf,
                UTType(filenameExtension: "epub") ?? .data,
                .plainText,
                UTType(filenameExtension: "md") ?? .plainText
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFile(at: url)
                }
            case .failure(let error):
                print("Error al seleccionar archivo: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $router.isShowingNewText) {
            NewTextView()
        }
    }

    private func importFile(at url: URL) {
        withAnimation(.spring(response: 0.3)) {
            isImporting = true
            importError = nil
            importedRecord = nil
            showImportStatus = true
        }

        Task {
            do {
                let record = try await dependencies.importService.importPublication(from: url)
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        self.importedRecord = record
                        self.isImporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) {
                        self.importError = error.localizedDescription
                        self.isImporting = false
                    }
                }
            }
        }
    }

    private func importStatusOverlay(theme: AppTheme) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isImporting {
                        withAnimation(.spring(response: 0.3)) {
                            showImportStatus = false
                        }
                    }
                }
            
            VStack(spacing: AppSpacing.lg) {
                if isImporting {
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColor.accent(for: theme))
                            .padding(.top, AppSpacing.sm)
                        
                        Text("Importando documento…")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                        
                        Text("Preparando el lector y guardando el archivo de forma segura.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let error = importError {
                    let isDuplicate = error.localizedCaseInsensitiveContains("ya existe") || error.localizedCaseInsensitiveContains("duplicado")
                    
                    VStack(spacing: AppSpacing.md) {
                        if isDuplicate {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(AppColor.accent(for: theme))
                            
                            Text("Ya está en tu biblioteca")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                            
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                            
                            Text("No se pudo cargar")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                            
                            Text(error)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showImportStatus = false
                            }
                        } label: {
                            Text("Cerrar")
                                .font(AppTypography.callout.bold())
                                .foregroundStyle(isDuplicate ? .white : AppColor.textPrimary(for: theme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(isDuplicate ? AppColor.accent(for: theme) : AppColor.surfaceSecondary(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                } else {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                            .transition(.scale)
                        
                        Text("¡Documento importado!")
                            .font(AppTypography.bodyBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                        
                        Text(importedRecord?.title ?? "Documento")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: AppSpacing.sm) {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    showImportStatus = false
                                }
                                if let record = importedRecord {
                                    router.selectedPublication = record
                                }
                            } label: {
                                Text("Empezar a leer")
                                    .font(AppTypography.callout.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(AppColor.accent(for: theme))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            }
                            
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    showImportStatus = false
                                }
                            } label: {
                                Text("Volver a la biblioteca")
                                    .font(AppTypography.callout)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppSpacing.md)
                                    .background(AppColor.surfaceSecondary(for: theme))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            }
                        }
                        .padding(.top, AppSpacing.sm)
                    }
                }
            }
            .padding(AppSpacing.xl)
            .frame(maxWidth: 320)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Preview

#Preview("Root View") {
    let themeManager = ThemeManager()
    let router = AppRouter()
    RootView()
        .environment(themeManager)
        .environment(router)
}
