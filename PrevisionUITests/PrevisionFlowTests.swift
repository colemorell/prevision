import XCTest

final class PrevisionFlowTests: XCTestCase {
    func testPlaceEditAndDeleteFurniture() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests"]
        app.launch()

        let newDesign = app.buttons["New Design"]
        XCTAssertTrue(newDesign.waitForExistence(timeout: 10))
        attach(name: "01-home")
        newDesign.tap()

        let sofa = app.buttons["Sectional Sofa"].firstMatch
        XCTAssertTrue(sofa.waitForExistence(timeout: 20))
        _ = app.staticTexts["Loading apartment…"].waitForNonExistence(timeout: 30)
        Thread.sleep(forTimeInterval: 2)

        let start = sofa.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let drop = start.withOffset(CGVector(dx: -260, dy: -60))
        start.press(forDuration: 0.8, thenDragTo: drop, withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "02-editing")

        let set = app.buttons["Set"]
        XCTAssertTrue(set.waitForExistence(timeout: 5))
        app.buttons["Rotate Right"].tap()
        app.buttons["Rotate Right"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        attach(name: "03-rotated")
        set.tap()
        Thread.sleep(forTimeInterval: 1)
        attach(name: "04-set")

        drop.press(forDuration: 0.8)
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        attach(name: "05-menu")
        edit.tap()
        XCTAssertTrue(set.waitForExistence(timeout: 5))
        drop.press(forDuration: 0.2, thenDragTo: drop.withOffset(CGVector(dx: 80, dy: 20)))
        Thread.sleep(forTimeInterval: 0.6)
        attach(name: "06-moved")
        set.tap()

        drop.withOffset(CGVector(dx: 80, dy: 20)).press(forDuration: 0.8)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        Thread.sleep(forTimeInterval: 1)
        attach(name: "07-deleted")

        app.buttons["Designs"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "08-home")
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
