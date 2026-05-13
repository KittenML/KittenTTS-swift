import Foundation
import CEPhonemizer

/// High-quality IPA phonemizer for English text.
///
/// Uses a C++ engine that reads `en_rules` / `en_list` data files to
/// produce accurate IPA for any English input.
/// Works on iOS, macOS, and Simulators with zero external dependencies.
///
/// Data files are downloaded on first use and cached on disk by default. You can
/// override the download URLs to point to your own hosted copies, or provide
/// local data files when bundling assets with your app:
///
/// ```swift
/// let phonemizer = EPhonemizer(
///     rulesURL: myCustomRulesURL,
///     listURL: myCustomListURL
/// )
/// let config = KittenTTSConfig(phonemizer: .custom(phonemizer))
/// ```
///
/// ```swift
/// let phonemizer = EPhonemizer(
///     rulesFileURL: Bundle.main.url(forResource: "en_rules", withExtension: nil)!,
///     listFileURL: Bundle.main.url(forResource: "en_list", withExtension: nil)!
/// )
/// ```
///
/// This is the default (`.builtin`) phonemizer for ``KittenTTS``.
public final class EPhonemizer: KittenPhonemizerProtocol, @unchecked Sendable {

    // MARK: - Default download URLs

    /// Default URL for the `en_rules` data file.
    public static let defaultRulesURL = URL(string:
        "https://raw.githubusercontent.com/espeak-ng/espeak-ng/59eb19938f12e30881c81d86ce4a7de25414c9f4/dictsource/en_rules"
    )!

    /// Default URL for the `en_list` data file.
    public static let defaultListURL = URL(string:
        "https://raw.githubusercontent.com/espeak-ng/espeak-ng/59eb19938f12e30881c81d86ce4a7de25414c9f4/dictsource/en_list"
    )!

    // MARK: - Properties

    private let rulesDownloadURL: URL
    private let listDownloadURL: URL
    private let rulesFileURL: URL?
    private let listFileURL: URL?

    private let lock = NSLock()
    private var handle: PhonemizerHandle?

    // MARK: - Init

    /// Create an EPhonemizer with optional custom download URLs or local files.
    ///
    /// The phonemizer does **not** load data at init time. Call
    /// ``downloadIfNeeded(to:progressHandler:)`` (done automatically by
    /// ``KittenTTS``) to fetch or validate the data files, then
    /// ``phonemize(_:)`` will lazily initialise the C++ engine on first call.
    ///
    /// - Parameters:
    ///   - rulesURL: URL to download `en_rules` from. Defaults to
    ///     ``defaultRulesURL``.
    ///   - listURL: URL to download `en_list` from. Defaults to
    ///     ``defaultListURL``.
    ///   - rulesFileURL: Local `en_rules` file. When provided with
    ///     `listFileURL`, no phonemizer data is downloaded.
    ///   - listFileURL: Local `en_list` file. When provided with
    ///     `rulesFileURL`, no phonemizer data is downloaded.
    public init(
        rulesURL: URL? = nil,
        listURL: URL? = nil,
        rulesFileURL: URL? = nil,
        listFileURL: URL? = nil
    ) {
        self.rulesDownloadURL = rulesURL ?? Self.defaultRulesURL
        self.listDownloadURL  = listURL  ?? Self.defaultListURL
        self.rulesFileURL = rulesFileURL
        self.listFileURL = listFileURL
    }

    deinit {
        if let handle { phonemizer_destroy(handle) }
    }

    // MARK: - Download

    /// Resolved paths to cached data files. Set after download.
    private var cachedRulesPath: String?
    private var cachedListPath: String?

    public func downloadIfNeeded(
        to storageDirectory: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        if rulesFileURL != nil || listFileURL != nil {
            try loadBundledFiles(progressHandler: progressHandler)
            return
        }

        let dir = storageDirectory.appendingPathComponent("EPhonemizer", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let rulesDst = dir.appendingPathComponent("en_rules")
        let listDst  = dir.appendingPathComponent("en_list")

        let rulesExists = FileManager.default.fileExists(atPath: rulesDst.path)
        let listExists  = FileManager.default.fileExists(atPath: listDst.path)

        if rulesExists && listExists {
            setCachedPaths(rulesPath: rulesDst.path, listPath: listDst.path)
            progressHandler?(1.0)
            return
        }

        // Download en_rules (60% of progress)
        if !rulesExists {
            try await Self.downloadFile(from: rulesDownloadURL, to: rulesDst) { p in
                progressHandler?(p * 0.6)
            }
        }

        // Download en_list (40% of progress)
        if !listExists {
            try await Self.downloadFile(from: listDownloadURL, to: listDst) { p in
                progressHandler?(0.6 + p * 0.4)
            }
        }

        setCachedPaths(rulesPath: rulesDst.path, listPath: listDst.path)
        progressHandler?(1.0)
    }

    private func loadBundledFiles(progressHandler: ((Double) -> Void)?) throws {
        guard let rulesFileURL, let listFileURL else {
            throw KittenTTSError.phonemizerLoadFailed(
                "Both rulesFileURL and listFileURL must be provided for bundled EPhonemizer data."
            )
        }

        guard FileManager.default.fileExists(atPath: rulesFileURL.path) else {
            throw KittenTTSError.phonemizerLoadFailed("Rules file not found: \(rulesFileURL.path)")
        }
        guard FileManager.default.fileExists(atPath: listFileURL.path) else {
            throw KittenTTSError.phonemizerLoadFailed("List file not found: \(listFileURL.path)")
        }

        setCachedPaths(rulesPath: rulesFileURL.path, listPath: listFileURL.path)
        progressHandler?(1.0)
    }

    private func setCachedPaths(rulesPath: String, listPath: String) {
        lock.lock()
        cachedRulesPath = rulesPath
        cachedListPath = listPath
        lock.unlock()
    }

    // MARK: - KittenPhonemizerProtocol

    public func phonemize(_ text: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        // Lazy init the C++ engine on first phonemize call
        if handle == nil {
            guard let rulesPath = cachedRulesPath,
                  let listPath = cachedListPath else {
                return ""
            }
            handle = phonemizer_create(rulesPath, listPath, "en-us")
            guard handle != nil else { return "" }
        }

        guard let cStr = phonemizer_phonemize(handle, text) else {
            return ""
        }
        let result = String(cString: cStr)
        phonemizer_free_string(cStr)
        return result
    }

    // MARK: - Private download helper

    private static func downloadFile(
        from src: URL,
        to dst: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let delegate = DownloadDelegate(dst: dst, progress: progressHandler) { error in
                if let error {
                    cont.resume(throwing: KittenTTSError.downloadFailed(
                        "EPhonemizer data download failed: \(error.localizedDescription)"
                    ))
                } else {
                    cont.resume()
                }
            }
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: src).resume()
            delegate.session = session
        }
    }
}

// MARK: - Download delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let dst: URL
    let progress: (Double) -> Void
    let completion: (Error?) -> Void
    var session: URLSession?

    init(dst: URL, progress: @escaping (Double) -> Void, completion: @escaping (Error?) -> Void) {
        self.dst        = dst
        self.progress   = progress
        self.completion = completion
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.moveItem(at: location, to: dst)
            completion(nil)
        } catch {
            completion(error)
        }
        self.session = nil
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            completion(error)
            self.session = nil
        }
    }
}
