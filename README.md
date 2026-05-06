# Kitten TTS Swift SDK

On-device text-to-speech Swift SDK for iOS and macOS, powered by [Kitten TTS](https://github.com/KittenML/KittenTTS).

```swift
let tts = try await KittenTTS()
let result = try await tts.generate("Hello from Kitten TTS!")
try await tts.speak("Good morning!")
```

## Features

- **Fully on-device** — no network calls after setup
- **Bundled offline assets** — ship model and phonemizer files with your app
- **4 model sizes** — nano (fp32/int8), micro, and mini
- **8 voices** — Bella, Jasper, Luna, Bruno, Rosie, Hugo, Kiki, Leo
- **Simple async API** — one line to generate or play speech
- **WAV export** — save audio to disk with `result.writeWAV(to:)`
- **iOS 16+ / macOS 14+**

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS      | 16.0    |
| macOS    | 14.0    |
| Swift    | 5.9     |
| Xcode    | 15+     |

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KittenML/KittenTTS-swift", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "KittenTTS", package: "KittenTTS-swift"),
    ]),
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter the repository URL.

## Quick Start

### 1. Create an instance

The first call downloads phonemizer data files and the model, then caches them
in Application Support. Subsequent calls are instant.

```swift
import KittenTTS

// Default config (nano fp32 model, Bella voice, 1× speed)
let tts = try await KittenTTS()

// With download progress
let tts = try await KittenTTS { progress in
    print("Download: \(Int(progress * 100))%")
}
```

### 2. Generate audio

```swift
let result = try await tts.generate("Hello, world!")

print("Duration: \(result.duration)s")
print("Voice: \(result.voice.displayName)")
print("Samples: \(result.samples.count)")
```

### 3. Play through speakers

```swift
// Generate + play (returns when playback finishes)
try await tts.speak("Hello, world!")

// Or generate first, then play later
let result = try await tts.generate("Hello, world!")
try await tts.speak(result.inputText, voice: result.voice)
```

### 4. Save as WAV

```swift
let result = try await tts.generate("Hello, world!")

// Get raw Data
let data = result.wavData()

// Write directly to a URL
let url = URL(fileURLWithPath: "/tmp/hello.wav")
try result.writeWAV(to: url)
```

## Configuration

```swift
let config = KittenTTSConfig(
    model: .nano,           // .nano (fp32), .nanoInt8, .micro, .mini
    defaultVoice: .luna,    // default voice
    speed: 1.1,             // global speed multiplier (0.5–2.0)
    storageDirectory: nil,  // nil = Application Support/KittenTTS/
    modelFiles: nil,        // set for bundled/offline model assets
    ortNumThreads: 4,       // ONNX intra-op thread count
    maxTokensPerChunk: 400  // max tokens per inference chunk
)
let tts = try await KittenTTS(config)
```

## Bundled Offline Assets

Use bundled assets when the app must work without a first-run network download.
This matches the React Native SDK's `bundle-assets` output:

```text
assets/kittentts/
  manifest.json
  kitten-tts-nano-0.8-int8/kitten_tts_nano_v0_8.onnx
  kitten-tts-nano-0.8-int8/voices.npz
  CEPhonemizer/en_rules.txt
  CEPhonemizer/en_list.txt
```

If the `kittentts` directory is included in the app bundle, create a config
directly from `manifest.json`:

```swift
let config = try KittenTTSBundledAssets.configFromBundle(
    assetRoot: "kittentts",
    model: .nanoInt8
)
let tts = try await KittenTTS(config)
```

You can also wire file URLs explicitly:

```swift
let assetRoot = Bundle.main.resourceURL!.appendingPathComponent("kittentts")
let config = KittenTTSConfig(
    model: .nanoInt8,
    phonemizer: .custom(EPhonemizer(
        rulesFileURL: assetRoot.appendingPathComponent("CEPhonemizer/en_rules.txt"),
        listFileURL: assetRoot.appendingPathComponent("CEPhonemizer/en_list.txt")
    )),
    modelFiles: KittenTTSModelFiles(
        onnxURL: assetRoot.appendingPathComponent("kitten-tts-nano-0.8-int8/kitten_tts_nano_v0_8.onnx"),
        voicesURL: assetRoot.appendingPathComponent("kitten-tts-nano-0.8-int8/voices.npz")
    )
)
let tts = try await KittenTTS(config)
```

When `modelFiles` and bundled `EPhonemizer` file URLs are provided, `KittenTTS`
does not download model or phonemizer assets.

## Models

| Case | Name | Size | Parameters |
|------|------|------|------------|
| `.nano` *(default)* | Nano (fp32) | ~56 MB | 15M |
| `.nanoInt8` | Nano (int8) | ~25 MB | 15M |
| `.micro` | Micro | ~41 MB | 40M |
| `.mini` | Mini | ~80 MB | 80M |

## Phonemizers

KittenSDK ships three options for English G2P (grapheme-to-phoneme) conversion, all
selected through `KittenTTSConfig.phonemizer`:

| Option | Quality | Dependencies | Platform |
|--------|---------|--------------|----------|
| `.builtin` *(default)* | High — accurate IPA with stress marks | None (data files downloaded on first use) | iOS + macOS |
| `.espeak` | High — invokes the system `espeak-ng` binary | `brew install espeak-ng` | macOS only |
| `.custom(…)` | Varies | Your own implementation | Any |

### EPhonemizer (default)

The default `.builtin` phonemizer uses `EPhonemizer`, a C++ engine that reads
rule and dictionary data files to produce high-quality IPA output. Data files
(`en_rules`, `en_list`) are automatically downloaded on first use and cached
alongside the model.

You can override the download URLs to point to your own hosted copies:

```swift
let phonemizer = EPhonemizer(
    rulesURL: URL(string: "https://example.com/en_rules")!,
    listURL:  URL(string: "https://example.com/en_list")!
)
let config = KittenTTSConfig(phonemizer: .custom(phonemizer))
```

Or provide local files bundled with the app:

```swift
let phonemizer = EPhonemizer(
    rulesFileURL: assetRoot.appendingPathComponent("CEPhonemizer/en_rules.txt"),
    listFileURL: assetRoot.appendingPathComponent("CEPhonemizer/en_list.txt")
)
let config = KittenTTSConfig(phonemizer: .custom(phonemizer))
```

### Custom phonemizer

Implement `KittenPhonemizerProtocol` to plug in any G2P engine:

```swift
struct MyPhonemizer: KittenPhonemizerProtocol {
    func phonemize(_ text: String) -> String {
        // your G2P logic here
    }
}
let config = KittenTTSConfig(phonemizer: .custom(MyPhonemizer()))
```

## Voices

| Case | Name | Gender |
|------|------|--------|
| `.bella` *(default)* | Bella | Female |
| `.jasper` | Jasper | Male |
| `.luna` | Luna | Female |
| `.bruno` | Bruno | Male |
| `.rosie` | Rosie | Female |
| `.hugo` | Hugo | Male |
| `.kiki` | Kiki | Female |
| `.leo` | Leo | Male |

## API Reference

### `KittenTTS`

```swift
// Init — downloads phonemizer data & model if needed
public init(_ config: KittenTTSConfig = .init(),
            downloadProgressHandler: ((Double) -> Void)? = nil) async throws

// Generate audio
public func generate(_ text: String,
                     voice: KittenVoice? = nil,
                     speed: Float? = nil) async throws -> KittenTTSResult

// Generate and play
@discardableResult
public func speak(_ text: String,
                  voice: KittenVoice? = nil,
                  speed: Float? = nil) async throws -> KittenTTSResult

// Stop playback
public func stopSpeaking()

// Check if model is cached (no download required)
public static func isModelCached(for config: KittenTTSConfig = .init()) -> Bool

// Pre-download without creating a full instance
public static func prewarm(config: KittenTTSConfig = .init()) async throws
```

### `KittenTTSResult`

```swift
public struct KittenTTSResult {
    public let samples: [Float]          // Raw Float32 PCM at 24 kHz
    public let sampleRate: Int           // Always 24_000
    public var duration: TimeInterval    // Audio length in seconds
    public let voice: KittenVoice        // Voice used
    public let effectiveSpeed: Float     // Speed × model speed prior
    public let inputText: String         // Original input text

    public func wavData() -> Data                    // Encode as WAV
    public func writeWAV(to url: URL) throws         // Write WAV to disk
}
```

## Examples

The `Examples/` directory contains two complete SwiftUI apps:

- **`KittenTTSiOSExample/`** — iOS 17+ app (iPhone / iPad)
- **`KittenTTSmacOSExample/`** — macOS 14+ app (native Mac window)

To open an example, regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd Examples/KittenTTSiOSExample
xcodegen generate
open KittenTTSiOSExample.xcodeproj
```

## Architecture

```
KittenSDK/
├── Sources/
│   ├── Czlib/               # System library shim for zlib (DEFLATE in .npz)
│   ├── CEPhonemizer/        # C++ phonemizer engine + C bridge for Swift interop
│   └── KittenTTS/
│       ├── Public/          # Public API (KittenTTS, KittenVoice, KittenPhonemizerProtocol, …)
│       ├── Engine/          # TextPreprocessor, TextCleaner, TTSEngine
│       ├── Phonemizer/      # EPhonemizer, BuiltinPhonemizer, ESpeakBinaryPhonemizer, RuleBasedG2P
│       ├── Loader/          # NPZLoader (ZIP64 + float16/32 .npy)
│       ├── Audio/           # WAVEncoder, AudioOutput
│       └── Internal/        # Extensions, ModelDownloader
├── Tests/KittenTTSTests/    # XCTest suite
└── Examples/
    ├── KittenTTSiOSExample/
    └── KittenTTSmacOSExample/
```

### Pipeline

```
text
 └─▶ TextPreprocessor      (numbers, currency, ordinals → words)
      └─▶ KittenPhonemizerProtocol  (pluggable G2P: builtin / espeak binary / custom)
           └─▶ TextCleaner (IPA → Int64 token IDs)
                └─▶ TTSEngine (ONNX Runtime inference, chunked)
                     └─▶ Float32 PCM @ 24 kHz
                          └─▶ WAVEncoder / AudioOutput
```

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

The KittenTTS model weights are distributed separately under their own license.
See [KittenML/KittenTTS](https://github.com/KittenML/KittenTTS) for details.

The SDK supports multiple pluggable phonemizers via `KittenPhonemizerProtocol`.
When using `EPhonemizer` it downloads GPL v3-licensed data files (`en_rules`,
`en_list`) at runtime - these files are only fetched when `EPhonemizer` is
selected and are not bundled in the SDK/app. 
