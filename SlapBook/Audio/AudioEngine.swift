import AVFoundation
import AudioToolbox
import Foundation

/// Separate selection state makes repetition behavior testable without an audio
/// device, and lets a library mutation discard pools containing removed URLs.
struct ReactionShuffleBag {
    private var lastByPool: [String: String] = [:]
    private var bags: [String: [String]] = [:]

    mutating func next(ids: [String], pool: String) -> String? {
        guard !ids.isEmpty else { return nil }
        var bag = bags[pool] ?? []
        if bag.isEmpty {
            bag = Array(Set(ids)).shuffled()
            if bag.count > 1, bag.last == lastByPool[pool] {
                bag.swapAt(0, bag.count - 1)
            }
        }
        let selected = bag.removeLast()
        bags[pool] = bag
        lastByPool[pool] = selected
        return selected
    }

    mutating func resetCustomPools() {
        bags = bags.filter { !$0.key.hasPrefix("custom:") }
        lastByPool = lastByPool.filter { !$0.key.hasPrefix("custom:") }
    }
}

enum ReactionAudioError: LocalizedError {
    case missingAsset(String)
    case invalidAudio(String)
    case emptyCustomPack
    case decodeFailed(String)
    case playbackUnavailable

    var errorDescription: String? {
        switch self {
        case .missingAsset(let file): "The bundled sound \(file) is missing. Rebuild the app with its Audio resources."
        case .invalidAudio(let reason): reason
        case .emptyCustomPack: "This pack has no sounds matching this rhythm. Import audio or assign a matching Single, Double, Triple, or Any rhythm."
        case .decodeFailed(let file): "Could not decode \(file). Choose a valid WAV, AIFF, CAF, MP3, or M4A audio file."
        case .playbackUnavailable: "macOS could not load its audio playback components. Relaunch SlapBook Pro and check Sound settings."
        }
    }
}

/// All playback is local. Built-ins are original synthesized character voices,
/// explicitly identified in the app and the pack's provenance manifest.
@MainActor
final class AudioEngine {
    private struct Manifest: Decodable {
        let clips: [Clip]
    }

    private struct Clip: Decodable {
        let id: String
        let mode: String
        let tapCount: Int
        let title: String
        let file: String
    }

    static let maximumImportBytes = 25 * 1024 * 1024
    static let maximumImportDuration: Double = 30
    static let maximumCustomCacheBytes = 32 * 1024 * 1024

    // Decoding and compatibility checks do not need to open any audio device.
    // Create the graph only after all required bundled resources validate.
    private lazy var engine = AVAudioEngine()
    private lazy var player = AVAudioPlayerNode()
    private lazy var pitch = AVAudioUnitTimePitch()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let bundle: Bundle
    private var configured = false
    private var clips: [Clip] = []
    private var builtInBuffers: [String: AVAudioPCMBuffer] = [:]
    private var customBuffers: [URL: AVAudioPCMBuffer] = [:]
    private var customCacheOrder: [URL] = []
    private var shuffle = ReactionShuffleBag()
    private var customPoolID: String?
    private var outputVolume: Float = 0.7
    private var muted = false

    var availableBuiltInCount: Int { builtInBuffers.count }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func prepare() throws {
        if clips.isEmpty {
            guard let url = resourceURL("sound_manifest.json") else {
                throw ReactionAudioError.missingAsset("sound_manifest.json")
            }
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
            guard !manifest.clips.isEmpty else {
                throw ReactionAudioError.missingAsset("all reaction clips")
            }
            var buffers: [String: AVAudioPCMBuffer] = [:]
            for clip in manifest.clips {
                guard let fileURL = resourceURL(clip.file) else {
                    throw ReactionAudioError.missingAsset(clip.file)
                }
                buffers[clip.id] = try decode(fileURL)
            }
            clips = manifest.clips
            builtInBuffers = buffers
        }
        if !configured {
            // AVAudioUnitTimePitch's initializer raises an Objective-C exception
            // when the system component is unavailable. Check the public
            // component registry first and surface a Swift error instead.
            var description = AudioComponentDescription(componentType: kAudioUnitType_FormatConverter,
                componentSubType: kAudioUnitSubType_NewTimePitch,
                componentManufacturer: kAudioUnitManufacturer_Apple,
                componentFlags: 0, componentFlagsMask: 0)
            guard AudioComponentFindNext(nil, &description) != nil else {
                throw ReactionAudioError.playbackUnavailable
            }
            engine.attach(player)
            engine.attach(pitch)
            do {
                if #available(macOS 27.0, *) {
                    try engine.connectNode(player, to: pitch, format: format)
                    try engine.connectNode(pitch, to: engine.mainMixerNode, format: format)
                } else {
                    engine.connect(player, to: pitch, format: format)
                    engine.connect(pitch, to: engine.mainMixerNode, format: format)
                }
                engine.prepare()
                configured = true
            } catch {
                // A later retry must start from an unattached graph. Attaching
                // these same nodes twice can raise an Objective-C exception.
                engine.detach(player)
                engine.detach(pitch)
                throw error
            }
        }
        if !engine.isRunning { try engine.start() }
    }

    /// Stops existing playback before scheduling, so reactions never stack.
    /// The tap count selects a separately authored single/double/triple clip.
    @discardableResult
    func play(mode: SoundMode, tapCount: Int, volume: Double,
              pitchVariation: Bool, customURLs: [URL]) throws -> String {
        try prepare()
        let buffer: AVAudioPCMBuffer
        let title: String
        if mode == .custom {
            guard !customURLs.isEmpty else { throw ReactionAudioError.emptyCustomPack }
            let ids = customURLs.map(\.absoluteString)
            let pool = "custom:" + ids.sorted().joined(separator: "|")
            if pool != customPoolID {
                shuffle.resetCustomPools()
                customPoolID = pool
            }
            let selected = choose(ids: ids, pool: pool)
            guard let url = customURLs.first(where: { $0.absoluteString == selected }) else {
                throw ReactionAudioError.emptyCustomPack
            }
            if let cached = customBuffers[url] {
                buffer = cached
                touchCache(url)
            } else {
                buffer = try decode(url)
                cache(buffer, at: url)
            }
            title = url.deletingPathExtension().lastPathComponent
        } else {
            let key = packKey(mode)
            let count = min(3, max(1, tapCount))
            let candidates = clips.filter { $0.mode == key && $0.tapCount == count }
            guard !candidates.isEmpty else { throw ReactionAudioError.missingAsset("\(key), \(count) taps") }
            let selected = choose(ids: candidates.map(\.id), pool: "\(key):\(count)")
            guard let clip = candidates.first(where: { $0.id == selected }),
                  let cached = builtInBuffers[selected] else {
                throw ReactionAudioError.missingAsset(selected)
            }
            buffer = cached
            title = clip.title
        }
        player.stop()
        pitch.pitch = pitchVariation ? Float.random(in: -140...140) : 0
        pitch.rate = pitchVariation ? Float.random(in: 0.96...1.04) : 1
        outputVolume = Float(min(1, max(0, volume)))
        player.volume = muted ? 0 : outputVolume
        player.scheduleBuffer(buffer)
        if #available(macOS 27.0, *) { try player.playAudio() }
        else { player.play() }
        return title
    }

    func setOutput(volume: Double, muted: Bool) {
        outputVolume = Float(min(1, max(0, volume)))
        self.muted = muted
        if configured {
            player.volume = muted ? 0 : outputVolume
            if muted { player.stop() }
        }
    }

    func stop() { if configured { player.stop() } }

    /// Decode before accepting an import. A file extension alone is not proof
    /// that a file is valid audio. Imported files are copied by the library.
    func validate(url: URL) throws {
        _ = try decode(url)
    }

    func preloadCustom(urls: [URL]) throws {
        clearCustomCache()
        // Warm only what fits. Further files decode once on first playback and
        // participate in the same 32 MiB LRU budget.
        for url in urls {
            let buffer = try decode(url)
            let cachedBytes = customBuffers.values.reduce(0) { $0 + memoryBytes($1) }
            guard cachedBytes + memoryBytes(buffer) <= Self.maximumCustomCacheBytes else { break }
            cache(buffer, at: url)
        }
    }

    /// Imported file contents may change only through the library UI. Call this
    /// after removal to bound memory and avoid retaining deleted audio buffers.
    func clearCustomCache() {
        customBuffers.removeAll()
        customCacheOrder.removeAll()
        shuffle.resetCustomPools()
        customPoolID = nil
    }

    private func packKey(_ mode: SoundMode) -> String {
        switch mode {
        case .shy: "shy"
        case .anime: "anime"
        case .drama: "drama"
        case .chaos: "chaos"
        case .secret: "secret"
        case .dramaticMoans: "dramaticMoans"
        case .custom: "custom"
        }
    }

    private func resourceURL(_ file: String) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        for directory: String? in [nil, "Audio/Resources", "Resources"] {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return url
            }
        }
        return nil
    }

    private func choose(ids: [String], pool: String) -> String {
        // Every caller checks its candidate list before choosing.
        shuffle.next(ids: ids, pool: pool)!
    }

    private func memoryBytes(_ buffer: AVAudioPCMBuffer) -> Int {
        Int(buffer.frameCapacity) * Int(buffer.format.channelCount) * MemoryLayout<Float>.size
    }

    private func touchCache(_ url: URL) {
        customCacheOrder.removeAll { $0 == url }
        customCacheOrder.append(url)
    }

    private func cache(_ buffer: AVAudioPCMBuffer, at url: URL) {
        let cost = memoryBytes(buffer)
        guard cost <= Self.maximumCustomCacheBytes else { return }
        customBuffers.removeValue(forKey: url)
        customCacheOrder.removeAll { $0 == url }
        while customBuffers.values.reduce(0, { $0 + memoryBytes($1) }) + cost > Self.maximumCustomCacheBytes,
              let oldest = customCacheOrder.first {
            customBuffers.removeValue(forKey: oldest)
            customCacheOrder.removeFirst()
        }
        customBuffers[url] = buffer
        customCacheOrder.append(url)
    }

    private func decode(_ url: URL) throws -> AVAudioPCMBuffer {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard bytes > 0, bytes <= Self.maximumImportBytes else {
            throw ReactionAudioError.invalidAudio("Choose a nonempty audio file smaller than 25 MB.")
        }
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false) }
        catch { throw ReactionAudioError.decodeFailed(url.lastPathComponent) }
        let inputFormat = file.processingFormat
        let duration = Double(file.length) / inputFormat.sampleRate
        guard duration.isFinite, duration > 0, duration <= Self.maximumImportDuration,
              inputFormat.channelCount > 0, inputFormat.channelCount <= 8 else {
            throw ReactionAudioError.invalidAudio("Choose audio lasting at most 30 seconds, with 1–8 channels.")
        }
        if inputFormat == format {
            guard let input = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                               frameCapacity: AVAudioFrameCount(file.length)) else {
                throw ReactionAudioError.decodeFailed(url.lastPathComponent)
            }
            try file.read(into: input)
            return input
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: format),
              let chunk = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 8192),
              let output = AVAudioPCMBuffer(pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(ceil(duration * format.sampleRate)) + 1024) else {
            throw ReactionAudioError.decodeFailed(url.lastPathComponent)
        }
        var readError: (any Error)?
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { requested, inputStatus in
            guard file.framePosition < file.length else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            do {
                try file.read(into: chunk, frameCount: min(requested, chunk.frameCapacity))
                inputStatus.pointee = chunk.frameLength > 0 ? .haveData : .endOfStream
                return chunk.frameLength > 0 ? chunk : nil
            } catch {
                readError = error
                inputStatus.pointee = .noDataNow
                return nil
            }
        }
        if let readError { throw readError }
        if let conversionError { throw conversionError }
        guard status != .error, output.frameLength > 0,
              abs(Double(output.frameLength) / format.sampleRate - duration) < 0.1 else {
            throw ReactionAudioError.decodeFailed(url.lastPathComponent)
        }
        return output
    }
}
