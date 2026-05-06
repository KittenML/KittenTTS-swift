import XCTest
@testable import KittenTTS

final class EPhonemizerBundledFilesTests: XCTestCase {

    func testBundledFileURLsSkipDownloadAndReportCompleteProgress() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let rulesURL = tempDir.appendingPathComponent("en_rules")
        let listURL = tempDir.appendingPathComponent("en_list")
        try "a A\n".write(to: rulesURL, atomically: true, encoding: .utf8)
        try "a A\n".write(to: listURL, atomically: true, encoding: .utf8)

        let phonemizer = EPhonemizer(rulesFileURL: rulesURL, listFileURL: listURL)
        var progressValues: [Double] = []

        try await phonemizer.downloadIfNeeded(to: tempDir) { progress in
            progressValues.append(progress)
        }

        XCTAssertEqual(progressValues, [1.0])
    }

    func testPartialBundledFileURLsThrow() async throws {
        let phonemizer = EPhonemizer(
            rulesFileURL: URL(fileURLWithPath: "/tmp/en_rules"),
            listFileURL: nil
        )

        do {
            try await phonemizer.downloadIfNeeded(to: FileManager.default.temporaryDirectory, progressHandler: nil)
            XCTFail("Expected partial bundled phonemizer files to throw")
        } catch KittenTTSError.phonemizerLoadFailed(let message) {
            XCTAssertTrue(message.contains("Both rulesFileURL and listFileURL"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
