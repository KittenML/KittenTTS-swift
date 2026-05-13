# KittenTTS macOS Bundled Example

SwiftUI macOS example for loading KittenTTS from pre-bundled offline assets.

This mirrors the React Native SDK's `bundle-assets` layout:

```text
assets/kittentts/
  manifest.json
  kitten-tts-nano-0.8-int8/kitten_tts_nano_v0_8.onnx
  kitten-tts-nano-0.8-int8/voices.npz
  CEPhonemizer/en_rules.txt
  CEPhonemizer/en_list.txt
```

Generate assets from a React Native app or compatible workspace:

```bash
npx @kittentts/react-native bundle-assets --models nano-int8 --out assets/kittentts
```

Then copy or symlink the generated `assets/kittentts` directory into this
example and open the Xcode project:

```bash
open KittenTTSmacOSBundledExample.xcodeproj
```

The app loads the manifest, lets you choose a bundled model and voice, and can
play speech or write `~/Downloads/bundled-output.wav`.
