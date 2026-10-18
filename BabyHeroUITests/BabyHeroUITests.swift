import XCTest

final class BabyHeroUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    private func launch(_ state: String? = nil, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if let state { app.launchArguments += ["--preview-state", state] }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }

    @MainActor
    func testWelcomeAndPrivacyInformation() {
        let app = launch()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["primaryAction"].label, "Start listening")
        XCTAssertFalse(app.staticTexts["previewLabel"].exists)
        app.buttons["informationButton"].tap()
        XCTAssertTrue(app.staticTexts["Just on your iPhone"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["primaryAction"].exists)
        attachScreenshot("Welcome")
    }

    @MainActor
    func testSelectToneBackAndStop() {
        let app = launch("listening")
        XCTAssertTrue(app.staticTexts["previewLabel"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["tone-1"].tap()
        XCTAssertTrue(app.otherElements["signalGauge"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["backToSounds"].isHittable)
        attachScreenshot("Finder")
        app.buttons["backToSounds"].tap()
        XCTAssertTrue(app.buttons["tone-1"].exists)
        app.swipeUp()
        app.buttons["tone-2"].tap()
        XCTAssertTrue(app.staticTexts["11.82"].waitForExistence(timeout: 3))
        app.buttons["backToSounds"].tap()
        app.buttons["primaryAction"].tap()
        XCTAssertEqual(app.buttons["primaryAction"].label, "Start listening")
        XCTAssertFalse(app.buttons["tone-1"].exists)
    }

    @MainActor
    func testSignalLostAndQuietStates() {
        let app = launch("lost")
        XCTAssertTrue(app.otherElements["signalGauge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["signalGauge"].label.contains("Signal lost"))
        app.terminate()
        let quiet = launch("quiet")
        XCTAssertTrue(quiet.staticTexts["No clear tone detected"].waitForExistence(timeout: 5))
        XCTAssertFalse(quiet.buttons["tone-1"].exists)
    }

    @MainActor
    func testBackgroundRequiresExplicitRestart() {
        let app = launch("listening")
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["primaryAction"].label, "Start again")
        XCTAssertFalse(app.buttons["tone-1"].exists)
    }

    @MainActor
    func testDeniedPermissionExplainsRecovery() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .microphone)
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists, "Opening the app must not ask for microphone access")
        app.buttons["primaryAction"].tap()
        let deny = springboard.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 8))
        deny.tap()
        XCTAssertTrue(app.alerts["Microphone access is off"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.buttons["Open Settings"].exists)
        app.alerts.buttons["Not now"].tap()
        XCTAssertEqual(app.buttons["primaryAction"].label, "Start listening")
    }

    @MainActor
    func testGrantedPermissionResolvesIntoCaptureOrActionableError() {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .microphone)
        app.launch()
        app.buttons["primaryAction"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 8))
        allow.tap()
        // Simulator microphone availability depends on the host. Either result
        // must resolve permission instead of leaving a disabled spinner forever.
        if app.buttons["Stop listening"].waitForExistence(timeout: 8) {
            app.buttons["primaryAction"].tap()
            XCTAssertEqual(app.buttons["primaryAction"].label, "Start listening")
        } else {
            XCTAssertTrue(app.alerts["Couldn’t start listening"].exists)
            XCTAssertTrue(app.alerts.buttons["OK"].exists)
        }
    }

    @MainActor
    func testLargeTextKeepsControlsReachable() {
        let app = launch("finder", largeText: true)
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["primaryAction"].isHittable)
        XCTAssertEqual(app.buttons["primaryAction"].label, "Stop")
        XCTAssertLessThan(app.buttons["primaryAction"].frame.height, 150)
        app.swipeUp()
        attachScreenshot("Finder-LargeText")
        app.buttons["primaryAction"].tap()
        XCTAssertEqual(app.buttons["primaryAction"].label, "Listen")
    }

    @MainActor
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
