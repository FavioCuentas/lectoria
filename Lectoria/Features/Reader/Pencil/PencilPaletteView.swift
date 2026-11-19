import SwiftUI
import UIKit

// MARK: - PencilPaletteView

/// Paleta flotante del lápiz (solo iPad): herramienta, color y grosor.
struct PencilPaletteView: View {
    @Bindable var state: PencilPaletteState
    let theme: AppTheme
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(state.availableTools, id: \.self) { tool in
                    toolButton(tool)
                }
                Spacer(minLength: AppSpacing.sm)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
                .accessibilityLabel(String(localized: "Cerrar", comment: "Pencil palette: close"))
            }

            if state.tool != .eraser {
                HStack(spacing: AppSpacing.md) {
                    colorRow
                    if state.tool == .pen || state.tool == .marker {
                        Divider().frame(height: 24)
                        widthRow
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: 520)
        .background(AppColor.surface(for: theme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: Herramientas

    private func toolButton(_ tool: PencilTool) -> some View {
        let isSelected = state.tool == tool
        return Button {
            state.tool = tool
        } label: {
            Label(Self.title(for: tool), systemImage: Self.icon(for: tool))
                .font(AppTypography.callout.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs + 2)
                .foregroundStyle(isSelected ? AppColor.accent(for: theme) : AppColor.textPrimary(for: theme))
                .background(
                    isSelected ? AppColor.accent(for: theme).opacity(0.14) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    static func title(for tool: PencilTool) -> String {
        switch tool {
        case .text: String(localized: "Texto", comment: "Pencil tool: text highlighter")
        case .pen: String(localized: "Pluma", comment: "Pencil tool: pen")
        case .marker: String(localized: "Marcador", comment: "Pencil tool: marker")
        case .eraser: String(localized: "Borrador", comment: "Pencil tool: eraser")
        }
    }

    static func icon(for tool: PencilTool) -> String {
        switch tool {
        case .text: "character.cursor.ibeam"
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .eraser: "eraser"
        }
    }

    // MARK: Colores

    private var colorRow: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(HighlightCategory.userSelectableCases, id: \.self) { category in
                let selected = state.tool == .pen ? state.penColor == .category(category) : state.category == category
                swatch(Color(uiColor: PencilPaletteState.color(for: category)), selected: selected,
                       label: category.rawValue) {
                    if state.tool == .pen { state.penColor = .category(category) } else { state.category = category }
                }
            }
            if state.tool == .pen {
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
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(AppColor.textPrimary(for: theme), lineWidth: selected ? 2.5 : 0))
                .padding(3)
                .overlay(Circle().strokeBorder(AppColor.textTertiary(for: theme).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Grosor

    private var widthRow: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(PencilWidth.allCases, id: \.self) { width in
                let selected = state.width == width
                Button {
                    state.width = width
                } label: {
                    Capsule()
                        .fill(AppColor.textPrimary(for: theme))
                        .frame(width: 22, height: [2, 4, 7][width.rawValue])
                        .frame(width: 36, height: 30)
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
