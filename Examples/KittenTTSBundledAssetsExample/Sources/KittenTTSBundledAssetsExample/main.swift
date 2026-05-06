import Foundation
import KittenTTS

@main
enum BundledAssetsExample {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            if options.showHelp {
                printHelp()
                return
            }

            try await run(options: options)
        } catch {
            print("Error: \(error.localizedDescription)")
            print("")
            printHelp()
            Foundation.exit(1)
        }
    }

    private static func run(options: Options) async throws {
        let assetsURL = options.assetsURL
        let manifestURL = assetsURL.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            print("No bundled KittenTTS manifest found at:")
            print("  \(manifestURL.path)")
            print("")
            print("Create assets with:")
            print("  npx @kittentts/react-native bundle-assets --models nano-int8 --out assets/kittentts")
            print("")
            print("Then run:")
            print("  swift run KittenTTSBundledAssetsExample --assets assets/kittentts --generate")
            return
        }

        let manifest = try KittenTTSBundledAssets.loadManifest(from: manifestURL)
        let selectedModel = options.model ?? manifest.defaultModel
        let config = try KittenTTSBundledAssets.config(
            from: manifest,
            baseURL: assetsURL,
            model: selectedModel,
            defaultVoice: options.voice,
            speed: options.speed
        )

        print("Loaded manifest: \(manifestURL.path)")
        print("Available models: \(manifest.availableModels.map(\.displayName).joined(separator: ", "))")
        print("Selected model: \(selectedModel.displayName)")

        if let modelFiles = config.modelFiles {
            print("ONNX: \(modelFiles.onnxURL.path)")
            print("Voices: \(modelFiles.voicesURL.path)")
        }

        guard KittenTTS.isModelCached(for: config) else {
            print("")
            print("Manifest is valid, but the selected model files are missing.")
            print("Regenerate or copy the bundled assets before using --generate.")
            return
        }

        guard options.generate else {
            print("")
            print("Bundled assets are ready. Add --generate to synthesize a sample WAV.")
            return
        }

        print("")
        print("Generating bundled-output.wav...")
        let tts = try await KittenTTS(config)
        let result = try await tts.generate(options.text, voice: options.voice, speed: options.speed)
        let outputURL = URL(fileURLWithPath: "bundled-output.wav")
        try result.writeWAV(to: outputURL)
        print("Wrote \(outputURL.path)")
    }

    private static func printHelp() {
        print("""
        Usage:
          swift run KittenTTSBundledAssetsExample [options]

        Options:
          --assets <dir>     Directory containing manifest.json. Defaults to assets/kittentts.
          --model <name>     nano, nano-int8, micro, mini, or full KittenTTS model id.
          --voice <name>     bella, jasper, luna, bruno, rosie, hugo, kiki, or leo. Defaults to bella.
          --speed <value>    Speed from 0.5 to 2.0. Defaults to 1.0.
          --text <text>      Text to synthesize when --generate is passed.
          --generate         Create KittenTTS and write bundled-output.wav.
          --help             Show this help.
        """)
    }
}

private struct Options {
    var assetsURL = URL(fileURLWithPath: "assets/kittentts", isDirectory: true)
    var model: KittenModel?
    var voice: KittenVoice = .bella
    var speed: Float = 1.0
    var text = "Hello from KittenTTS bundled offline assets."
    var generate = false
    var showHelp = false

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--assets":
                assetsURL = URL(fileURLWithPath: try Self.value(after: argument, in: arguments, at: &index), isDirectory: true)
            case "--model":
                model = try Self.parseModel(try Self.value(after: argument, in: arguments, at: &index))
            case "--voice":
                voice = try Self.parseVoice(try Self.value(after: argument, in: arguments, at: &index))
            case "--speed":
                let rawSpeed = try Self.value(after: argument, in: arguments, at: &index)
                guard let parsed = Float(rawSpeed) else {
                    throw OptionError.invalidValue(argument, rawSpeed)
                }
                speed = min(max(parsed, 0.5), 2.0)
            case "--text":
                text = try Self.value(after: argument, in: arguments, at: &index)
            case "--generate":
                generate = true
            case "--help", "-h":
                showHelp = true
            default:
                throw OptionError.unknown(argument)
            }
            index += 1
        }
    }

    private static func value(after option: String, in arguments: [String], at index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw OptionError.missingValue(option)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func parseModel(_ value: String) throws -> KittenModel {
        let aliases: [String: KittenModel] = [
            "nano": .nano,
            "nano-fp32": .nano,
            "nano-int8": .nanoInt8,
            "micro": .micro,
            "mini": .mini,
        ]
        if let model = aliases[value] ?? KittenModel(rawValue: value) {
            return model
        }
        throw OptionError.invalidValue("--model", value)
    }

    private static func parseVoice(_ value: String) throws -> KittenVoice {
        guard let voice = KittenVoice(rawValue: value) else {
            throw OptionError.invalidValue("--voice", value)
        }
        return voice
    }
}

private enum OptionError: LocalizedError {
    case unknown(String)
    case missingValue(String)
    case invalidValue(String, String)

    var errorDescription: String? {
        switch self {
        case .unknown(let option):
            return "Unknown option \(option)"
        case .missingValue(let option):
            return "Missing value for \(option)"
        case .invalidValue(let option, let value):
            return "Invalid value for \(option): \(value)"
        }
    }
}
