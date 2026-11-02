import SwiftUI

struct SoundCreditsView: View {
    @Environment(\.dismiss) private var dismiss

    private let credits: [(name: String, url: String)] = [
        ("marythewitch — Ah! sound female", "https://freesound.org/people/marythewitch/sounds/536839/"),
        ("Airlane1979 — Short Oh!", "https://freesound.org/people/Airlane1979/sounds/798372/"),
        ("iokera — gasp.wav", "https://freesound.org/people/iokera/sounds/414213/"),
        ("Reitanna — gasp HOH!.wav", "https://freesound.org/people/Reitanna/sounds/242606/"),
        ("wjtaylor — sigh", "https://freesound.org/people/wjtaylor/sounds/265249/")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("The voices behind the drama", systemImage: "waveform")
                .font(.title2.bold())
            Text("Dramatic Moans contains edited human recordings from Freesound, dedicated to the public domain under CC0 1.0. Clips are trimmed, normalized, and arranged into reaction patterns.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(credits, id: \.url) { credit in
                if let url = URL(string: credit.url) { Link(credit.name, destination: url) }
            }
            Divider()
            Text("The other modes contain original synthesized character voices, also released under CC0. No celebrity voices, film clips, or unlicensed meme recordings are included.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Link("CC0 1.0 dedication", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(26).frame(width: 510)
    }
}
