import Foundation

/// Local model files to use instead of downloading KittenTTS assets.
///
/// Use this when an app bundles the ONNX model and `voices.npz`, for example
/// from the React Native SDK's `assets/kittentts` bundle.
public struct KittenTTSModelFiles: Sendable, Equatable {
    /// File URL for the ONNX model.
    public let onnxURL: URL

    /// File URL for the `voices.npz` embedding archive.
    public let voicesURL: URL

    public init(onnxURL: URL, voicesURL: URL) {
        self.onnxURL = onnxURL
        self.voicesURL = voicesURL
    }
}
