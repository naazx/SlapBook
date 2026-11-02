import AVFoundation
import Foundation
import Testing
@testable import SlapBook

@MainActor
struct AudioTests {
    private struct Manifest: Decodable {
        struct Clip: Decodable {
            let file: String
            let mode: String
            let tapCount: Int
        }
        let clips: [Clip]
    }

    private func resource(_ name: String, extension ext: String) throws -> URL {
        for directory: String? in [nil, "Audio/Resources", "Resources"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return url
            }
        }
        throw ReactionAudioError.missingAsset(name + "." + ext)
    }

    @Test func bundledAudioIsCompleteDecodableAndNotClipped() throws {
        let manifest = try JSONDecoder().decode(Manifest.self,
            from: Data(contentsOf: resource("sound_manifest", extension: "json")))
        #expect(manifest.clips.count == 36)
        for mode in ["shy", "anime", "drama", "chaos", "secret", "dramaticMoans"] {
            for tapCount in 1...3 {
                #expect(manifest.clips.filter { $0.mode == mode && $0.tapCount == tapCount }.count >= 2)
            }
        }
        for clip in manifest.clips {
            let filename = clip.file as NSString
            let url = try resource(filename.deletingPathExtension, extension: filename.pathExtension)
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            #expect(file.processingFormat.sampleRate == 44_100)
            #expect(file.processingFormat.channelCount == 1)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                      frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            let channel = try #require(buffer.floatChannelData?[0])
            let samples = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
            let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
            #expect(peak > 0.70 && peak < 0.80)
            #expect(abs(samples[0]) < 0.001)
            #expect(abs(samples[samples.count - 1]) < 0.001)
        }
    }

    @Test func corruptImportsFailExplicitly() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data("not an audio file".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: (any Error).self) { try AudioEngine().validate(url: url) }
    }

    @Test func stereoImportsAtAnotherRateCanDecode() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800))
        buffer.frameLength = 4800
        for channel in 0..<2 {
            for frame in 0..<4800 {
                buffer.floatChannelData![channel][frame] = sin(Float(frame) * 0.06) * 0.2
            }
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        try AudioEngine().validate(url: url)
    }

    @Test func shuffleExhaustsPoolAndDoesNotRepeatAcrossRefills() throws {
        var bag = ReactionShuffleBag()
        let candidates = ["aaah", "oooh", "gasp"]
        var previous: String?
        for _ in 0..<40 {
            var cycle: [String] = []
            for _ in candidates {
                let candidate = bag.next(ids: candidates, pool: "drama:1")
                let next = try #require(candidate)
                #expect(next != previous)
                cycle.append(next)
                previous = next
            }
            #expect(Set(cycle) == Set(candidates))
        }
        let empty = bag.next(ids: [], pool: "empty")
        let single = bag.next(ids: ["only"], pool: "single")
        let singleAgain = bag.next(ids: ["only"], pool: "single")
        #expect(empty == nil)
        #expect(single == "only")
        #expect(singleAgain == "only")
    }

    @Test func libraryChangesDiscardCustomShufflePools() {
        var bag = ReactionShuffleBag()
        _ = bag.next(ids: ["old-a", "old-b"], pool: "custom:library")
        bag.resetCustomPools()
        let replacement = bag.next(ids: ["new"], pool: "custom:library")
        #expect(replacement == "new")
    }

    @Test func missingBundledAudioReportsAnErrorInsteadOfSubstituting() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bundle")
        let contents = directory.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try PropertyListSerialization.data(fromPropertyList:
            ["CFBundleIdentifier": "com.slapbook.tests.empty", "CFBundlePackageType": "BNDL"],
            format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: directory))
        do {
            try AudioEngine(bundle: bundle).prepare()
            Issue.record("A missing sound pack must fail explicitly.")
        } catch ReactionAudioError.missingAsset(let filename) {
            #expect(filename == "sound_manifest.json")
        } catch {
            Issue.record("Expected a missing-resource error, received \(error).")
        }
    }
}
