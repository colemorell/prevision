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
        let create = app.buttons["Create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        let sofa = app.buttons["Sectional Sofa"].firstMatch
        XCTAssertTrue(sofa.waitForExistence(timeout: 20))
        _ = app.staticTexts["Loading room…"].waitForNonExistence(timeout: 30)
        Thread.sleep(forTimeInterval: 2)

        let room = app.descendants(matching: .any)["Room"].firstMatch
        XCTAssertTrue(room.exists)
        let start = sofa.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let drop = room.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.8, thenDragTo: drop, withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "02-editing")

        let set = app.buttons["Set"]
        XCTAssertTrue(set.waitForExistence(timeout: 5))
        app.buttons["Rotate Right"].tap()
        app.buttons["Rotate Right"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        room.pinch(withScale: 1.6, velocity: 2)
        Thread.sleep(forTimeInterval: 0.6)
        attach(name: "03-rotated-scaled")
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

        drop.press(forDuration: 0.8)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        Thread.sleep(forTimeInterval: 1)
        attach(name: "07-deleted")

        let lamp = app.buttons["Floor Lamp"].firstMatch
        lamp.tap()
        room.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
        XCTAssertTrue(set.waitForExistence(timeout: 5))
        attach(name: "08-tap-placed")
        set.tap()

        let edge = room.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.3))
        start.press(forDuration: 0.8, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "09-edge-clamped")
        XCTAssertTrue(set.waitForExistence(timeout: 5))
        set.tap()

        app.buttons["Light"].tap()
        let slider = app.descendants(matching: .any)["LightSlider"].firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        Thread.sleep(forTimeInterval: 1)
        attach(name: "10-dimmed")

        app.buttons["Designs"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "11-home")
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
