import SwiftUI

// MARK: - ActiveDocumentSelectorView

/// Vista modal para que los usuarios del plan Free elijan exactamente qué 5 documentos mantener activos.
///
/// Los documentos no seleccionados se marcan como archivados/restringidos (`isArchived = true`),
/// pero sus notas, destacamentos, marcadores y progresos permanecen 100% intactos y conservados.
struct ActiveDocumentSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    let publications: [PublicationRecord]
    let onSave: () -> Void

    @State private var selectedIDs: Set<UUID> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(publications: [PublicationRecord], onSave: @escaping () -> Void) {
        self.publications = publications
        self.onSave = onSave

        // Inicializar seleccionando los primeros 5 documentos no archivados o más recientes
        let initiallyActive = publications.filter { !$0.isArchived }.prefix(5).map { $0.id }
        _selectedIDs = State(initialValue: Set(initiallyActive))
    }

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            VStack(spacing: 0) {
                // Banner explicativo respetuoso
                infoBanner(theme: theme)

                // Lista interactiva de selección
                List {
                    Section {
                        ForEach(publications) { pub in
                            let isSelected = selectedIDs.contains(pub.id)

                            Button {
                                toggleSelection(for: pub.id)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isSelected ? AppColor.accent(for: theme) : AppColor.textTertiary(for: theme))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pub.title)
                                            .font(AppTypography.bodyBold)
                                            .foregroundStyle(AppColor.textPrimary(for: theme))
                                            .lineLimit(1)

                                        if let author = pub.author {
                                            Text(author)
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColor.textSecondary(for: theme))
                                                .lineLimit(1)
                                        }

                                        HStack(spacing: AppSpacing.xs) {
                                            Label(pub.publicationType.displayName, systemImage: pub.publicationType.systemImage)
                                                .font(.system(size: 10))
                                                .foregroundStyle(AppColor.textTertiary(for: theme))

                                            if pub.isArchived && !isSelected {
                                                Text("• Archivado", comment: "Status archived tag")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Documentos en tu biblioteca (\(selectedIDs.count)/5 seleccionados)")
                            .font(AppTypography.caption.weight(.bold))
                    }
                }
                .listStyle(.insetGrouped)

                // Botón de confirmación
                VStack(spacing: AppSpacing.sm) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.red)
                    }

                    Button {
                        saveSelection()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(selectedIDs.count <= 5 ? "Guardar selección (\(selectedIDs.count)/5)" : "Selecciona máximo 5 documentos")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(selectedIDs.count > 5 || selectedIDs.isEmpty || isSaving)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(selectedIDs.count <= 5 && !selectedIDs.isEmpty ? AppColor.accent(for: theme) : AppColor.textTertiary(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.bottom, AppSpacing.md)
                }
                .background(AppColor.surface(for: theme))
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Seleccionar 5 Activos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .font(AppTypography.body)
                }
            }
        }
    }

    private func infoBanner(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColor.accent(for: theme))

            VStack(alignment: .leading, spacing: 2) {
                Text("Límite de 5 documentos en Lectoría Free", comment: "Selector title")
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                Text("Elige qué 5 documentos deseas tener activos para lectura. Los demás se guardarán archivados en tu biblioteca conservando todas sus notas e historial.", comment: "Selector subtitle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.accent(for: theme).opacity(0.1))
    }

    private func toggleSelection(for id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            if selectedIDs.count < 5 {
                selectedIDs.insert(id)
            } else {
                errorMessage = String(localized: "Solo puedes tener un máximo de 5 documentos activos en el plan Free.", comment: "Max selection error")
            }
        }
    }

    private func saveSelection() {
        guard selectedIDs.count <= 5 else { return }
        isSaving = true

        Task {
            for var pub in publications {
                let shouldBeActive = selectedIDs.contains(pub.id)
                if pub.isArchived == shouldBeActive {
                    pub.isArchived = !shouldBeActive
                    try? await dependencies.publicationRepository.save(pub)
                }
            }

            await MainActor.run {
                isSaving = false
                onSave()
                dismiss()
            }
        }
    }
}
