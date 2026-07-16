import SwiftUI
import ReadiumShared
import ReadiumNavigator

// MARK: - EPUBReaderView

/// Pantalla del lector de libros EPUB.
///
/// Integra el adaptador Readium con el Design System de Lectoria,
/// ofreciendo una experiencia inmersiva con controles de formato
/// (tamaño de fuente, scroll vs paginación, temas claro/oscuro/sepia),
/// índice interactivo y autoguardado de progreso.
struct EPUBReaderView: View {
    let record: PublicationRecord
    
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // Estado del ciclo de vida del lector
    @State private var adapter = EPUBReaderAdapter()
    @State private var isLoading = true
    @State private var loadingError: String? = nil
    
    // Ubicación de lectura y navegación
    @State private var initialLocation: EPUBLocation? = nil
    @State private var currentLocation: EPUBLocation? = nil
    @State private var targetLocation: EPUBLocation? = nil
    @State private var tocItems: [TOCItem] = []

    // Controles de interfaz de usuario
    @State private var showUI = true
    @State private var showTOC = false
    @State private var showSettings = false

    // Preferencias del usuario (persistidas o inicializadas por defecto)
    @State private var fontSize: Double = 1.0
    @State private var isScrollMode = false

    var body: some View {
        let appTheme = themeManager.currentTheme

        ZStack {
            // Fondo adaptado al tema actual de lectura
            AppColor.background(for: appTheme)
                .ignoresSafeArea()

            if isLoading {
                loadingView(theme: appTheme)
            } else if let error = loadingError {
                errorView(error, theme: appTheme)
            } else if let publication = adapter.publication {
                // Wrapper del visor de Readium
                EPUBNavigatorWrapper(
                    publication: publication,
                    initialLocation: initialLocation,
                    currentLocation: $currentLocation,
                    preferences: epubPreferences,
                    onTap: { _ in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showUI.toggle()
                        }
                    },
                    targetLocation: targetLocation
                )
                .ignoresSafeArea(.all, edges: showUI ? [] : .all)
            }

            // Capa de Controles y Barras Superpuestas
            if !isLoading && loadingError == nil {
                overlaysView(theme: appTheme)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(!showUI)
        .task {
            await loadBook()
        }
        .onChange(of: currentLocation) { _, newValue in
            if let newValue {
                saveReadingProgress(location: newValue)
            }
        }
    }

    // MARK: - Loading & Error States

    private func loadingView(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColor.accent(for: theme))
            Text(String(localized: "Abriendo libro…", comment: "Reader: loading book"))
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
    }

    private func errorView(_ message: String, theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(AppColor.error(for: theme))
            
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button {
                Task { await loadBook() }
            } label: {
                Text(String(localized: "Reintentar", comment: "Reader: retry opening"))
                    .font(AppTypography.bodyBold)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.accent(for: theme))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
        }
    }

    // MARK: - Overlays & Bars

    private func overlaysView(theme: AppTheme) -> some View {
        VStack {
            if showUI {
                // Barra Superior
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    
                    Spacer()
                    
                    Text(record.title)
                        .font(AppTypography.bodyBold)
                        .lineLimit(1)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    
                    Spacer()
                    
                    // Botón de Formato / Preferencias
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "textformat")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    
                    // Botón del Índice / TOC
                    Button {
                        showTOC.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                            .padding(AppSpacing.md)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, safeAreaTop)
                .background(
                    AppColor.surface(for: theme)
                        .shadow(color: AppShadow.subtle(for: theme).color,
                                radius: AppShadow.subtle(for: theme).radius,
                                x: AppShadow.subtle(for: theme).x,
                                y: AppShadow.subtle(for: theme).y)
                )
                .transition(.move(edge: .top))
            }
            
            Spacer()
            
            if showUI {
                // Barra Inferior (Progreso)
                VStack(spacing: AppSpacing.sm) {
                    let progressPercent = currentLocation?.locator.locations.totalProgression ?? 0.0
                    
                    HStack {
                        Text(currentLocation?.locator.title ?? "Capítulo")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", progressPercent * 100))
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    ProgressView(value: progressPercent, total: 1.0)
                        .tint(AppColor.accent(for: theme))
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.vertical, AppSpacing.md)
                .background(
                    AppColor.surface(for: theme)
                        .shadow(color: AppShadow.subtle(for: theme).color,
                                radius: AppShadow.subtle(for: theme).radius,
                                x: AppShadow.subtle(for: theme).x,
                                y: AppShadow.subtle(for: theme).y)
                )
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
        // Hojas secundarias
        .sheet(isPresented: $showTOC) {
            tocSheet(theme: theme)
        }
        .sheet(isPresented: $showSettings) {
            settingsSheet(theme: theme)
        }
    }

    // MARK: - Table of Contents Sheet

    private func tocSheet(theme: AppTheme) -> some View {
        NavigationStack {
            List(tocItems) { item in
                let data = item.locationData
                Button {
                    if !data.isEmpty,
                       let location = try? JSONDecoder().decode(EPUBLocation.self, from: data) {
                        targetLocation = location
                        showTOC = false
                    }
                } label: {
                    HStack {
                        Text(item.title)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                        Spacer()
                    }
                }
                .listRowBackground(AppColor.surface(for: theme))
            }
            .background(AppColor.background(for: theme))
            .scrollContentBackground(.hidden)
            .navigationTitle("Índice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { showTOC = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Settings Sheet (Format & Theme)

    private func settingsSheet(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Text("Opciones de lectura")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .padding(.top, AppSpacing.lg)

            // Selector de Tema
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tema")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                
                HStack(spacing: AppSpacing.md) {
                    ForEach(AppTheme.allCases) { item in
                        Button {
                            withAnimation {
                                themeManager.currentTheme = item
                            }
                        } label: {
                            Text(item.displayName)
                                .font(AppTypography.callout)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(themeManager.currentTheme == item ? AppColor.accent(for: theme) : AppColor.surfaceSecondary(for: theme))
                                .foregroundStyle(themeManager.currentTheme == item ? .white : AppColor.textPrimary(for: theme))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(AppColor.border(for: theme), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Selector de Tamaño de Fuente
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Tamaño de letra")
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                
                HStack {
                    Button {
                        if fontSize > 0.6 { fontSize -= 0.1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .padding()
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%%", fontSize * 100))
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    
                    Spacer()
                    
                    Button {
                        if fontSize < 2.0 { fontSize += 0.1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .padding()
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                    }
                }
                .background(AppColor.surfaceSecondary(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .padding(.horizontal, AppSpacing.lg)

            // Dirección de Lectura (Scroll vs Páginas)
            Toggle(isOn: $isScrollMode) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Desplazamiento continuo")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text("Desplazar verticalmente en lugar de paginar")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .tint(AppColor.accent(for: theme))
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .padding(.bottom, AppSpacing.xxl)
        .background(AppColor.surface(for: theme))
        .presentationDetents([.height(350)])
    }

    // MARK: - Book Lifecycle

    private func loadBook() async {
        isLoading = true
        loadingError = nil
        
        do {
            // 1. Cargar el último progreso guardado de base de datos
            if let savedProgress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: record.id),
               let data = savedProgress.locatorJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(EPUBLocation.self, from: data) {
                self.initialLocation = decoded
                self.currentLocation = decoded
            }
            
            // 2. Abrir la publicación con el adaptador de Readium
            try await adapter.open(publication: record)
            
            // 3. Extraer la Tabla de Contenidos
            self.tocItems = (try? await adapter.tableOfContents()) ?? []
            
            self.isLoading = false
        } catch {
            self.loadingError = error.localizedDescription
            self.isLoading = false
        }
    }

    private func saveReadingProgress(location: EPUBLocation) {
        Task {
            let percentage = location.locator.locations.totalProgression ?? 0.0
            let chapterTitle = location.locator.title ?? location.locator.href.string
            let locatorJSON = (try? String(data: JSONEncoder().encode(location), encoding: .utf8)) ?? ""
            
            let progress = ReadingProgress(
                publicationID: record.id,
                locatorJSON: locatorJSON,
                percentage: percentage,
                chapterTitle: chapterTitle,
                deviceID: "iOS-Simulator",
                version: 1
            )
            try? await dependencies.readingProgressRepository.saveProgress(progress)
        }
    }

    // MARK: - Helpers

    private var epubPreferences: EPUBPreferences {
        let readiumTheme: ReadiumNavigator.Theme
        switch themeManager.currentTheme {
        case .light: readiumTheme = .light
        case .dark: readiumTheme = .dark
        case .sepia: readiumTheme = .sepia
        }
        
        return EPUBPreferences(
            fontSize: fontSize,
            scroll: isScrollMode,
            theme: readiumTheme
        )
    }

    private var safeAreaTop: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.top ?? 20
    }
}
