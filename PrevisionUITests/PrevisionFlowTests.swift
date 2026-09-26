import XCTest

final class PrevisionFlowTests: XCTestCase {
    func testCreateDesignAndDragFurniture() throws {
        let app = XCUIApplication()
        app.launch()

        let newDesign = app.buttons["New Design"]
        XCTAssertTrue(newDesign.waitForExistence(timeout: 10))
        attach(name: "01-home")
        newDesign.tap()

        let sofa = app.buttons["Sectional Sofa"].firstMatch
        XCTAssertTrue(sofa.waitForExistence(timeout: 20))
        _ = app.staticTexts["Loading apartment…"].waitForNonExistence(timeout: 30)
        Thread.sleep(forTimeInterval: 2)
        attach(name: "02-showroom")

        let start = sofa.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let target = start.withOffset(CGVector(dx: -300, dy: 40))
        start.press(forDuration: 0.8, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 2)
        attach(name: "03-dragged")

        let lamp = app.buttons["Floor Lamp"].firstMatch
        lamp.tap()
        lamp.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -200, dy: 0)).tap()
        Thread.sleep(forTimeInterval: 2)
        attach(name: "04-tapped")

        app.buttons["Designs"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "05-home-saved")
    }

    private func attach(name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name)-screen\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
