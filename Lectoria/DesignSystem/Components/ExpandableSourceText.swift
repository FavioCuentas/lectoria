import SwiftUI

/// Muestra el texto seleccionado por el usuario (grounding) en las respuestas de IA/traducción.
/// Contraído enseña unas pocas líneas; al tocarlo se expande y muestra el texto completo
/// dentro de un área desplazable con altura máxima, para no ocultar la respuesta.
struct ExpandableSourceText: View {
    let text: String
    let theme: AppTheme
    var font: Font = AppTypography.caption
    var collapsedLines: Int = 2
    var expandedMaxHeight: CGFloat = 180

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if isExpanded {
                ScrollView {
                    Text("\"\(text)\"")
                        .font(font)
                        .foregroundStyle(AppColor.textTertiary(for: theme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: expandedMaxHeight)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\"\(text)\"")
                    .font(font)
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .lineLimit(collapsedLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard isExpandable else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true }
                    }
            }

            if isExpandable {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Label(
                    isExpanded ? "Ver menos" : "Ver texto completo",
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                )
                .font(AppTypography.footnote.weight(.semibold))
                .foregroundStyle(AppColor.accent(for: theme))
            }
            .buttonStyle(.plain)
            }
        }
    }

    /// Solo ofrece expandir si el texto probablemente no cabe en las líneas contraídas.
    private var isExpandable: Bool {
        text.count > collapsedLines * 45 || text.contains("\n")
    }
}
