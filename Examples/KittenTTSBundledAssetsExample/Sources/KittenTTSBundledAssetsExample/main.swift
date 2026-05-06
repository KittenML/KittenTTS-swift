import SwiftUI
import KittenTTS

@main
struct KittenTTSBundledAssetsApp: App {
    var body: some Scene {
        WindowGroup("KittenTTS Bundled Assets") {
            ContentView()
                .frame(minWidth: 640, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            status
            editor
            controls
            actions
            result
            Spacer(minLength: 0)
        }
        .padding(22)
        .task { await viewModel.loadAssets() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("KittenTTS Bundled Assets")
                    .font(.title2.bold())
                Text(viewModel.assetsURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                Task { await viewModel.loadAssets() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isWorking)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.state {
        case .idle:
            if let manifest = viewModel.manifest {
                Label("Manifest loaded: \(manifest.availableModels.map(\.displayName).joined(separator: ", "))",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }
        case .missingAssets:
            VStack(alignment: .leading, spacing: 8) {
                Label("No bundled assets found", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text("Run this in `Examples/KittenTTSBundledAssetsExample`:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("npx @kittentts/react-native bundle-assets --models nano-int8 --out assets/kittentts")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        case .loading:
            Label("Loading bundled assets...", systemImage: "shippingbox")
                .font(.subheadline)
        case .generating:
            Label("Generating speech...", systemImage: "waveform.badge.clock")
                .font(.subheadline)
        case .playing:
            Label("Playing...", systemImage: "speaker.wave.2.fill")
                .font(.subheadline)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Text")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $viewModel.inputText)
                .font(.body)
                .frame(minHeight: 110, maxHeight: 160)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .disabled(viewModel.isWorking || viewModel.manifest == nil)
        }
    }

    private var controls: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .frame(width: 140)
                .disabled(viewModel.isWorking || viewModel.availableModels.isEmpty)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $viewModel.selectedVoice) {
                    ForEach(KittenVoice.allCases) { voice in
                        Text(voice.displayName).tag(voice)
                    }
                }
                .frame(width: 130)
                .disabled(viewModel.isWorking || viewModel.manifest == nil)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(String(format: "%.1f", viewModel.speed))x")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.speed, in: 0.5 ... 2.0, step: 0.1)
                    .frame(minWidth: 180)
                    .disabled(viewModel.isWorking || viewModel.manifest == nil)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.generateWAV() }
            } label: {
                Label("Generate WAV", systemImage: "waveform")
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!viewModel.canGenerate)

            Button {
                Task { await viewModel.speak() }
            } label: {
                Label("Speak", systemImage: "speaker.wave.2")
            }
            .disabled(!viewModel.canGenerate)

            Spacer()

            if viewModel.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var result: some View {
        if let lastResult = viewModel.lastResult {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(lastResult.voice.displayName, systemImage: "person.wave.2")
                        Spacer()
                        Label(String(format: "%.2fs", lastResult.duration), systemImage: "clock")
                        Spacer()
                        Label(viewModel.outputURL.lastPathComponent, systemImage: "doc.waveform")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(viewModel.outputURL.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            } label: {
                Label("Last Output", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
    }
}

@Observable
@MainActor
final class ViewModel {
    enum State: Equatable {
        case idle
        case missingAssets
        case loading
        case generating
        case playing
        case error(String)
    }

    var inputText = "Hello from KittenTTS bundled offline assets."
    var selectedVoice: KittenVoice = .bella
    var selectedModel: KittenModel = .nanoInt8
    var speed: Double = 1.0
    var state: State = .loading
    var manifest: KittenTTSBundledAssetsManifest?
    var lastResult: KittenTTSResult?

    let assetsURL = AssetLocator.resolveAssetsURL()
    let outputURL = URL(fileURLWithPath: "bundled-output.wav")

    var availableModels: [KittenModel] {
        manifest?.availableModels ?? []
    }

    var isWorking: Bool {
        switch state {
        case .loading, .generating, .playing:
            return true
        default:
            return false
        }
    }

    var canGenerate: Bool {
        manifest != nil &&
        !isWorking &&
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadAssets() async {
        state = .loading
        lastResult = nil

        let manifestURL = assetsURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            manifest = nil
            state = .missingAssets
            return
        }

        do {
            let loadedManifest = try KittenTTSBundledAssets.loadManifest(from: manifestURL)
            manifest = loadedManifest
            selectedModel = loadedManifest.availableModels.contains(loadedManifest.defaultModel)
                ? loadedManifest.defaultModel
                : (loadedManifest.availableModels.first ?? selectedModel)
            state = .idle
        } catch {
            manifest = nil
            state = .error(error.localizedDescription)
        }
    }

    func generateWAV() async {
        await synthesize(play: false)
    }

    func speak() async {
        await synthesize(play: true)
    }

    private func synthesize(play: Bool) async {
        guard let manifest else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        state = play ? .playing : .generating
        do {
            let config = try KittenTTSBundledAssets.config(
                from: manifest,
                baseURL: assetsURL,
                model: selectedModel,
                defaultVoice: selectedVoice,
                speed: Float(speed)
            )
            let tts = try await KittenTTS(config)
            let result = play
                ? try await tts.speak(text, voice: selectedVoice, speed: Float(speed))
                : try await tts.generate(text, voice: selectedVoice, speed: Float(speed))
            try result.writeWAV(to: outputURL)
            lastResult = result
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

enum AssetLocator {
    static func resolveAssetsURL() -> URL {
        if let bundledURL = Bundle.main.resourceURL?
            .appendingPathComponent("kittentts", isDirectory: true),
           FileManager.default.fileExists(atPath: bundledURL.appendingPathComponent("manifest.json").path) {
            return bundledURL
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("assets/kittentts", isDirectory: true)
    }
}
