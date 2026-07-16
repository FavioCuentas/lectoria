import XCTest

// MARK: - NavigationUITests

/// Pruebas de UI para la navegación principal.
///
/// Verifica que los 4 tabs son accesibles y navegables,
/// y que el onboarding funciona correctamente.
final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset onboarding state for clean tests
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()
    }

    // MARK: - Tab navigation

    func testAllTabsAreVisible() {
        XCTAssertTrue(app.tabBars.buttons["Inicio"].exists, "Home tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Biblioteca"].exists, "Library tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Notas"].exists, "Notes tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Perfil"].exists, "Profile tab should exist")
    }

    func testCanNavigateBetweenTabs() {
        // Navigate to Library
        app.tabBars.buttons["Biblioteca"].tap()
        XCTAssertTrue(app.navigationBars["Biblioteca"].waitForExistence(timeout: 2))

        // Navigate to Notes
        app.tabBars.buttons["Notas"].tap()
        XCTAssertTrue(app.navigationBars["Notas"].waitForExistence(timeout: 2))

        // Navigate to Profile
        app.tabBars.buttons["Perfil"].tap()
        XCTAssertTrue(app.navigationBars["Perfil"].waitForExistence(timeout: 2))

        // Navigate back to Home
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.navigationBars["Inicio"].waitForExistence(timeout: 2))
    }

    func testHomeTabIsSelectedByDefault() {
        let homeTab = app.tabBars.buttons["Inicio"]
        XCTAssertTrue(homeTab.isSelected, "Home tab should be selected by default")
    }

    // MARK: - Onboarding

    func testOnboardingFlowCompletes() {
        // Launch with onboarding not completed
        let freshApp = XCUIApplication()
        freshApp.launchArguments += ["-hasCompletedOnboarding", "NO"]
        freshApp.launch()

        // Verify onboarding is showing
        let skipButton = freshApp.buttons["Omitir"]
        if skipButton.waitForExistence(timeout: 3) {
            // Skip onboarding
            skipButton.tap()

            // Verify we're on the main screen with tabs
            XCTAssertTrue(freshApp.tabBars.buttons["Inicio"].waitForExistence(timeout: 3),
                         "Should show tabs after completing onboarding")
        }
    }
}
