import SwiftUI
import AppKit

struct MenuBarView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "laptopcomputer").font(.title2).foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 3) {
                    Text("SlapBook Pro").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Your Mac has feelings. Unfortunately.").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            HStack {
                Circle().fill(model.motionStreaming ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(model.motionStreaming ? "Experimental motion is live" : "Button previews / optional keyboard").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
            }
            Toggle("Enable Detection", isOn: $model.settings.detectionEnabled)
            Toggle("Mute", isOn: $model.settings.muted)
            Picker("Personality", selection: $model.settings.mode) {
                ForEach(model.availableModes) { mode in Text(mode.title).tag(mode) }
            }
            HStack {
                Button { model.testSound() } label: { Label("Test Sound", systemImage: "play.fill") }.buttonStyle(.borderedProminent).tint(.purple)
                Spacer()
                Text("Preview").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text("\(model.tapCount) inputs · \(model.reactionCount) reactions").font(.system(size: 10)).foregroundStyle(.secondary)
            if let message = model.statusMessage, !message.isEmpty {
                Text(message).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(3)
            }
            Divider()
            HStack {
                Button("Open SlapBook…") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }.buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless)
            }
        }.padding(20).frame(width: 315)
    }
}
