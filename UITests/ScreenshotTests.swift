import XCTest

/// Captures a screenshot of EACH main screen for the todo.firashome.uk gallery.
/// Deterministic: relaunches the app per screen with `--screen=<id>` (RootView
/// renders that screen full-screen), so every page is captured regardless of
/// sidebar tap discoverability. Attachments are added in this fixed order,
/// matching the gallery labels.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureAllScreens() {
        let app = XCUIApplication()
        let screens = [
            ("today", "01-today"),
            ("inbox", "02-inbox"),
            ("upcoming", "03-upcoming"),
            ("filters", "04-filters"),
            ("projects", "05-projects"),
            ("quickadd", "06-quickadd"),
        ]

        for (screen, name) in screens {
            app.launchArguments = ["--seed-demo", "--screen=\(screen)", "-UITestScreenshotMode"]
            app.launch()
            // Give the view + SwiftData seed a moment to render.
            _ = app.windows.firstMatch.waitForExistence(timeout: 8)
            Thread.sleep(forTimeInterval: 0.8)

            let shot = app.screenshot()
            let a = XCTAttachment(screenshot: shot)
            a.name = name
            a.lifetime = .keepAlways
            add(a)

            app.terminate()
        }
    }
}
