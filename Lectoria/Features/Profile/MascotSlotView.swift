import SwiftUI
import UIKit

// MARK: - MascotSlotView

/// Espacio reservado para la mascota de Lectoria en Estadísticas.
///
/// Muestra la imagen del recurso `statsMascot` de `Assets.xcassets` si existe.
/// Mientras no haya imagen, muestra un marco punteado indicando dónde irá:
/// basta con arrastrar la imagen (PNG con transparencia o JPG) a ese recurso en Xcode.
struct MascotSlotView: View {
    static let assetName = "statsMascot"

    let message: String
    let theme: AppTheme

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            if UIImage(named: Self.assetName) != nil {
                Image(Self.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .accessibilityHidden(true)
            } else {
                placeholder
            }

            Text(message)
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .accessibilityElement(children: .combine)
    }

    private var placeholder: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppColor.textTertiary(for: theme))
            Text(String(localized: "Espacio para la mascota de Lectoria", comment: "Stats: mascot placeholder"))
                .font(AppTypography.footnote)
                .foregroundStyle(AppColor.textTertiary(for: theme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(
                    AppColor.border(for: theme),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                )
        )
    }
}
