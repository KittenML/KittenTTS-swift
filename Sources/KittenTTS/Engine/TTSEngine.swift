import Foundation
import OnnxRuntimeBindings

/// Internal ONNX inference engine.
///
/// Orchestrates the full pipeline:
/// `text → TextPreprocessor → Phonemizer → TextCleaner → ONNX → Float32 PCM`
final class TTSEngine {

    // MARK: - Private state

    private let session: ORTSession
    private let ortEnv: ORTEnv         // must outlive session
    private let voices: [String: VoiceEmbedding]
    private let outputName: String
    private let config: KittenTTSConfig
    private let phonemizer: any KittenPhonemizerProtocol

    // MARK: - Init

    /// Load a pre-downloaded model and voices file, then initialise the ORT session.
    ///
    /// This is CPU-only; CoreML EP is intentionally excluded to avoid shape-inference
    /// errors with the KittenTTS model on some devices.
    init(modelURL: URL, voicesURL: URL, config: KittenTTSConfig, phonemizer: any KittenPhonemizerProtocol) throws {
        self.config     = config
        self.phonemizer = phonemizer

        let env  = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
        let opts = try ORTSessionOptions()
        try opts.setGraphOptimizationLevel(ORTGraphOptimizationLevel.all)
        try opts.setIntraOpNumThreads(Int32(config.ortNumThreads))

        let session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: opts)
        let outName = (try? session.outputNames())?.first ?? "output"
        let voices  = try NPZLoader.load(contentsOf: voicesURL)

        self.ortEnv     = env
        self.session    = session
        self.outputName = outName
        self.voices     = voices
    }

    // MARK: - Generation

    /// Synthesise speech and return raw Float32 PCM samples at 24 kHz.
    ///
    /// Long texts are split into chunks of at most ``KittenTTSConfig/maxTokensPerChunk``
    /// tokens to avoid out-of-memory errors.
    ///
    /// - Parameters:
    ///   - text: Normalised input text (already preprocessed).
    ///   - voice: The ``KittenVoice`` to use.
    ///   - speed: Effective speed multiplier (already pre-multiplied with voice's default).
    /// - Returns: Float32 PCM samples at ``KittenTTSConfig/outputSampleRate`` Hz.
    /// - Throws: ``KittenTTSError`` on inference failure or missing voice data.
    func generate(text: String, voice: KittenVoice, speed: Float) throws -> [Float] {
        guard let embedding = voices[voice.rawValue] else {
            throw KittenTTSError.noVoiceEmbedding(voice)
        }

        let normalised = TextPreprocessor.process(text)
        let phonemes   = phonemizer.phonemize(normalised)
        let tokens     = TextCleaner.encode(phonemes)
        let chunks     = splitIntoChunks(tokens)
        let effectiveSpeed = speed * config.model.speedPrior(for: voice)

        var allSamples: [Float] = []
        for chunk in chunks {
            let samples = try runChunk(
                tokens: chunk,
                embedding: embedding,
                phonemeLength: phonemes.count,
                speed: effectiveSpeed
            )
            allSamples.append(contentsOf: samples)
        }

        guard !allSamples.isEmpty else { throw KittenTTSError.emptyOutput }
        return allSamples
    }

    // MARK: - Private

    private func runChunk(tokens: [Int64],
                          embedding: VoiceEmbedding,
                          phonemeLength: Int,
                          speed: Float) throws -> [Float] {
        let styleVec = embedding.slice(forTextLength: phonemeLength)

        let tokenTensor = try ortTensor(int64: tokens, shape: [1, tokens.count])
        let styleTensor = try ortTensor(float: styleVec, shape: [1, styleVec.count])
        let speedTensor = try ortTensor(float: [speed], shape: [1])

        let results = try session.run(
            withInputs: ["input_ids": tokenTensor, "style": styleTensor, "speed": speedTensor],
            outputNames: Set([outputName]),
            runOptions: nil
        )

        guard let outValue = results[outputName] else { throw KittenTTSError.emptyOutput }

        let outData = try outValue.tensorData() as Data
        let count   = outData.count / MemoryLayout<Float>.stride
        guard count > 0 else { throw KittenTTSError.emptyOutput }

        var samples = [Float](unsafeUninitializedCapacity: count) { buf, n in
            outData.withUnsafeBytes { src in _ = src.copyBytes(to: buf) }
            n = count
        }

        // KittenTTS appends ~0.2 s of silence at the end of each chunk; trim it.
        let trim = min(5_000, samples.count)
        samples.removeLast(trim)
        return samples
    }

    private func splitIntoChunks(_ tokens: [Int64]) -> [[Int64]] {
        let body    = Array(tokens.dropFirst().dropLast(2))
        let maxBody = config.maxTokensPerChunk - 3
        if body.count <= maxBody { return [tokens] }

        var chunks: [[Int64]] = []
        var i = 0
        while i < body.count {
            let slice = Array(body[i ..< min(i + maxBody, body.count)])
            chunks.append(
                [TextCleaner.startTokenID] + slice + [TextCleaner.endTokenID, TextCleaner.padTokenID]
            )
            i += maxBody
        }
        return chunks
    }
}

// MARK: - ORT tensor helpers

private func ortTensor(float values: [Float], shape: [Int]) throws -> ORTValue {
    try values.withUnsafeBytes { raw in
        let mdata = NSMutableData(bytes: raw.baseAddress!, length: raw.count)
        return try ORTValue(tensorData: mdata,
                            elementType: ORTTensorElementDataType.float,
                            shape: shape.map { NSNumber(value: $0) })
    }
}

private func ortTensor(int64 values: [Int64], shape: [Int]) throws -> ORTValue {
    try values.withUnsafeBytes { raw in
        let mdata = NSMutableData(bytes: raw.baseAddress!, length: raw.count)
        return try ORTValue(tensorData: mdata,
                            elementType: ORTTensorElementDataType.int64,
                            shape: shape.map { NSNumber(value: $0) })
    }
}
