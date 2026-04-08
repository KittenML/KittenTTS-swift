import SwiftUI
import KittenTTS

struct ContentView: View {

    @State private var viewModel = ViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text("KittenTTS")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isModelCached {
                    Label("Model ready", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Divider()

            // Status
            if case .downloading(let p) = viewModel.state {
                VStack(spacing: 6) {
                    Label("Downloading model (\(Int(p * 100))%)…", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                    ProgressView(value: p)
                }
                .padding(.horizontal, 4)
            }

            if case .error(let msg) = viewModel.state {
                Label(msg, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            // Text input
            VStack(alignment: .leading, spacing: 4) {
                Text("Input text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.inputText)
                    .font(.body)
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .disabled(viewModel.isWorking)
            }

            // Controls row
            HStack(spacing: 20) {
                // Model picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.selectedModel) {
                        ForEach(KittenModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .frame(width: 120)
                    .disabled(viewModel.isWorking)
                }

                // Voice picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $viewModel.selectedVoice) {
                        ForEach(KittenVoice.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .frame(width: 120)
                    .disabled(viewModel.isWorking)
                }

                // Speed
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(String(format: "%.1f×", viewModel.speed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.speed, in: 0.5 ... 2.0, step: 0.1)
                        .frame(minWidth: 160)
                        .disabled(viewModel.isWorking)
                }
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.speak() }
                } label: {
                    Label("Speak", systemImage: "speaker.wave.2")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.isWorking || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("speak_button")

                Button {
                    Task { await viewModel.generate() }
                } label: {
                    Label("Generate only", systemImage: "waveform")
                }
                .disabled(viewModel.isWorking || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("generate_button")

                if let result = viewModel.result, viewModel.state == .idle {
                    Button {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.wav]
                        panel.nameFieldStringValue = "output.wav"
                        if panel.runModal() == .OK, let url = panel.url {
                            try? result.writeWAV(to: url)
                        }
                    } label: {
                        Label("Save WAV", systemImage: "arrow.down.doc")
                    }
                }

                Spacer()

                if viewModel.isWorking {
                    ProgressView().controlSize(.small)
                }
            }

            // Result info
            if let result = viewModel.result {
                GroupBox {
                    HStack {
                        Label(result.voice.displayName, systemImage: "person.wave.2")
                        Spacer()
                        Label(String(format: "%.2fs", result.duration), systemImage: "clock")
                        Spacer()
                        Label(String(format: "%.1f\u{00D7}", result.effectiveSpeed), systemImage: "speedometer")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } label: {
                    Label("Last result", systemImage: "checkmark.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                .accessibilityIdentifier("result_groupbox")
            }

            Spacer()
        }
        .padding(20)
        .task { await viewModel.setup() }
        .onChange(of: viewModel.selectedModel) {
            Task { await viewModel.setup() }
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ViewModel {

    enum State: Equatable {
        case idle
        case downloading(Double)
        case generating
        case playing
        case error(String)
    }

    var inputText     = "Hello! Welcome to KittenTTS, a fast on-device speech synthesis engine for Apple platforms."
    var selectedVoice: KittenVoice = .bella
    var selectedModel: KittenModel = .nano {
        didSet { if oldValue != selectedModel { tts = nil; isModelCached = KittenTTS.isModelCached(selectedModel) } }
    }
    var speed: Double = 1.0
    var state: State  = .idle
    var result: KittenTTSResult?
    var isModelCached = KittenTTS.isModelCached(.nano)

    var isWorking: Bool {
        switch state {
        case .downloading, .generating, .playing: return true
        default: return false
        }
    }

    private var tts: KittenTTS?

    func setup() async {
        guard tts == nil else { return }
        do {
            state = .downloading(0)
            let config = KittenTTSConfig(model: selectedModel)
            tts = try await KittenTTS(config) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state = .downloading(progress)
                }
            }
            isModelCached = true
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func speak() async {
        guard let tts else { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        state = .playing
        do {
            result = try await tts.speak(text, voice: selectedVoice, speed: Float(speed))
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func generate() async {
        guard let tts else { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        state = .generating
        do {
            result = try await tts.generate(text, voice: selectedVoice, speed: Float(speed))
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
