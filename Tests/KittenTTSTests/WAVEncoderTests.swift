import XCTest
@testable import KittenTTS

final class WAVEncoderTests: XCTestCase {

    func testOutputIsNonEmpty() {
        let data = WAVEncoder.encode(samples: [0.0, 0.5, -0.5], sampleRate: 24_000)
        XCTAssertFalse(data.isEmpty)
    }

    func testRIFFHeader() {
        let data = WAVEncoder.encode(samples: [0.0], sampleRate: 24_000)
        let riff = String(bytes: data.prefix(4), encoding: .ascii)
        XCTAssertEqual(riff, "RIFF")
    }

    func testWAVEMarker() {
        let data = WAVEncoder.encode(samples: [0.0], sampleRate: 24_000)
        let wave = String(bytes: data[8 ..< 12], encoding: .ascii)
        XCTAssertEqual(wave, "WAVE")
    }

    func testMinimumSize() {
        // A WAV with 0 samples should still have the 44-byte header
        let data = WAVEncoder.encode(samples: [], sampleRate: 24_000)
        XCTAssertEqual(data.count, 44)
    }

    func testSampleCountIncreasesOutputSize() {
        let empty   = WAVEncoder.encode(samples: [],                  sampleRate: 24_000)
        let oneSamp = WAVEncoder.encode(samples: [0.5],               sampleRate: 24_000)
        let tenSamp = WAVEncoder.encode(samples: Array(repeating: 0.5, count: 10), sampleRate: 24_000)
        XCTAssertGreaterThan(oneSamp.count, empty.count)
        XCTAssertGreaterThan(tenSamp.count, oneSamp.count)
    }

    func testClamping() {
        // Values outside ±1.0 should not crash
        let data = WAVEncoder.encode(samples: [2.0, -2.0, 100.0], sampleRate: 24_000)
        XCTAssertFalse(data.isEmpty)
    }
}
