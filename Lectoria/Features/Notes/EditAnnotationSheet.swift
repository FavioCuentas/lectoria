import SwiftUI

// MARK: - EditAnnotationSheet

/// Vista modal para editar una anotación (destacado y/o nota) existente.
struct EditAnnotationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    // Anotación original
    let highlight: Highlight?
    let note: Note?
    
    // Callback al guardar los cambios
    let onSave: (Highlight?, Note?) -> Void
    // Callback al eliminar la anotación
    let onDelete: () -> Void
    
    // Estados editables locales
    @State private var selectedCategory: HighlightCategory = .mainIdea
    @State private var noteBody: String = ""
    @State private var tagsString: String = ""
    
    @State private var exportWrapper: ExportFileWrapper? = nil

    init(
        highlight: Highlight?,
        note: Note?,
        onSave: @escaping (Highlight?, Note?) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.highlight = highlight
        self.note = note
        self.onSave = onSave
        self.onDelete = onDelete
        
        // Inicializar estados
        if let highlight = highlight {
            let cat = HighlightCategory(rawValue: highlight.category ?? "") ?? .mainIdea
            _selectedCategory = State(initialValue: cat)
        }
        
        if let note = note {
            _noteBody = State(initialValue: note.body)
            _tagsString = State(initialValue: note.tags.joined(separator: ", "))
        }
    }
    
    var body: some View {
        let theme = themeManager.currentTheme
        
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    
                    // 1. Mostrar texto destacado (si existe)
                    if let highlight = highlight {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Texto Destacado")
                                .font(AppTypography.captionBold)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                            
                            Text("\"\(highlight.selectedText)\"")
                                .font(AppTypography.body.italic())
                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                .padding(AppSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(categoryColor(selectedCategory).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.sm)
                                        .stroke(categoryColor(selectedCategory).opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // 2. Selector de categoría (si es destacado)
                        if HighlightCategory.userSelectableCases.contains(selectedCategory) {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Categoría de Estudio")
                                    .font(AppTypography.captionBold)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                
                                Picker("Categoría", selection: $selectedCategory) {
                                    ForEach(HighlightCategory.userSelectableCases, id: \.self) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.horizontal, AppSpacing.md)
                        } else {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Tipo de Consulta IA")
                                    .font(AppTypography.captionBold)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                                
                                Text(selectedCategory.rawValue)
                                    .font(AppTypography.bodyBold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, 4)
                                    .background(categoryColor(selectedCategory))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    
                    // 3. Editor de notas
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(highlight != nil ? "Anotación / Nota Vinculada" : "Contenido de la Nota")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        
                        TextEditor(text: $noteBody)
                            .font(AppTypography.body)
                            .padding(AppSpacing.sm)
                            .frame(minHeight: 120)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(AppColor.border(for: theme), lineWidth: 1)
                            )
                            .overlay(
                                VStack {
                                    if noteBody.isEmpty {
                                        HStack {
                                            Text("Escribe tu nota o comentarios aquí...")
                                                .font(AppTypography.body)
                                                .foregroundStyle(AppColor.textTertiary(for: theme))
                                                .padding(.leading, AppSpacing.sm + 4)
                                                .padding(.top, AppSpacing.sm + 4)
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                }
                            )
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    // 4. Campo de etiquetas
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Etiquetas")
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                        
                        TextField("Ej: examen, anatomia, importante", text: $tagsString)
                            .font(AppTypography.body)
                            .padding(AppSpacing.md)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.sm)
                                    .stroke(AppColor.border(for: theme), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, AppSpacing.md)
                    
                    // Spacer y botón de eliminar destructivo
                    Spacer(minLength: AppSpacing.lg)
                    
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Eliminar Anotación")
                        }
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.error(for: theme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColor.error(for: theme).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.md)
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Editar Nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .font(AppTypography.body)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: AppSpacing.sm) {
                        Menu {
                            ForEach(NoteExportFormat.allCases) { format in
                                Button {
                                    exportSingle(format: format)
                                } label: {
                                    Label(format.displayName, systemImage: format.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }

                        Button("Guardar") {
                            saveChanges()
                            dismiss()
                        }
                        .font(AppTypography.bodyBold)
                        .disabled(note == nil && noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && highlight == nil)
                    }
                }
            }
            .sheet(item: $exportWrapper) { wrapper in
                ShareSheetView(activityItems: [wrapper.url])
            }
        }
    }

    private func exportSingle(format: NoteExportFormat) {
        let dummyPub = PublicationRecord(
            title: "Anotación de Lectoria",
            localFileName: "note.txt",
            publicationType: .txt,
            fileHash: "hash"
        )
        let hlList = highlight != nil ? [highlight!] : []
        let currentNote = note ?? Note(
            publicationID: highlight?.publicationID ?? UUID(),
            highlightID: highlight?.id,
            body: noteBody,
            tags: tagsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        )
        let exportData = [NoteExportData(publication: dummyPub, highlights: hlList, notes: [currentNote])]

        do {
            let url = try NoteExporter.export(data: exportData, format: format)
            self.exportWrapper = ExportFileWrapper(url: url)
        } catch {
            print("Error al exportar nota: \(error)")
        }
    }
    
    // MARK: - Save Lógica
    
    private func saveChanges() {
        var updatedHighlight = highlight
        var updatedNote = note
        
        // 1. Guardar cambios en el Destacado
        if var hl = updatedHighlight {
            hl.category = selectedCategory.rawValue
            hl.colorToken = colorToken(for: selectedCategory)
            hl.updatedAt = .now
            updatedHighlight = hl
        }
        
        // 2. Guardar cambios en la Nota
        let cleanBody = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedTags = tagsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        
        if var nt = updatedNote {
            // Nota existente: actualizar
            nt.body = cleanBody
            nt.tags = parsedTags
            nt.updatedAt = .now
            updatedNote = nt
        } else if !cleanBody.isEmpty {
            // Nota nueva (vinculada a destacado o independiente)
            let pubID = highlight?.publicationID ?? UUID()
            let hlID = highlight?.id
            let anchor = highlight?.anchor
            
            updatedNote = Note(
                publicationID: pubID,
                highlightID: hlID,
                anchor: anchor,
                body: cleanBody,
                tags: parsedTags
            )
        }
        
        onSave(updatedHighlight, updatedNote)
    }
    
    // MARK: - Helper Colors
    
    private func categoryColor(_ category: HighlightCategory) -> Color {
        switch category {
        case .mainIdea: return .blue
        case .question: return .purple
        case .evidence: return .green
        case .action: return .orange
        case .quote: return .pink
        case .dictionary: return Color(red: 0.18, green: 0.60, blue: 0.60)
        case .translation: return Color(red: 0.36, green: 0.36, blue: 0.75)
        case .ai: return Color(red: 0.12, green: 0.53, blue: 0.82)
        }
    }
    
    private func colorToken(for category: HighlightCategory) -> String {
        switch category {
        case .mainIdea: return "blue"
        case .question: return "purple"
        case .evidence: return "green"
        case .action: return "orange"
        case .quote: return "pink"
        case .dictionary: return "dictionary"
        case .translation: return "translation"
        case .ai: return "ai"
        }
    }
}
