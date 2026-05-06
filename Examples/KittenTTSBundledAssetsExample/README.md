# KittenTTS Bundled Assets macOS Example

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
example and run:

```bash
swift run KittenTTSBundledAssetsExample
```

The app loads the manifest, lets you choose a bundled model and voice, and can
play speech or write `bundled-output.wav`.

To build a standalone local `.app` bundle:

```bash
./make-macos-app.sh
open build/KittenTTSBundledAssetsExample.app
```

If `assets/kittentts` exists, the script copies it into
`Contents/Resources/kittentts` so the app uses bundle resources instead of the
working directory.
