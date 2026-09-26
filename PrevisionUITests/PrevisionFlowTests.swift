import XCTest

final class PrevisionFlowTests: XCTestCase {
    func testPlaceFurniture() throws {
        let app = XCUIApplication()
        app.launch()

        let loadingText = app.staticTexts["Loading apartment…"]
        if loadingText.waitForExistence(timeout: 2) {
            _ = loadingText.waitForNonExistence(timeout: 15)
        } else {
            Thread.sleep(forTimeInterval: 15)
        }

        attach(name: "01-loaded")

        app.buttons["Sectional Sofa"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        Thread.sleep(forTimeInterval: 2)
        attach(name: "02-sofa")

        app.buttons["Floor Lamp"].tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.7)).tap()
        Thread.sleep(forTimeInterval: 2)
        attach(name: "03-lamp")
    }

    private func attach(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
