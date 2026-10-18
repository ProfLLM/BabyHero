import SwiftUI

struct InformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    BrandMark().padding(.top, 5)
                    Text("A little clarity.\nA lot of privacy.")
                        .font(.system(.largeTitle, design: .serif))
                        .foregroundStyle(Palette.ink)
                    info("Just on your iPhone", icon: "lock.shield", text: "Your data stays on your phone. All sound analysis runs live, in memory, on your iPhone. Audio and measurements are never saved or uploaded. No ads, accounts, account or usage tracking, analytics, or session history.")
                    info("You’re in control", icon: "hand.raised", text: "The microphone starts only when you tap Start listening. Stop ends capture immediately. Leaving the app pauses listening; it will not restart by itself. You can revoke access in iPhone Settings.")
                    info("What we look for", icon: "waveform", text: "Persistent high-pitched tones, roughly 8–20 kHz, within the available microphone range. Some high-pitched sounds may be easier for children to hear. Short chirps, very faint tones, broadband noise, and sounds beyond the microphone’s response can be missed.")
                    info("A guide, not a diagnosis", icon: "ear", text: "A detected tone cannot tell you whether your baby hears it or finds it uncomfortable. An empty result doesn’t prove the room is free of high-pitched sounds. This isn’t a hearing test or a calibrated sound-level meter.")
                    info("Follow the signal", icon: "figure.walk", text: "The finder compares the same tone over time. Strength can change because of reflections, your grip, microphone sensitivity, or the source itself. It doesn’t measure direction or distance. Keep the microphone uncovered and compare nearby devices one at a time.")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Further reading").font(.subheadline.weight(.semibold))
                        Link("Research on high-frequency hearing", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2803110/")!)
                        Link("Apple’s audio measurement mode", destination: URL(string: "https://developer.apple.com/documentation/avfaudio/avaudiosession/mode-swift.struct/measurement")!)
                    }.font(.footnote).tint(Palette.coral)
                    Text("BabyHero · Made for small moments of quiet.")
                        .font(.caption).foregroundStyle(Palette.secondary).padding(.bottom, 20)
                }
                .padding(26)
                .frame(maxWidth: 540, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationTitle("About BabyHero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.tint(Palette.coral)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func info(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .rounded)).foregroundStyle(Palette.ink)
            Text(text).font(.subheadline).foregroundStyle(Palette.secondary).lineSpacing(4)
        }
    }
}
