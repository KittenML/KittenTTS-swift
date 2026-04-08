import XCTest
@testable import KittenTTS

final class TextCleanerTests: XCTestCase {

    // MARK: - Token structure

    func testEncodeReturnsAtLeastThreeTokens() {
        // [start, ...body..., end, pad]
        let tokens = TextCleaner.encode("a")
        XCTAssertGreaterThanOrEqual(tokens.count, 3)
    }

    func testEncodeStartAndEnd() {
        let tokens = TextCleaner.encode("hello")
        XCTAssertEqual(tokens.first, TextCleaner.startTokenID)
        XCTAssertEqual(tokens[tokens.count - 2], TextCleaner.endTokenID)
        XCTAssertEqual(tokens.last,  TextCleaner.padTokenID)
    }

    func testEmptyStringReturnsThreeTokens() {
        let tokens = TextCleaner.encode("")
        // start + end + pad = 3
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0], TextCleaner.startTokenID)
        XCTAssertEqual(tokens[1], TextCleaner.endTokenID)
        XCTAssertEqual(tokens[2], TextCleaner.padTokenID)
    }

    func testKnownIpaSymbols() {
        // Space (index 16 in the symbol table) should encode to 16
        let tokens = TextCleaner.encode(" ")
        XCTAssertEqual(tokens.count, 4)  // start, 16, end, pad
        XCTAssertEqual(tokens[1], 16)
    }

    func testUnknownScalarsSkipped() {
        // A rare Unicode character not in the symbol table
        let tokens = TextCleaner.encode("\u{1F600}") // 😀
        // Should just be start + end + pad with nothing in between
        XCTAssertEqual(tokens.count, 3)
    }

    func testTokenIDsAreNonNegative() {
        let tokens = TextCleaner.encode("Hello world!")
        for token in tokens {
            XCTAssertGreaterThanOrEqual(token, 0)
        }
    }

    // MARK: - Constants

    func testEndTokenIsEllipsis() {
        // Index 10 should be "…" — verify by checking the position manually
        // pad($)=0, then punctuation ";:,.!?¡¿—…" → "…" is the 10th character (index 10)
        XCTAssertEqual(TextCleaner.endTokenID, 10)
    }
}
