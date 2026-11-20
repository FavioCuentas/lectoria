import SwiftUI
import UIKit

// MARK: - PencilPaletteView

/// Paleta flotante del lápiz (solo iPad), como la de Notas: solo íconos.
/// Tocar elige la herramienta; mantener presionado (o tocar otra vez la elegida) abre su color y grosor.
struct PencilPaletteView: View {
    @Bindable var state: PencilPaletteState
    let theme: AppTheme
    let onClose: () -> Void

    @State private var optionsTool: PencilTool?

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(state.availableTools, id: \.self) { tool in
                toolButton(tool)
            }
            Divider().frame(height: 28).padding(.horizontal, AppSpacing.xs)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 44)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }
            .accessibilityLabel(String(localized: "Cerrar", comment: "Pencil palette: close"))
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.surface(for: theme), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    // MARK: Herramientas

    private func toolButton(_ tool: PencilTool) -> some View {
        let isSelected = state.tool == tool
        return Image(systemName: Self.icon(for: tool))
            .font(.title2.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(iconColor(for: tool, selected: isSelected))
            .frame(width: 48, height: 44)
            .background(isSelected ? AppColor.accent(for: theme).opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture {
                // Como en Notas: tocar otra vez la herramienta elegida abre sus opciones.
                if isSelected { showOptions(for: tool) } else { state.tool = tool }
            }
            .onLongPressGesture(minimumDuration: 0.35) {
                state.tool = tool
                showOptions(for: tool)
            }
            .popover(isPresented: optionsBinding(for: tool), arrowEdge: .bottom) {
                options(for: tool)
                    .presentationCompactAdaptation(.popover)
            }
            .accessibilityElement()
            .accessibilityLabel(Self.title(for: tool))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { state.tool = tool }
            .accessibilityAction(named: String(localized: "Opciones", comment: "Pencil palette: tool options action")) {
                state.tool = tool
                showOptions(for: tool)
            }
    }

    private func showOptions(for tool: PencilTool) {
        // El borrador no tiene opciones.
        guard tool != .eraser else { return }
        optionsTool = tool
    }

    private func optionsBinding(for tool: PencilTool) -> Binding<Bool> {
        Binding(get: { optionsTool == tool }, set: { if !$0 { optionsTool = nil } })
    }

    /// El ícono de la pluma y del marcador lleva su color actual, como en Notas.
    private func iconColor(for tool: PencilTool, selected: Bool) -> Color {
        switch tool {
        case .pen:
            switch state.penColor {
            case .black: return AppColor.textPrimary(for: theme)
            case .category(let category): return Color(uiColor: PencilPaletteState.color(for: category))
            }
        case .marker:
            return Color(uiColor: PencilPaletteState.color(for: state.category))
        case .eraser:
            return selected ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme)
        }
    }

    static func title(for tool: PencilTool) -> String {
        switch tool {
        case .pen: String(localized: "Pluma", comment: "Pencil tool: pen")
        case .marker: String(localized: "Marcador", comment: "Pencil tool: marker")
        case .eraser: String(localized: "Borrador", comment: "Pencil tool: eraser")
        }
    }

    static func icon(for tool: PencilTool) -> String {
        switch tool {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .eraser: "eraser"
        }
    }

    // MARK: Opciones (color y grosor)

    private func options(for tool: PencilTool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(Self.title(for: tool))
                .font(AppTypography.bodyBold)
                .foregroundStyle(AppColor.textPrimary(for: theme))
            colorRow(for: tool)
            if state.showsWidth { widthRow }
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface(for: theme))
    }

    private func colorRow(for tool: PencilTool) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(HighlightCategory.userSelectableCases, id: \.self) { category in
                let selected = tool == .pen ? state.penColor == .category(category) : state.category == category
                swatch(Color(uiColor: PencilPaletteState.color(for: category)), selected: selected, label: category.rawValue) {
                    if tool == .pen { state.penColor = .category(category) } else { state.category = category }
                }
            }
            if tool == .pen {
                swatch(.black, selected: state.penColor == .black,
                       label: String(localized: "Negro", comment: "Pencil color: black")) {
                    state.penColor = .black
                }
            }
        }
    }

    private func swatch(_ color: Color, selected: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .padding(3)
                .overlay(Circle().strokeBorder(AppColor.textPrimary(for: theme), lineWidth: selected ? 2.5 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var widthRow: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(PencilWidth.allCases, id: \.self) { width in
                let selected = state.width == width
                Button {
                    state.width = width
                } label: {
                    Capsule()
                        .fill(AppColor.textPrimary(for: theme))
                        .frame(width: 26, height: [2, 4, 7][width.rawValue])
                        .frame(width: 48, height: 34)
                        .background(selected ? AppColor.accent(for: theme).opacity(0.14) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel([String(localized: "Fino", comment: "Pencil width: thin"),
                                     String(localized: "Medio", comment: "Pencil width: medium"),
                                     String(localized: "Grueso", comment: "Pencil width: thick")][width.rawValue])
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - PencilModeButton

/// Botón de la barra del lector que muestra u oculta la paleta del lápiz. Solo en iPad.
struct PencilModeButton: View {
    @Binding var isOn: Bool
    let theme: AppTheme

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() }
            } label: {
                Image(systemName: isOn ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                    .font(.title3)
                    .padding(AppSpacing.sm)
                    .foregroundStyle(isOn ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
            }
            .accessibilityLabel(String(localized: "Lápiz", comment: "Reader: pencil mode button"))
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}
