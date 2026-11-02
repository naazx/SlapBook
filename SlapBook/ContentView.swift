import SwiftUI

private enum Destination: String, CaseIterable, Identifiable {
    case playground = "Playground", library = "Sound Library", detection = "Detection", settings = "Settings & About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .playground: "sparkles"
        case .library: "waveform"
        case .detection: "hand.tap"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var destination: Destination = .playground
    @State private var inputPulse = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let purple = Color(red: 0.48, green: 0.35, blue: 0.88)
    private var canvas: Color {
        colorScheme == .dark ? Color(red: 0.105, green: 0.105, blue: 0.13) : Color(red: 0.975, green: 0.973, blue: 0.985)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider().opacity(0.5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch destination {
                        case .playground: playground
                        case .library: library
                        case .detection: detection
                        case .settings: settings
                        }
                        if let message = model.statusMessage, !message.isEmpty {
                            Label(message, systemImage: "info.circle.fill")
                                .font(.callout).foregroundStyle(.secondary)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                                .accessibilityIdentifier("statusMessage")
                        }
                    }
                    .padding(28).frame(maxWidth: 940).frame(maxWidth: .infinity)
                }
            }
            .background(canvas)
        }
        .frame(minWidth: 920, minHeight: 700).tint(purple)
        .onChange(of: model.tapCount) { oldCount, newCount in
            guard newCount > oldCount else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { inputPulse = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { inputPulse = false }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(purple.gradient, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("SlapBook").font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("PRO / FEELINGS INCLUDED").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                }
            }.padding(.top, 16)
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR MAC, BUT DRAMATIC").font(.system(size: 9, weight: .semibold)).tracking(1.1)
                    .foregroundStyle(.tertiary).padding(.horizontal, 12).padding(.bottom, 7)
                ForEach(Destination.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { destination = item }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.symbol).frame(width: 19)
                            Text(item.rawValue).font(.system(size: 13, weight: destination == item ? .semibold : .medium))
                            Spacer(minLength: 0)
                            if destination == item { Circle().fill(purple).frame(width: 5, height: 5) }
                        }
                        .foregroundStyle(destination == item ? purple : .primary.opacity(0.72))
                        .padding(.horizontal, 12).padding(.vertical, 12)
                        .background(destination == item ? purple.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("nav_\(item.id)")
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle().fill(model.motionStreaming ? Color.green : Color.orange).frame(width: 6, height: 6)
                    Text(model.motionStreaming ? "Motion reports live" : "Button previews available").font(.system(size: 11, weight: .medium))
                }
                Text("Your Mac has feelings.\nUnfortunately.")
                    .font(.system(size: 12, design: .rounded)).foregroundStyle(.secondary).lineSpacing(3)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            Text("GENTLE TAPS. BIG FEELINGS.").font(.system(size: 8, weight: .medium)).tracking(1.2)
                .foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.bottom, 4)
        }
        .padding(.horizontal, 16).padding(.bottom, 16).frame(width: 207).background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(destination.rawValue).font(.system(size: 22, weight: .bold, design: .rounded))
                Text(headerSubtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.settings.muted.toggle() } label: {
                Label(model.settings.muted ? "Muted" : "Sound on", systemImage: model.settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.background, in: Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("muteButton")
        }.padding(.horizontal, 28).padding(.vertical, 23)
    }

    private var headerSubtitle: String {
        switch destination {
        case .playground: "A little tap. An unreasonable reaction."
        case .library: "Find your Mac’s very questionable personality."
        case .detection: "Real inputs. Honest compatibility. Gentle hands."
        case .settings: "Fine-tune the feelings."
        }
    }

    private var playground: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 17) {
                    Text("EMOTIONALLY AVAILABLE").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(purple)
                    Text("Meet your\noverreactor.")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).tracking(-1.2).lineSpacing(-1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Tiny input. Main character energy.\nPick a voice and give it a try.")
                        .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
                    Button { model.testSound() } label: {
                        Label("Test Sound", systemImage: "play.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 13)
                            .background(Color(red: 0.91, green: 0.40, blue: 0.22).gradient, in: RoundedRectangle(cornerRadius: 11))
                    }.buttonStyle(.plain).accessibilityIdentifier("testSoundButton")
                    Text("Works without hardware detection").font(.system(size: 10)).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 0) {
                    Text(model.lastReaction.isEmpty ? "I’m sensitive, okay?" : model.lastReaction)
                        .font(.system(size: 12, weight: .medium, design: .rounded)).multilineTextAlignment(.center).lineLimit(2)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(purple.opacity(0.12)))
                        .padding(.bottom, 8).accessibilityIdentifier("lastReaction")
                    MascotView(reactionID: model.reactionID, isMuted: model.settings.muted).frame(width: 252, height: 202)
                    HStack(spacing: 5) {
                        Circle().fill(inputPulse ? Color.orange : model.settings.detectionEnabled ? Color.green : Color.secondary)
                            .frame(width: inputPulse ? 8 : 5, height: inputPulse ? 8 : 5)
                        Text(inputPulse ? "Input received!" : model.settings.detectionEnabled ? "Input reactions enabled" : "Taking a feelings break")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    }
                }.frame(width: 270)
            }
            .padding(28).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [purple.opacity(0.09), purple.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(purple.opacity(0.10)))
            HStack(spacing: 14) {
                statCard("Inputs received", value: "\(model.tapCount)", symbol: "hand.tap", color: purple)
                statCard("Reactions played", value: "\(model.reactionCount)", symbol: "waveform", color: .orange)
                statCard("Current personality", value: model.settings.mode.title, symbol: model.settings.mode.symbol, color: .pink)
            }
            HStack(alignment: .top, spacing: 18) {
                card(title: "The mood", symbol: "theatermasks") {
                    Picker("Sound Mode", selection: $model.settings.mode) {
                        ForEach(SoundMode.allCases.filter { $0 != .secret || model.secretUnlocked }) { mode in Text(mode.title).tag(mode) }
                    }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    Text(model.settings.mode.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    sliderRow("Volume", value: $model.settings.volume, range: 0...1, text: "\(Int(model.settings.volume * 100))%", symbol: "speaker.wave.2")
                }
                card(title: "Try a little rhythm", symbol: "hand.tap") {
                    Text("Preview a single, double, or triple reaction. Test buttons bypass detection and cooldown.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 7) {
                        ForEach(1...3, id: \.self) { count in
                            Button { model.testSound(tapCount: count) } label: {
                                VStack(spacing: 5) {
                                    Text(String(repeating: "•", count: count)).font(.system(size: 18, weight: .bold)).tracking(2)
                                    Text(["Single", "Double", "Triple"][count - 1]).font(.system(size: 10))
                                }.frame(maxWidth: .infinity).padding(.vertical, 9)
                            }.buttonStyle(.bordered).accessibilityIdentifier("testTap\(count)")
                        }
                    }
                    Button("Send an input") { model.triggerManualTap() }.font(.system(size: 11)).buttonStyle(.link).accessibilityIdentifier("manualTapButton")
                }
            }
            Label("Built-in voices are original synthesized characters. Chassis sensing is experimental. Test Sound works independently of detection; mute and volume still apply.", systemImage: "info.circle")
                .font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                sectionHeading("Choose your chaos", subtitle: "Original synthesized vocal characters, ready to react.")
                Spacer()
                Button { model.testSound() } label: { Label("Test Sound", systemImage: "play.fill") }.buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                ForEach(SoundMode.allCases.filter { $0 != .custom }) { mode in modeCard(mode) }
            }
            card(title: "Your sound packs", symbol: "square.stack.3d.up") {
                Text("Import audio you own or have permission to use. Files are copied into the app’s library for reliable playback.").font(.callout).foregroundStyle(.secondary)
                HStack {
                    TextField("New pack name", text: $model.customPackName).textFieldStyle(.roundedBorder)
                    Button { model.importSounds() } label: { Label("Import Sounds…", systemImage: "plus") }.buttonStyle(.borderedProminent).accessibilityIdentifier("importSoundsButton")
                }
                if model.customSounds.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.plus").font(.system(size: 28)).foregroundStyle(.tertiary)
                        Text("A very personal kind of ridiculous.").font(.system(size: 12, weight: .medium))
                        Text("WAV, AIFF, M4A, MP3 and other AVFoundation-readable audio").font(.system(size: 10)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 25)
                } else {
                    Picker("Active pack", selection: $model.selectedCustomPack) {
                        ForEach(model.customPacks, id: \.self) { pack in Text(pack).tag(pack) }
                    }
                    Button("Use Custom Mode") { model.settings.mode = .custom }
                    ForEach(model.customSounds.filter { model.selectedCustomPack == "All sounds" || $0.pack == model.selectedCustomPack }) { sound in
                        HStack {
                            Image(systemName: "waveform").foregroundStyle(purple).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sound.name).font(.system(size: 12, weight: .medium))
                                Text(sound.pack).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("Rhythm", selection: Binding(get: { sound.tapCount }, set: { model.setSoundTapCount(sound, count: $0) })) {
                                Text("Any rhythm").tag(0)
                                Text("Single").tag(1)
                                Text("Double").tag(2)
                                Text("Triple").tag(3)
                            }.labelsHidden().frame(width: 105)
                            Button(role: .destructive) { model.removeSound(sound) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Remove \(sound.name)")
                                .accessibilityIdentifier("remove_\(sound.name)")
                        }.padding(.vertical, 7)
                        Divider()
                    }
                }
            }
            Text("No film clips, celebrity voices, or unlicensed meme recordings are bundled. Secret Mode contains original surprises.").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var detection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("A tap of reality", subtitle: "Your Mac’s actual capabilities, without the make-believe.")
            card(title: model.hardware.summary, symbol: "laptopcomputer") {
                Text(model.hardware.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                Text("Left and right palm-rest location cannot be reliably determined, so all inputs are generic. Only use gentle taps. Never increase force to make detection work.").font(.callout).foregroundStyle(.secondary)
                Button("Check Hardware Again", action: model.refreshHardware)
            }
            card(title: "Input sources", symbol: "hand.tap") {
                Toggle("Enable Detection", isOn: $model.settings.detectionEnabled).accessibilityIdentifier("enableDetectionToggle")
                Text("Controls real input reactions, including the global shortcut. Test Sound remains available.").font(.system(size: 11)).foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                Toggle("Global keyboard shortcut", isOn: $model.settings.shortcutEnabled)
                HStack {
                    Text("Option + Command + S").font(.callout)
                    Spacer()
                    Text("⌥⌘S").font(.system(size: 13, weight: .medium, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 5).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                Text(model.shortcutStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                Toggle("Experimental chassis motion", isOn: $model.settings.experimentalMotionEnabled).disabled(!model.hardware.sensorPresent)
                Label(model.motionStatus, systemImage: model.motionStreaming ? "dot.radiowaves.left.and.right" : "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(model.motionStreaming ? Color.green : Color.orange)
                Text("Uses an undocumented Apple SPU report format through IOKit HID. Sensor presence does not guarantee readable data or accurate taps. No administrator helper is installed.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            card(title: "A gentle touch", symbol: "slider.horizontal.3") {
                sliderRow("Sensitivity", value: $model.settings.sensitivity, range: 0...1, text: model.settings.sensitivity < 0.35 ? "Low" : model.settings.sensitivity > 0.7 ? "High" : "Balanced", symbol: "hand.point.up")
                Text("Applies only to experimental motion detection. Higher sensitivity responds to smaller changes and may pick up typing or desk movement.").font(.system(size: 11)).foregroundStyle(.secondary)
                Divider().padding(.vertical, 5)
                sliderRow("Cooldown", value: $model.settings.cooldown, range: 0.2...3, text: String(format: "%.1f s", model.settings.cooldown), symbol: "timer")
                Toggle("Recognize double and triple inputs", isOn: $model.settings.multiTapEnabled)
                Text("Rhythm recognition adds a short grouping delay. Turn it off for the fastest single reactions. Debouncing filters repeated motion reports.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Label(model.lastInput, systemImage: "clock").font(.system(size: 11)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("lastInput")
                Spacer()
                Button("Send an input") { model.triggerManualTap() }.buttonStyle(.bordered)
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Small app. Big personality.", subtitle: "Make room for a tiny bit of nonsense.")
            card(title: "Sound & playback", symbol: "speaker.wave.2") {
                Toggle("Mute all reactions", isOn: $model.settings.muted)
                sliderRow("Volume", value: $model.settings.volume, range: 0...1, text: "\(Int(model.settings.volume * 100))%", symbol: "speaker.wave.2")
                Toggle("Random pitch & playback variation", isOn: $model.settings.pitchVariation)
                Text("A small amount of variation keeps the drama fresh. Reactions avoid immediate repeats.").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Button("Test Sound") { model.testSound() }
                    Button("Stop Playback", action: model.stopPlayback)
                }
            }
            card(title: "At home in your menu bar", symbol: "menubar.rectangle") {
                Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                Text(model.loginStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Close this window to keep SlapBook in your menu bar. Quit from the menu bar when your Mac needs emotional rest.").font(.callout).foregroundStyle(.secondary)
            }
            card(title: "The feelings department", symbol: "heart") {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SlapBook Pro").font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Your Mac has feelings. Unfortunately.").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "heart.fill").font(.system(size: 32)).foregroundStyle(purple.opacity(0.7))
                }
                Divider().padding(.vertical, 5)
                Text("Native SwiftUI · Local audio · No account · No microphone recording").font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Counts include keyboard and button inputs; test sounds do not increase the input counter. No left/right statistics are invented.").font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Built-in audio: original synthesized character voices. See docs/AUDIO.md in the project for provenance and generation details.").font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Reset Statistics", action: model.resetStatistics)
            }
        }
    }

    private func modeCard(_ mode: SoundMode) -> some View {
        let locked = mode == .secret && !model.secretUnlocked
        let selected = model.settings.mode == mode
        return Button {
            if locked { model.unlockSecret() } else { model.settings.mode = mode }
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: locked ? "lock.fill" : mode.symbol).font(.system(size: 19)).foregroundStyle(selected ? .white : purple)
                    .frame(width: 43, height: 43).background(selected ? purple : purple.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(mode.title).font(.system(size: 13, weight: .semibold))
                        Spacer(minLength: 0)
                        if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(purple) }
                    }
                    Text(locked ? "A little surprise. Click to unlock." : mode.subtitle)
                        .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.leading).lineLimit(3)
                }
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 77, alignment: .topLeading)
            .background(selected ? purple.opacity(0.065) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? purple.opacity(0.5) : purple.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityIdentifier("mode_\(mode.rawValue)")
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func statCard(_ title: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(color).frame(width: 34, height: 38).background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: value.count > 10 ? 13 : 21, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.04)))
    }

    private func card<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold))
            content()
        }
        .padding(19).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.05)))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 11))
                Spacer()
                Text(text).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range).labelsHidden().accessibilityLabel(title)
        }
    }
}
