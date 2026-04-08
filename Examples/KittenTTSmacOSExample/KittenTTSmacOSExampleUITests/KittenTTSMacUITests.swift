import XCTest

final class KittenTTSMacUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Launch

    func testAppLaunchesAndShowsUI() {
        // The window should exist
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10),
                      "App window should appear")
        // KittenTTS title should be visible
        XCTAssertTrue(app.staticTexts["KittenTTS"].exists,
                      "App title should be visible")
        // Generate button should exist
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch.exists,
            "Generate button should be visible"
        )
    }

    // MARK: - Generate

    func testGenerateButtonProducesResult() throws {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10),
                      "App window should appear")

        // Find the Generate button
        let generateButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Generate'")
        ).firstMatch

        XCTAssertTrue(generateButton.waitForExistence(timeout: 15),
                      "Generate button should appear")

        // Wait for it to become enabled (model loads from cache)
        let startTime = Date()
        while !generateButton.isEnabled {
            if Date().timeIntervalSince(startTime) > 20 {
                XCTFail("Generate button still disabled after 20s — model may not be cached")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        generateButton.click()

        // After generation the result GroupBox should appear.
        // Search multiple ways to be robust across macOS accessibility tree variations.
        let resultGroupbox  = app.groups["result_groupbox"].firstMatch
        let resultLabelText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Last result'")
        ).firstMatch

        // Give generation up to 30s
        let appeared = resultGroupbox.waitForExistence(timeout: 30) ||
                       resultLabelText.waitForExistence(timeout: 5)

        XCTAssertTrue(appeared, "Result GroupBox should appear within 30s of clicking Generate")
    }

    // MARK: - Speed slider

    func testSpeedSliderAdjusts() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.exists, "Speed slider should exist")
        // Verify the slider can be adjusted without error
        slider.adjust(toNormalizedSliderPosition: 0.75)
        // Slider still exists after adjustment
        XCTAssertTrue(slider.exists, "Slider should still exist after adjustment")
    }
}
