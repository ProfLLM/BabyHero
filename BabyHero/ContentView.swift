import BabyHeroCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showingInfo = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(spacing: 26) {
                    header
                    if model.isPreview {
                        Text("DESIGN PREVIEW · SAMPLE DATA")
                            .font(.caption2.weight(.bold)).tracking(1)
                            .foregroundStyle(Palette.coral)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Palette.softPeach, in: Capsule())
                            .accessibilityIdentifier("previewLabel")
                    }
                    if let tone = model.selectedTone {
                        FinderView(tone: tone, reading: model.snapshot?.tracking,
                                   elapsed: model.snapshot?.elapsed ?? 0, back: model.backToSounds)
                    } else {
                        ListeningView(model: model)
                    }
                    if model.snapshot?.isClipping == true && model.isListening {
                        Label("The microphone is overloaded. Move farther away for a clearer reading.", systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(Palette.coral)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 26)
                .padding(.top, 14)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .id("screenTop")
            }
            .background(Palette.background)
            .safeAreaInset(edge: .bottom, spacing: 0) { controls }
            .sheet(isPresented: $showingInfo) { InformationView() }
            .alert(item: $model.issue) { issue in
                if issue.offersSettings {
                    return Alert(title: Text(issue.title), message: Text(issue.message),
                                 primaryButton: .default(Text("Open Settings")) {
                                     if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                                 }, secondaryButton: .cancel(Text("Not now")))
                }
                return Alert(title: Text(issue.title), message: Text(issue.message), dismissButton: .default(Text("OK")))
            }
            .onChange(of: model.selectedTone?.id) { _, _ in
                scroll.scrollTo("screenTop", anchor: .top)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            BrandMark()
            Text("BabyHero")
                .font(.system(size: 27, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showingInfo = true } label: {
                Image(systemName: "info")
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 44, height: 44)
                    .background(Palette.card, in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
            }
            .accessibilityLabel("About BabyHero and your privacy")
            .accessibilityIdentifier("informationButton")
        }
    }

    private var controls: some View {
        VStack(spacing: 13) {
            PrimaryButton(title: actionTitle,
                          icon: model.isListening ? "stop.fill" : "waveform",
                          isBusy: model.state == .requesting) {
                if model.isListening { model.stop() } else { model.start() }
            }
            if !typeSize.isAccessibilitySize {
                Label(model.isListening ? "Listening on this iPhone only" : "On your iPhone. Just between you.", systemImage: "lock.shield")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.background)
    }

    private var actionTitle: String {
        if typeSize.isAccessibilitySize {
            return model.isListening ? "Stop" : model.state == .paused ? "Restart" : "Listen"
        }
        return model.isListening ? "Stop listening" : model.state == .paused ? "Start again" : "Start listening"
    }
}

private struct ListeningView: View {
    @ObservedObject var model: AppModel
    private var tones: [Tone] { model.isListening ? model.snapshot?.tones ?? [] : [] }
    private var foundTone: Bool { !tones.isEmpty }
    private var hasSettled: Bool { (model.snapshot?.elapsed ?? 0) > 3 }

    var body: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: model.isListening ? "A moment of listening" : "A little help for little ears")
                Text(model.isListening ? "Let’s find a\nlittle quiet." : "Little ears.\nA quieter world.")
                    .font(.system(.largeTitle, design: .serif, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ListeningOrb(isListening: model.isListening, detected: foundTone, size: model.isListening ? 170 : 218)
                .padding(.top, 1)

            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    if model.isListening {
                        Circle().fill(foundTone ? Palette.coral : Palette.sage).frame(width: 6, height: 6)
                    }
                    Text(statusTitle)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Palette.ink)
                }
                Text(statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("listeningStatus")

            if foundTone {
                toneList
            } else if model.isListening {
                listeningHint
            } else {
                introduction
            }
        }
    }

    private var statusTitle: String {
        if model.state == .paused { return "A little pause" }
        if !model.isListening { return "Hear the little things." }
        if foundTone { return "High-pitched tone detected" }
        return hasSettled ? "No clear tone detected" : "Listening for high-pitched sounds"
    }

    private var statusDetail: String {
        if let message = model.pauseMessage { return message }
        if !model.isListening { return "Find high-pitched sounds you may miss,\nand follow the signal to their source." }
        if foundTone { return "Choose a tone below to follow its signal." }
        return hasSettled ? "Nothing distinct is showing up right now.\nTry another spot in the room." : "Give it a moment. Keep the microphone clear\nand let the room do the talking."
    }

    private var introduction: some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkle")
                    .font(.title3).foregroundStyle(Palette.coral)
                    .padding(10).background(Palette.softPeach, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Their ears hear differently.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Some high-pitched sounds may be easier for children to hear. A small whine is worth a closer look.")
                        .font(.footnote).foregroundStyle(Palette.secondary).lineSpacing(3)
                }
            }
        }
    }

    private var listeningHint: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("A slow walk can help.", systemImage: "figure.walk")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Try near chargers, lamps, and other electronics. Not finding a tone doesn’t mean there are no high-pitched sounds.")
                    .font(.footnote).foregroundStyle(Palette.secondary).lineSpacing(3)
                if let upper = model.snapshot?.upperFrequency {
                    Text("Looking from 8 to \(upper / 1000, specifier: "%.1f") kHz · microphone response varies")
                        .font(.caption2).foregroundStyle(Palette.secondary)
                }
            }
        }
    }

    private var toneList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Sounds to explore")
                Spacer()
                Text("Strongest first").font(.caption).foregroundStyle(Palette.secondary)
            }
            ForEach(tones) { tone in
                Button { model.select(tone) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "waveform")
                            .font(.title3).foregroundStyle(Palette.coral)
                            .frame(width: 43, height: 48)
                            .background(Palette.softPeach, in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(tone.frequency / 1000, specifier: "%.2f") kHz")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(Palette.ink).monospacedDigit()
                            Text("Persistent high tone").font(.caption).foregroundStyle(Palette.secondary)
                        }
                        Spacer(minLength: 2)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Palette.coral)
                    }
                    .padding(15)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 21))
                    .overlay(RoundedRectangle(cornerRadius: 21).stroke(Palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tone.frequency / 1000, specifier: "%.2f") kilohertz, persistent high tone")
                .accessibilityHint("Find this sound by following its signal strength")
                .accessibilityIdentifier("tone-\(tone.id)")
            }
            Text("Tap a tone to find this sound.")
                .font(.caption).foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity).padding(.top, 2)
        }
    }
}

#Preview("Welcome") { ContentView(model: AppModel(preview: "idle")) }
#Preview("Listening") { ContentView(model: AppModel(preview: "listening")) }
#Preview("Finding a tone") { ContentView(model: AppModel(preview: "finder")) }
#Preview("No clear tone") { ContentView(model: AppModel(preview: "quiet")) }
