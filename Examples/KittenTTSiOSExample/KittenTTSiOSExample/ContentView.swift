import SwiftUI
import KittenTTS

struct ContentView: View {

    @State private var viewModel = ViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status banner
                StatusBanner(state: viewModel.state)

                // Input area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.inputText)
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(viewModel.isWorking)
                }

                // Model picker
                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(KittenModel.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isWorking)
                .onChange(of: viewModel.selectedModel) {
                    Task { await viewModel.resetAndSetup() }
                }

                // Phonemizer picker
                Picker("Phonemizer", selection: $viewModel.selectedPhonemizer) {
                    ForEach(PhonemizerChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isWorking)
                .onChange(of: viewModel.selectedPhonemizer) {
                    Task { await viewModel.resetAndSetup() }
                }

                // Voice picker
                Picker("Voice", selection: $viewModel.selectedVoice) {
                    ForEach(KittenVoice.allCases) { voice in
                        Text(voice.displayName).tag(voice)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isWorking)

                // Speed slider
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(String(format: "%.1f×", viewModel.speed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.speed, in: 0.5 ... 2.0, step: 0.1)
                        .disabled(viewModel.isWorking)
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        Task { await viewModel.generate() }
                    } label: {
                        Label("Generate", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("generate_button")
                    .disabled(viewModel.isWorking || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)

                    if viewModel.result != nil {
                        Button {
                            Task { await viewModel.speak() }
                        } label: {
                            Label("Play", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isWorking)
                    }
                }

                // Result card
                if let result = viewModel.result {
                    ResultCard(result: result)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("KittenTTS")
            .task { await viewModel.setup() }
        }
    }
}

// MARK: - Sub-views

private struct StatusBanner: View {
    let state: ViewModel.State

    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .downloading(let progress):
                VStack(spacing: 6) {
                    Label("Downloading model…", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                    ProgressView(value: progress)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            case .generating:
                Label("Generating speech…", systemImage: "waveform.badge.clock")
                    .font(.subheadline)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            case .playing:
                Label("Playing…", systemImage: "speaker.wave.2")
                    .font(.subheadline)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(.easeInOut, value: state == .idle)
    }
}

private struct ResultCard: View {
    let result: KittenTTSResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Generated Audio", systemImage: "checkmark.circle")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
                .accessibilityIdentifier("result_label")

            HStack {
                Label(result.voice.displayName, systemImage: "person.wave.2")
                Spacer()
                Label(String(format: "%.2fs", result.duration), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Phonemizer choice

enum PhonemizerChoice: String, CaseIterable, Identifiable {
    case ePhonemizer = "EPhonemizer"
    case builtin     = "Basic Rules"

    var id: String { rawValue }

    var displayName: String { rawValue }

    func phonemizerType() throws -> KittenPhonemizerType {
        switch self {
        case .ePhonemizer: return .builtin
        case .builtin:     return .custom(BuiltinPhonemizer())
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

    var inputText = "Hello! Welcome to KittenTTS, a fast on-device text-to-speech engine."
    var selectedVoice: KittenVoice = .bella
    var selectedModel: KittenModel = .nano
    var selectedPhonemizer: PhonemizerChoice = .ePhonemizer
    var speed: Double = 1.0
    var state: State = .idle
    var result: KittenTTSResult?

    var isWorking: Bool {
        switch state {
        case .downloading, .generating, .playing: return true
        default: return false
        }
    }

    private var tts: KittenTTS?

    // MARK: - Setup

    func setup() async {
        guard tts == nil else { return }
        do {
            state = .downloading(0)
            let config = KittenTTSConfig(
                model: selectedModel,
                phonemizer: try selectedPhonemizer.phonemizerType()
            )
            tts = try await KittenTTS(config) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.state = .downloading(progress)
                }
            }
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func resetAndSetup() async {
        tts = nil
        result = nil
        await setup()
    }

    // MARK: - Actions

    func generate() async {
        guard let tts else { return }
        state = .generating
        do {
            result = try await tts.generate(inputText, voice: selectedVoice, speed: Float(speed))
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func speak() async {
        guard let tts, let existingResult = result else { return }
        state = .playing
        do {
            result = try await tts.speak(existingResult.inputText,
                                         voice: existingResult.voice,
                                         speed: Float(speed))
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
