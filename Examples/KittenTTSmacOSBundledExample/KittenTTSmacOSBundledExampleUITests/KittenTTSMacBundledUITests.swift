import XCTest

final class KittenTTSMacBundledUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunchesAndShowsUI() {
        XCTAssertTrue(app.staticTexts["KittenTTS Bundled Assets"].waitForExistence(timeout: 30),
                      "App title should be visible")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Generate'")).firstMatch.waitForExistence(timeout: 10),
            "Generate button should be visible"
        )
    }

    func testGenerateButtonProducesResult() throws {
        let generateButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Generate'")
        ).firstMatch

        XCTAssertTrue(generateButton.waitForExistence(timeout: 15),
                      "Generate button should appear")

        let startTime = Date()
        while !generateButton.isEnabled {
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No bundled assets found'")).firstMatch.exists {
                throw XCTSkip("Bundled assets are not checked in. Generate assets before running this UI test.")
            }
            if Date().timeIntervalSince(startTime) > 20 {
                XCTFail("Generate button still disabled after 20s; bundled assets may be missing")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        let outputURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bundled-output.wav")
        try? FileManager.default.removeItem(at: outputURL)

        generateButton.click()

        let resultGroupbox  = app.groups["result_groupbox"].firstMatch
        let resultLabelText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Last Output'")
        ).firstMatch

        let appeared = resultGroupbox.waitForExistence(timeout: 30) ||
                       resultLabelText.waitForExistence(timeout: 5)

        XCTAssertTrue(appeared, "Result GroupBox should appear within 30s of clicking Generate")
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path),
                      "Generated WAV should be written to Downloads")
    }

    func testSpeedSliderAdjusts() {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 30), "Speed slider should exist")
        slider.adjust(toNormalizedSliderPosition: 0.75)
        XCTAssertTrue(slider.exists, "Slider should still exist after adjustment")
    }
}
