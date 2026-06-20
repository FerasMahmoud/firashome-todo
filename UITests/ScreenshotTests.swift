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

        // Capture the default (Today) screen first.
        capture(app, named: "01-today", tapIdentifier: nil)

        // Tap through nav — these accessibility IDs are set on sidebar rows.
        capture(app, named: "02-upcoming", tapIdentifier: "nav-upcoming")
        capture(app, named: "03-filters", tapIdentifier: "nav-filters")
        capture(app, named: "04-projects", tapIdentifier: "nav-projects")

        // Open quick-add sheet
        if app.buttons["Add task"].waitForExistence(timeout: 3) {
            app.buttons["Add task"].tap()
            capture(app, named: "05-quickadd", tapIdentifier: nil)
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        }
    }

    private func capture(_ app: XCUIApplication, named name: String, tapIdentifier id: String?) {
        if let id {
            // Sidebar List rows can surface as buttons, cells, or otherElements.
            for el in [app.buttons[id], app.cells[id], app.otherElements[id]] {
                if el.waitForExistence(timeout: 3) {
                    el.tap()
                    _ = app.windows.firstMatch.waitForExistence(timeout: 2)
                    break
                }
            }
        }
        let shot = app.screenshot()
        let a = XCTAttachment(screenshot: shot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
