import XCTest

/// Captures a screenshot of each main screen for the todo.firashome.uk gallery.
/// Launches the app with --seed-demo so every screen has realistic content.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seed-demo", "-UITestScreenshotMode"]
        app.launch()

        let attachment = XCTAttachment(dstName: "01-home.png")
        attachment.attach()

        // Tap through nav — these accessibility IDs are set on sidebar rows.
        capture(app, named: "02-today", tapIdentifier: "nav-today")
        capture(app, named: "03-upcoming", tapIdentifier: "nav-upcoming")
        capture(app, named: "04-filters", tapIdentifier: "nav-filters")
        capture(app, named: "05-projects", tapIdentifier: "nav-projects")

        // Open quick-add sheet
        if app.buttons["Add task"].waitForExistence(timeout: 3) {
            app.buttons["Add task"].tap()
            capture(app, named: "06-quickadd", tapIdentifier: nil)
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        }
    }

    private func capture(_ app: XCUIApplication, named name: String, tapIdentifier id: String?) {
        if let id, app.buttons[id].waitForExistence(timeout: 3) {
            app.buttons[id].tap()
            _ = app.windows.firstMatch.waitForExistence(timeout: 2)
        }
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
