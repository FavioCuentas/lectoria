import SwiftUI

// MARK: - StudyCategory

/// Las 5 categorías académicas normalizadas del sistema de estudio de Lectoria.
public enum StudyCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case importante = "Importante"
    case definicion = "Definición"
    case ejemplo = "Ejemplo"
    case duda = "Duda"
    case estudio = "Estudio"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .importante: Color(red: 0.95, green: 0.77, blue: 0.06) // Amarillo
        case .definicion: Color(red: 0.20, green: 0.60, blue: 0.86) // Azul
        case .ejemplo: Color(red: 0.18, green: 0.80, blue: 0.44)    // Verde
        case .duda: Color(red: 0.91, green: 0.30, blue: 0.24)       // Rojo
        case .estudio: Color(red: 0.90, green: 0.49, blue: 0.13)    // Terracota
        }
    }

    public var iconName: String {
        switch self {
        case .importante: "star.fill"
        case .definicion: "book.closed.fill"
        case .ejemplo: "checkmark.circle.fill"
        case .duda: "questionmark.circle.fill"
        case .estudio: "bookmark.fill"
        }
    }
}

// MARK: - PresentationNotesPanelView

/// Panel inferior desplegable para gestionar notas personales y clasificaciones por categoría en la diapositiva actual.
struct PresentationNotesPanelView: View {
    let slideIndex: Int
    let totalSlides: Int
    let existingNotes: [Note]
    let onSaveNote: (String, StudyCategory) -> Void

    @Environment(ThemeManager.self) private var themeManager

    @State private var newNoteText = ""
    @State private var selectedCategory: StudyCategory = .importante
    @State private var isExpanded = false

    var body: some View {
        let theme = themeManager.currentTheme
        let slideNotes = existingNotes.filter { $0.anchor == "slide_\(slideIndex + 1)" }

        VStack(spacing: AppSpacing.xs) {
            // Header del Panel
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "note.text")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColor.accent(for: theme))

                        Text(String(localized: "Notas del slide \(slideIndex + 1)", comment: "Slide notes header"))
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))

                        if !slideNotes.isEmpty {
                            Text("\(slideNotes.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(AppColor.accent(for: theme))
                                .clipShape(Capsule())
                        }

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColor.textTertiary(for: theme))
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            // Contenido expandible del panel de notas
            if isExpanded {
                VStack(spacing: AppSpacing.sm) {
                    // Selector de 5 Categorías de Estudio
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(StudyCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 10))
                                    Text(category.rawValue)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedCategory == category ? category.color.opacity(0.2) : AppColor.surfaceSecondary(for: theme))
                                .foregroundStyle(selectedCategory == category ? category.color : AppColor.textSecondary(for: theme))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == category ? category.color : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)

                    // Campo de entrada de texto
                    HStack(spacing: AppSpacing.xs) {
                        TextField(String(localized: "Escribe una nota para este slide...", comment: "Note input placeholder"), text: $newNoteText)
                            .font(AppTypography.caption)
                            .padding(AppSpacing.xs)
                            .background(AppColor.surfaceSecondary(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))

                        Button {
                            guard !newNoteText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            onSaveNote(newNoteText, selectedCategory)
                            newNoteText = ""
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(newNoteText.isEmpty ? AppColor.textTertiary(for: theme) : AppColor.accent(for: theme))
                                .clipShape(Circle())
                        }
                        .disabled(newNoteText.isEmpty)
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Lista de notas redactadas en este slide
                    if !slideNotes.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                ForEach(slideNotes) { note in
                                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                                        Circle()
                                            .fill(selectedCategory.color)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 4)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.body)
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColor.textPrimary(for: theme))
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .padding(AppSpacing.xs)
                                    .background(AppColor.surfaceSecondary(for: theme))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        .frame(maxHeight: 100)
                    }
                }
                .padding(.bottom, AppSpacing.xs)
            }
        }
        .background(AppColor.surface(for: theme))
    }
}
