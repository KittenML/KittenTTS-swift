import XCTest
@testable import KittenTTS

final class PhonemizerTests: XCTestCase {

    // MARK: - Lexicon lookups

    func testHello() {
        XCTAssertEqual(Phonemizer.phonemize("hello"), "həˈloʊ")
    }

    func testThe() {
        XCTAssertEqual(Phonemizer.phonemize("the"), "ðə")
    }

    func testKitten() {
        XCTAssertEqual(Phonemizer.phonemize("kitten"), "kɪtən")
    }

    // MARK: - Multi-word sentences

    func testMultiWordSentence() {
        let result = Phonemizer.phonemize("hello world")
        // Should contain a space between the two phoneme sequences
        XCTAssertTrue(result.contains(" "), "Expected space between words in '\(result)'")
    }

    func testPunctuationPassthrough() {
        let result = Phonemizer.phonemize("hello, world")
        XCTAssertTrue(result.contains(","), "Expected comma passthrough in '\(result)'")
    }

    // MARK: - Suffix derivation

    func testPossessive() {
        // "kitten's" should be "kɪtən" + "z"
        let result = Phonemizer.phonemize("kitten's")
        XCTAssertTrue(result.hasSuffix("z"), "Expected possessive suffix 'z' in '\(result)'")
    }

    func testLexiconIngSuffix() {
        // "making" is in the lexicon directly
        let result = Phonemizer.phonemize("making")
        XCTAssertEqual(result, "meɪkɪŋ")
    }

    // MARK: - Rule-based fallback

    func testRuleG2PProducesOutput() {
        // "zzz" is not in the lexicon; should still produce non-empty output
        let result = Phonemizer.phonemize("zzz")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Lexicon consistency

    func testLexiconContainsExpectedEntries() {
        XCTAssertNotNil(Phonemizer.lexicon["hello"])
        XCTAssertNotNil(Phonemizer.lexicon["the"])
        XCTAssertNotNil(Phonemizer.lexicon["kitten"])
    }

    func testLexiconValuesAreNonEmpty() {
        for (word, ipa) in Phonemizer.lexicon {
            XCTAssertFalse(ipa.isEmpty, "Lexicon entry for '\(word)' has empty IPA")
        }
    }
}
