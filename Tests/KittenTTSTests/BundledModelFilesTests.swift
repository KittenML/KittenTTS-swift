import XCTest
@testable import KittenTTS

final class BundledModelFilesTests: XCTestCase {

    func testIsModelCachedUsesProvidedModelFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let onnxURL = tempDir.appendingPathComponent("model.onnx")
        let voicesURL = tempDir.appendingPathComponent("voices.npz")
        try Data([0]).write(to: onnxURL)
        try Data([1]).write(to: voicesURL)

        let config = KittenTTSConfig(
            modelFiles: KittenTTSModelFiles(onnxURL: onnxURL, voicesURL: voicesURL)
        )

        XCTAssertTrue(KittenTTS.isModelCached(for: config))
    }

    func testProvidedModelFilesMustExist() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let config = KittenTTSConfig(
            modelFiles: KittenTTSModelFiles(
                onnxURL: tempDir.appendingPathComponent("missing.onnx"),
                voicesURL: tempDir.appendingPathComponent("missing.npz")
            )
        )

        do {
            _ = try await ModelDownloader.downloadModelIfNeeded(for: config)
            XCTFail("Expected missing bundled model files to throw")
        } catch KittenTTSError.modelFileNotFound(let url) {
            XCTAssertEqual(url.lastPathComponent, "missing.onnx")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
