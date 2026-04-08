import XCTest
@testable import KittenTTS

/// End-to-end integration tests that require the model to be cached on disk.
///
/// These tests are automatically skipped when the model is not present,
/// so they are safe to run in CI environments that don't have the model.
final class IntegrationTests: XCTestCase {

    private var tts: KittenTTS!

    override func setUp() async throws {
        try await super.setUp()
        guard KittenTTS.isModelCached() else {
            throw XCTSkip("Model not cached — skipping integration tests")
        }
        tts = try await KittenTTS()
    }

    // MARK: - Basic synthesis

    func testGenerateShortText() async throws {
        let result = try await tts.generate("Hello.")
        XCTAssertFalse(result.samples.isEmpty, "Expected audio samples")
        XCTAssertGreaterThan(result.duration, 0)
        XCTAssertEqual(result.sampleRate, KittenTTSConfig.outputSampleRate)
        XCTAssertEqual(result.inputText, "Hello.")
    }

    func testGenerateLongerText() async throws {
        let text = "KittenTTS is a fast on-device text-to-speech engine for Apple platforms."
        let result = try await tts.generate(text)
        XCTAssertGreaterThan(result.duration, 1.0, "Expected at least one second of audio")
        XCTAssertEqual(result.inputText, text)
    }

    // MARK: - All voices

    func testAllVoicesProduceAudio() async throws {
        for voice in KittenVoice.allCases {
            let result = try await tts.generate("Hello.", voice: voice)
            XCTAssertFalse(result.samples.isEmpty, "Voice \(voice.displayName) produced no audio")
            XCTAssertEqual(result.voice, voice)
        }
    }

    // MARK: - Speed variants

    func testSpeedSlowProducesLongerAudio() async throws {
        let slow   = try await tts.generate("Hello world", speed: 0.5)
        let normal = try await tts.generate("Hello world", speed: 1.0)
        XCTAssertGreaterThan(slow.duration, normal.duration,
                             "Slow speed should produce longer audio")
    }

    func testSpeedFastProducesShorterAudio() async throws {
        let fast   = try await tts.generate("Hello world", speed: 2.0)
        let normal = try await tts.generate("Hello world", speed: 1.0)
        XCTAssertLessThan(fast.duration, normal.duration,
                          "Fast speed should produce shorter audio")
    }

    // MARK: - Error cases

    func testEmptyInputThrows() async throws {
        do {
            _ = try await tts.generate("")
            XCTFail("Expected emptyInput error")
        } catch KittenTTSError.emptyInput {
            // expected
        }
    }

    func testWhitespaceOnlyThrows() async throws {
        do {
            _ = try await tts.generate("   ")
            XCTFail("Expected emptyInput error")
        } catch KittenTTSError.emptyInput {
            // expected
        }
    }

    // MARK: - WAV export

    func testWavDataIsValidRIFF() async throws {
        let result  = try await tts.generate("Hello.")
        let wavData = result.wavData()
        XCTAssertGreaterThan(wavData.count, 44, "WAV data should be larger than header")
        let riff = String(bytes: wavData.prefix(4), encoding: .ascii)
        XCTAssertEqual(riff, "RIFF")
    }

    func testWriteWAVToDisk() async throws {
        let result = try await tts.generate("Hello.")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kitten_test_\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try result.writeWAV(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 44)
    }

    // MARK: - isModelCached

    func testIsModelCachedReturnsTrueAfterInit() {
        XCTAssertTrue(KittenTTS.isModelCached())
    }

    // MARK: - Chunking (long text)

    func testLongTextProducesAudio() async throws {
        let longText = Array(repeating: "The quick brown fox jumps over the lazy dog.", count: 10)
            .joined(separator: " ")
        let result = try await tts.generate(longText)
        XCTAssertGreaterThan(result.duration, 5.0,
                             "Long text should produce more than 5 seconds of audio")
    }
}
