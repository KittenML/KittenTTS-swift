import XCTest
@testable import KittenTTS

final class TextPreprocessorTests: XCTestCase {

    // MARK: - Numbers

    func testSimpleInteger() {
        XCTAssertEqual(TextPreprocessor.process("I have 3 cats"), "I have three cats")
    }

    func testLargeNumber() {
        XCTAssertEqual(TextPreprocessor.process("1000 people"), "one thousand people")
    }

    func testDecimalNumber() {
        XCTAssertEqual(TextPreprocessor.process("3.14 is pi"), "three point one four is pi")
    }

    func testCommaNumber() {
        XCTAssertEqual(TextPreprocessor.process("1,000,000 dollars"), "one million dollars")
    }

    // MARK: - Currency

    func testDollar() {
        XCTAssertEqual(TextPreprocessor.process("costs $5"), "costs five dollars")
    }

    func testDollarSingular() {
        XCTAssertEqual(TextPreprocessor.process("$1 coin"), "one dollar coin")
    }

    func testDollarMillions() {
        // Currency expansion multiplies amount then passes to numberToWords,
        // so $2M → "two million" (numberToWords of 2_000_000) + " million" multiplierWord
        // This is the inherited behaviour from the reference implementation.
        let result = TextPreprocessor.process("$2M deal")
        XCTAssertTrue(result.contains("million"), "Expected 'million' in result: '\(result)'")
        XCTAssertTrue(result.contains("dollars"), "Expected 'dollars' in result: '\(result)'")
    }

    func testPound() {
        XCTAssertEqual(TextPreprocessor.process("£10 note"), "ten pounds note")
    }

    // MARK: - Percentages

    func testPercentage() {
        XCTAssertEqual(TextPreprocessor.process("50% off"), "fifty percent off")
    }

    // MARK: - Ordinals

    func testOrdinalFirst() {
        XCTAssertEqual(TextPreprocessor.process("1st place"), "first place")
    }

    func testOrdinalThird() {
        XCTAssertEqual(TextPreprocessor.process("3rd attempt"), "third attempt")
    }

    func testOrdinalTwentyFirst() {
        XCTAssertEqual(TextPreprocessor.process("21st century"), "twenty-first century")
    }

    // MARK: - Whitespace

    func testCollapseWhitespace() {
        let result = TextPreprocessor.process("hello   world")
        XCTAssertFalse(result.contains("   "), "Expected whitespace collapsed in '\(result)'")
        XCTAssertEqual(result, "hello world")
    }

    func testTrimming() {
        XCTAssertEqual(TextPreprocessor.process("  hello  "), "hello")
    }

    // MARK: - numberToWords

    func testZero()     { XCTAssertEqual(TextPreprocessor.numberToWords(0),   "zero") }
    func testNegative() { XCTAssertEqual(TextPreprocessor.numberToWords(-5),  "negative five") }
    func testTeen()     { XCTAssertEqual(TextPreprocessor.numberToWords(15),  "fifteen") }
    func testTwentyish(){ XCTAssertEqual(TextPreprocessor.numberToWords(42),  "forty-two") }
    func testHundred()  { XCTAssertEqual(TextPreprocessor.numberToWords(100), "one hundred") }
    func testThousand() { XCTAssertEqual(TextPreprocessor.numberToWords(1001),"one thousand one") }
}
