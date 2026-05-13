import XCTest
@testable import KittenTTS

final class BundledAssetsTests: XCTestCase {

    func testDecodesVersionTwoManifestAndBuildsConfig() throws {
        let json = """
        {
          "version": 2,
          "defaultModel": "kitten-tts-nano-0.8-int8",
          "models": {
            "kitten-tts-nano-0.8-int8": {
              "onnx": "kitten-tts-nano-0.8-int8/kitten_tts_nano_v0_8.onnx",
              "voices": "kitten-tts-nano-0.8-int8/voices.npz"
            },
            "kitten-tts-micro-0.8": {
              "onnx": "kitten-tts-micro-0.8/kitten_tts_micro_v0_8.onnx",
              "voices": "kitten-tts-micro-0.8/voices.npz"
            }
          },
          "files": {
            "phonemizerRules": "CEPhonemizer/en_rules.txt",
            "phonemizerList": "CEPhonemizer/en_list.txt"
          }
        }
        """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(KittenTTSBundledAssetsManifest.self, from: json)
        let baseURL = URL(fileURLWithPath: "/tmp/kittentts", isDirectory: true)
        let config = try KittenTTSBundledAssets.config(
            from: manifest,
            baseURL: baseURL,
            model: .micro,
            defaultVoice: .luna,
            speed: 1.25
        )

        XCTAssertEqual(manifest.defaultModel, .nanoInt8)
        XCTAssertEqual(manifest.availableModels, [.micro, .nanoInt8])
        XCTAssertEqual(config.model, .micro)
        XCTAssertEqual(config.defaultVoice, .luna)
        XCTAssertEqual(config.speed, 1.25, accuracy: 0.001)
        XCTAssertEqual(
            config.modelFiles?.onnxURL.path,
            "/tmp/kittentts/kitten-tts-micro-0.8/kitten_tts_micro_v0_8.onnx"
        )
        XCTAssertEqual(
            config.modelFiles?.voicesURL.path,
            "/tmp/kittentts/kitten-tts-micro-0.8/voices.npz"
        )
    }

    func testDecodesVersionOneManifest() throws {
        let json = """
        {
          "version": 1,
          "model": "kitten-tts-nano-0.8",
          "files": {
            "onnx": "kitten-tts-nano-0.8/kitten_tts_nano_v0_8.onnx",
            "voices": "kitten-tts-nano-0.8/voices.npz",
            "phonemizerRules": "CEPhonemizer/en_rules.txt",
            "phonemizerList": "CEPhonemizer/en_list.txt"
          }
        }
        """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(KittenTTSBundledAssetsManifest.self, from: json)
        let files = try manifest.modelFiles()

        XCTAssertEqual(manifest.defaultModel, .nano)
        XCTAssertEqual(manifest.availableModels, [.nano])
        XCTAssertEqual(files.onnx, "kitten-tts-nano-0.8/kitten_tts_nano_v0_8.onnx")
        XCTAssertEqual(files.voices, "kitten-tts-nano-0.8/voices.npz")
    }

    func testMissingManifestModelThrows() throws {
        let json = """
        {
          "version": 2,
          "defaultModel": "kitten-tts-mini-0.8",
          "models": {
            "kitten-tts-nano-0.8-int8": {
              "onnx": "kitten-tts-nano-0.8-int8/kitten_tts_nano_v0_8.onnx",
              "voices": "kitten-tts-nano-0.8-int8/voices.npz"
            }
          },
          "files": {
            "phonemizerRules": "CEPhonemizer/en_rules.txt",
            "phonemizerList": "CEPhonemizer/en_list.txt"
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(KittenTTSBundledAssetsManifest.self, from: json))
    }
}
