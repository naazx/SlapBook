import Foundation

enum SoundMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case shy, anime, drama, chaos, dramaticMoans, secret, custom

    var id: String { rawValue }
    var title: String {
        switch self {
        case .shy: "Shy Mode"
        case .anime: "Anime Mode"
        case .drama: "Drama Queen"
        case .chaos: "Chaos Mode"
        case .dramaticMoans: "Dramatic Moans"
        case .secret: "Secret Mode"
        case .custom: "Custom Sounds"
        }
    }
    var subtitle: String {
        switch self {
        case .shy: "Tiny squeaks. Very big feelings."
        case .anime: "A season finale in every tap."
        case .drama: "An Oscar-worthy overreaction."
        case .chaos: "Absolutely no emotional stability."
        case .dramaticMoans: "Real voices. Theatrical ahs, ohs & sighs."
        case .secret: "Your Mac's extremely silly alter ego."
        case .custom: "Your sounds. Your questionable decisions."
        }
    }
    var symbol: String {
        switch self {
        case .shy: "face.smiling"
        case .anime: "sparkles"
        case .drama: "theatermasks"
        case .chaos: "bolt.fill"
        case .dramaticMoans: "waveform"
        case .secret: "lock.open"
        case .custom: "music.note.list"
        }
    }
}

struct CustomSound: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var pack: String
    /// 0 matches every gesture; 1, 2, 3 match a specific tap count.
    var tapCount: Int
    var filename: String

    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "SlapBookPro/CustomSounds", directoryHint: .isDirectory)
    }
    var url: URL { Self.directory.appendingPathComponent(filename) }
}
