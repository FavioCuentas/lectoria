import SwiftUI
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Home")

// MARK: - HomeView

/// Pantalla de inicio minimalista.
///
/// Diseño limpio inspirado en Kindle: saludo simple,
/// tarjeta de continuar leyendo, acciones discretas.
struct InteractiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct HomeView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppRouter.self) private var router
    @Environment(AppDependencies.self) private var dependencies
    
    @State private var lastReadPublication: PublicationRecord? = nil
    @State private var lastReadProgress: Double = 0.0
    @State private var recentPublications: [(PublicationRecord, Double)] = []
    @State private var isLoadingData = true
    @State private var selectedPublication: PublicationRecord? = nil

    var body: some View {
        @Bindable var router = router
        let theme = themeManager.currentTheme

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.xxl) {
                // Saludo
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(contextualGreeting)
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColor.textPrimary(for: theme))

                    Text(String(localized: "¿Qué vas a leer hoy?",
                                comment: "Home screen subtitle"))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                }

                if isLoadingData {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(AppColor.accent(for: theme))
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.xl)
                } else {
                    // Continuar leyendo
                    continueReadingSection(theme: theme)

                    // Acciones rápidas
                    quickActionsSection(theme: theme)

                    // Recientes
                    recentSection(theme: theme)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxxl)
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Inicio", comment: "Home screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPublication) { record in
            switch record.publicationType {
            case .pdf:
                PDFReaderView(record: record)
            case .epub:
                EPUBReaderView(record: record)
            case .txt, .markdown, .pastedText:
                TextReaderView(record: record)
            case .pptx:
                PresentationOpenerView(record: record)
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            let allPubs = try await dependencies.publicationRepository.fetchAll()
            
            // 1. Encontrar el último leído (filtrando por lastOpenedAt != nil)
            let openedPubs = allPubs
                .filter { $0.lastOpenedAt != nil }
                .sorted(by: { ($0.lastOpenedAt ?? Date.distantPast) > ($1.lastOpenedAt ?? Date.distantPast) })
            
            if let last = openedPubs.first {
                self.lastReadPublication = last
                if let progress = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: last.id) {
                    self.lastReadProgress = progress.percentage
                } else {
                    self.lastReadProgress = 0.0
                }
            } else {
                self.lastReadPublication = nil
                self.lastReadProgress = 0.0
            }
            
            // 2. Cargar los últimos 4 agregados/leídos para la sección Recientes
            let sortedRecents = allPubs
                .sorted(by: { ($0.lastOpenedAt ?? $0.importedAt) > ($1.lastOpenedAt ?? $1.importedAt) })
                .prefix(4)
            
            var list: [(PublicationRecord, Double)] = []
            for pub in sortedRecents {
                let prog = (try? await dependencies.readingProgressRepository.fetchProgress(forPublication: pub.id))?.percentage ?? 0.0
                list.append((pub, prog))
            }
            
            await MainActor.run {
                self.recentPublications = list
                self.isLoadingData = false
            }
        } catch {
            logger.error("Error cargando datos de inicio: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingData = false
            }
        }
    }

    // MARK: - Continue Reading

    private func continueReadingSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(String(localized: "Continuar leyendo",
                        comment: "Home section: continue reading"))
                .font(AppTypography.callout)
                .foregroundStyle(AppColor.textSecondary(for: theme))

            if let publication = lastReadPublication {
                Button {
                    selectedPublication = publication
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        // Portada física del libro (primera página)
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let coverPath = publication.coverPath,
                                   !coverPath.isEmpty,
                                   let uiImage = UIImage(contentsOfFile: CoverGenerator().coversDirectory.appendingPathComponent(coverPath).path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .clipped()
                                } else {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: AppRadius.xs)
                                            .fill(AppColor.surfaceSecondary(for: theme))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppRadius.xs)
                                                    .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                                            )
                                        
                                        Image(systemName: publication.publicationType.systemImage)
                                            .font(.title3)
                                            .foregroundStyle(AppColor.textSecondary(for: theme))
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.xs)
                                    .strokeBorder(AppColor.border(for: theme).opacity(0.4), lineWidth: 1)
                            )
                            
                            if publication.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(AppColor.accent(for: theme))
                                    .clipShape(Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .frame(width: 50, height: 70)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(publication.title)
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                .lineLimit(1)
                            
                            if let author = publication.author {
                                Text(author)
                                    .font(AppTypography.footnote)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: AppSpacing.xs) {
                                ProgressPill(progress: lastReadProgress, compact: true)
                                if lastReadProgress < 1.0 {
                                    Text("leído")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColor.textTertiary(for: theme))
                                }
                            }
                            .padding(.top, 2)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.accent(for: theme))
                            .padding(AppSpacing.xs)
                            .background(AppColor.accent(for: theme).opacity(0.1))
                            .clipShape(Circle())
                    }
                    .padding(AppSpacing.md)
                    .background(AppColor.surface(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .shadow(color: AppShadow.subtle(for: theme).color,
                            radius: AppShadow.subtle(for: theme).radius,
                            x: AppShadow.subtle(for: theme).x,
                            y: AppShadow.subtle(for: theme).y)
                    .contentShape(Rectangle())
                }
                .buttonStyle(InteractiveButtonStyle())
                .contextMenu {
                    // Fijar / Desfijar
                    Button {
                        Task {
                            await PublicationRecordUpdates.update(publication.id, repository: dependencies.publicationRepository) { $0.isPinned.toggle() }
                            await loadData()
                        }
                    } label: {
                        Label(publication.isPinned ? "Desfijar" : "Fijar al inicio",
                              systemImage: publication.isPinned ? "pin.slash" : "pin")
                    }

                    // Favorito / Quitar favorito
                    Button {
                        Task {
                            await PublicationRecordUpdates.update(publication.id, repository: dependencies.publicationRepository) { $0.isFavorite.toggle() }
                            await loadData()
                        }
                    } label: {
                        Label(publication.isFavorite ? "Quitar de favoritos" : "Hacer favorito",
                              systemImage: publication.isFavorite ? "heart.slash" : "heart")
                    }

                    Divider()

                    // Borrar
                    Button(role: .destructive) {
                        Task {
                            try? await dependencies.publicationRepository.delete(id: publication.id)
                            await dependencies.searchIndexingService.remove(publicationID: publication.id)
                            await loadData()
                        }
                    } label: {
                        Label("Borrar libro", systemImage: "trash")
                    }
                }
            } else {
                // Empty state — minimal
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "book.closed")
                        .font(.title3)
                        .foregroundStyle(AppColor.textTertiary(for: theme))

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(String(localized: "Sin lecturas en progreso",
                                    comment: "Home: no reading"))
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColor.textSecondary(for: theme))

                        Text(String(localized: "Abre un libro de tu biblioteca para comenzar",
                                    comment: "Home: open hint"))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.lg)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
    }

    // MARK: - Quick Actions

    private func quickActionsSection(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                router.showImport()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus")
                        .font(AppTypography.body)
                    Text(String(localized: "Importar", comment: "Home: import"))
                        .font(AppTypography.callout)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.accent(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .contentShape(Rectangle())
            }
            .buttonStyle(InteractiveButtonStyle())

            Button {
                router.showNewText()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.on.clipboard")
                        .font(AppTypography.body)
                    Text(String(localized: "Pegar texto", comment: "Home: paste text"))
                        .font(AppTypography.callout)
                }
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .strokeBorder(AppColor.border(for: theme), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(InteractiveButtonStyle())
        }
    }

    // MARK: - Recent

    private func recentSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(String(localized: "Recientes", comment: "Home section: recent"))
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                Spacer()
                Button {
                    withAnimation {
                        router.selectedTab = .library
                    }
                } label: {
                    Text(String(localized: "Ver todo", comment: "Home: see all"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.accent(for: theme))
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InteractiveButtonStyle())
            }

            if recentPublications.isEmpty {
                Text(String(localized: "Aún no hay documentos",
                            comment: "Home: empty recent"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: AppSpacing.md),
                    GridItem(.flexible(), spacing: AppSpacing.md)
                ]
                LazyVGrid(columns: columns, spacing: AppSpacing.lg) {
                    ForEach(recentPublications, id: \.0.id) { pair in
                        let pub = pair.0
                        let prog = pair.1
                        PublicationCard(publication: pub, style: .grid, progress: prog, onUpdate: {
                            Task {
                                await loadData()
                            }
                        }) {
                            selectedPublication = pub
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var contextualGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return String(localized: "Buenos días", comment: "Greeting: morning")
        case 12..<18:
            return String(localized: "Buenas tardes", comment: "Greeting: afternoon")
        default:
            return String(localized: "Buenas noches", comment: "Greeting: evening")
        }
    }
}

// MARK: - Preview

#Preview("Home") {
    let themeManager = ThemeManager()
    let router = AppRouter()
    NavigationStack {
        HomeView()
    }
    .environment(themeManager)
    .environment(router)
}
