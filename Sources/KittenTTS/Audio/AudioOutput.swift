import Foundation
import AVFoundation

/// Plays a ``KittenTTSResult`` through the device speakers.
///
/// On iOS the audio session is configured for `.playback` before playback starts.
/// On macOS no session management is required.
///
/// Audio playback is skipped gracefully in headless environments (e.g. simulator
/// CI without audio hardware), where ``isAudioAvailable()`` returns `false`.
final class AudioOutput: NSObject {

    private var player: AVAudioPlayer?

    // MARK: - Playback

    /// Play `samples` at `sampleRate` Hz through the device speakers.
    ///
    /// Returns as soon as playback completes (or is skipped due to no hardware).
    ///
    /// - Parameters:
    ///   - samples: Float32 PCM mono audio samples.
    ///   - sampleRate: Sample rate in Hz (e.g. 24 000).
    /// - Throws: ``KittenTTSError/audioSessionFailed(_:)`` if the session cannot be
    ///   configured, or ``KittenTTSError/playbackFailed(_:)`` if the player fails.
    func play(samples: [Float], sampleRate: Int) async throws {
        guard Self.isAudioAvailable() else { return }

        let wavData = WAVEncoder.encode(samples: samples, sampleRate: sampleRate)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
#if os(iOS)
                do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    cont.resume(throwing: KittenTTSError.audioSessionFailed(error.localizedDescription))
                    return
                }
#endif
                let p = try AVAudioPlayer(data: wavData)
                p.delegate = self
                p.prepareToPlay()
                self.player = p

                // Stash continuation so the delegate can resume it on completion.
                self.continuation = cont

                p.play()
            } catch {
                cont.resume(throwing: KittenTTSError.playbackFailed(error.localizedDescription))
            }
        }
    }

    /// Stop any currently active playback.
    func stop() {
        player?.stop()
        player = nil
        continuation?.resume()
        continuation = nil
    }

    // MARK: - Private

    private var continuation: CheckedContinuation<Void, Error>?

    // MARK: - Audio availability

    /// Returns `false` in headless simulator environments where coreaudiod is absent.
    static func isAudioAvailable() -> Bool {
#if os(iOS) && targetEnvironment(simulator)
        let session = AVAudioSession.sharedInstance()
        do { try session.setCategory(.ambient) } catch { return false }
        return !session.currentRoute.outputs.isEmpty
#else
        return true
#endif
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioOutput: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        if flag {
            continuation?.resume()
        } else {
            continuation?.resume(throwing: KittenTTSError.playbackFailed("Playback ended early"))
        }
        continuation = nil
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.player = nil
        continuation?.resume(
            throwing: KittenTTSError.playbackFailed(error?.localizedDescription ?? "Decode error")
        )
        continuation = nil
    }
}
