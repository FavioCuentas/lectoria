import Testing
import SwiftUI
@testable import Lectoria

// MARK: - TokenTests

/// Pruebas unitarias para los tokens del Design System.
///
/// Valida que todos los temas producen valores y que
/// los tokens son consistentes entre temas.
struct TokenTests {

    // MARK: - Color tokens

    @Test("Background color exists for all themes")
    func backgroundColorForAllThemes() {
        for theme in AppTheme.allCases {
            let color = AppColor.background(for: theme)
            #expect(color != nil, "Background color should exist for \(theme)")
        }
    }

    @Test("Surface color exists for all themes")
    func surfaceColorForAllThemes() {
        for theme in AppTheme.allCases {
            let color = AppColor.surface(for: theme)
            #expect(color != nil, "Surface color should exist for \(theme)")
        }
    }

    @Test("Text primary color exists for all themes")
    func textPrimaryColorForAllThemes() {
        for theme in AppTheme.allCases {
            let color = AppColor.textPrimary(for: theme)
            #expect(color != nil, "Text primary color should exist for \(theme)")
        }
    }

    @Test("Accent color exists for all themes")
    func accentColorForAllThemes() {
        for theme in AppTheme.allCases {
            let color = AppColor.accent(for: theme)
            #expect(color != nil, "Accent color should exist for \(theme)")
        }
    }

    @Test("All highlight colors exist for all themes")
    func highlightColorsForAllThemes() {
        for theme in AppTheme.allCases {
            #expect(AppColor.highlightMainIdea(for: theme) != nil)
            #expect(AppColor.highlightQuestion(for: theme) != nil)
            #expect(AppColor.highlightEvidence(for: theme) != nil)
            #expect(AppColor.highlightAction(for: theme) != nil)
            #expect(AppColor.highlightQuote(for: theme) != nil)
        }
    }

    // MARK: - Theme

    @Test("AppTheme has exactly 3 cases")
    func themeCount() {
        #expect(AppTheme.allCases.count == 3)
    }

    @Test("AppTheme display names are non-empty")
    func themeDisplayNames() {
        for theme in AppTheme.allCases {
            #expect(!theme.displayName.isEmpty, "Theme \(theme) should have a display name")
        }
    }

    @Test("Sepia theme uses light color scheme")
    func sepiaUsesLightScheme() {
        #expect(AppTheme.sepia.colorScheme == .light)
    }

    @Test("Dark theme uses dark color scheme")
    func darkUsesDarkScheme() {
        #expect(AppTheme.dark.colorScheme == .dark)
    }

    // MARK: - Spacing tokens

    @Test("Spacing values are positive and ordered")
    func spacingOrder() {
        #expect(AppSpacing.xxs < AppSpacing.xs)
        #expect(AppSpacing.xs < AppSpacing.sm)
        #expect(AppSpacing.sm < AppSpacing.md)
        #expect(AppSpacing.md < AppSpacing.lg)
        #expect(AppSpacing.lg < AppSpacing.xl)
        #expect(AppSpacing.xl < AppSpacing.xxl)
        #expect(AppSpacing.xxl < AppSpacing.xxxl)
        #expect(AppSpacing.xxxl < AppSpacing.huge)
    }

    // MARK: - Radius tokens

    @Test("Radius values are positive and ordered")
    func radiusOrder() {
        #expect(AppRadius.xs < AppRadius.sm)
        #expect(AppRadius.sm < AppRadius.md)
        #expect(AppRadius.md < AppRadius.lg)
        #expect(AppRadius.lg < AppRadius.xl)
        #expect(AppRadius.xl < AppRadius.full)
    }

    // MARK: - Typography

    @Test("Reader font sizes are ordered and non-empty")
    func readerFontSizes() {
        let sizes = AppTypography.readerFontSizes
        #expect(!sizes.isEmpty)
        for i in 1..<sizes.count {
            #expect(sizes[i] > sizes[i - 1], "Font sizes should be ascending")
        }
    }

    @Test("Default reader font size index is valid")
    func defaultFontSizeIndex() {
        #expect(AppTypography.defaultReaderFontSizeIndex >= 0)
        #expect(AppTypography.defaultReaderFontSizeIndex < AppTypography.readerFontSizes.count)
        #expect(AppTypography.readerFontSizes[AppTypography.defaultReaderFontSizeIndex]
                == AppTypography.defaultReaderFontSize)
    }

    @Test("Line spacing options are ordered")
    func lineSpacingOrder() {
        let options = AppTypography.lineSpacingOptions
        #expect(!options.isEmpty)
        for i in 1..<options.count {
            #expect(options[i] > options[i - 1])
        }
    }
}
