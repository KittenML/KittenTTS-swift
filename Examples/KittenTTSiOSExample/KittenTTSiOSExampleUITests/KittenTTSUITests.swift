import XCTest

final class KittenTTSUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Launch

    func testAppLaunchesAndShowsUI() {
        XCTAssertTrue(app.navigationBars["KittenTTS"].exists, "Navigation bar should show 'KittenTTS'")
        XCTAssertTrue(app.buttons["Generate"].exists, "Generate button should be visible")
        XCTAssertTrue(app.sliders.firstMatch.exists, "Speed slider should be visible")
    }

    // MARK: - Generate

    func testGenerateButtonProducesResult() throws {
        // The model is pre-cached so setup() should complete quickly.
        // Wait up to 15s for the Generate button to become enabled.
        let generateButton = app.buttons["Generate"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 15),
                      "Generate button should appear")

        // Retry tapping until enabled (short setup time)
        let startTime = Date()
        while !generateButton.isEnabled {
            if Date().timeIntervalSince(startTime) > 15 {
                XCTFail("Generate button still disabled after 15s")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        generateButton.tap()

        // After generation, a "result_label" element should appear
        let resultLabel = app.otherElements["result_label"].firstMatch
        let resultText  = app.staticTexts["Generated Audio"]
        let appeared    = resultLabel.waitForExistence(timeout: 30) ||
                          resultText.waitForExistence(timeout: 5)

        XCTAssertTrue(appeared, "Result card should appear within 30s of tapping Generate")
    }

    // MARK: - Voice picker

    func testVoicePickerExists() {
        XCTAssertTrue(app.buttons["Bella, Collapsed"].exists ||
                      app.pickers.firstMatch.exists ||
                      app.buttons.matching(NSPredicate(format: "label CONTAINS 'Bella'")).firstMatch.exists,
                      "Voice picker should show the selected voice name")
    }

    // MARK: - Speed slider

    func testSpeedSliderAdjusts() {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.exists)
        // Drag right to increase speed
        slider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '×'")).firstMatch.exists,
                      "Speed label should show multiplier")
    }
}
