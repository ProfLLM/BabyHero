import SwiftUI

enum Palette {
    static let background = Color(hex: 0xFAF6EF)
    static let ink = Color(hex: 0x352F2B)
    static let secondary = Color(hex: 0x756A60)
    static let coral = Color(hex: 0x9F4D36)
    static let peach = Color(hex: 0xF1D7C6)
    static let softPeach = Color(hex: 0xF5E9DE)
    static let sage = Color(hex: 0x52654F)
    static let line = Color(hex: 0xE5DCD1)
    static let card = Color(hex: 0xFFFDF8)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line.opacity(0.7), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(2)
            .foregroundStyle(Palette.secondary)
    }
}

struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(Palette.coral)
            Image(systemName: "waveform")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Palette.background)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

struct PrimaryButton: View {
    let title: String
    let icon: String
    var isBusy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if isBusy { ProgressView().tint(.white) }
                else { Image(systemName: icon).font(.body.weight(.semibold)) }
                Text(title).font(.system(.body, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 19)
            .foregroundStyle(.white)
            .background(Palette.coral, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityIdentifier("primaryAction")
    }
}

struct ListeningOrb: View {
    var isListening: Bool
    var detected: Bool
    var size: CGFloat = 218
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !isListening || reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let breath = isListening && !reduceMotion ? sin(time * 1.5) * 0.025 : 0
            ZStack {
                Circle().stroke(Palette.peach.opacity(0.5), lineWidth: 1)
                    .padding(1)
                Circle().stroke(Palette.peach.opacity(0.7), lineWidth: 1)
                    .padding(size * 0.075)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xF9E9DC), Palette.peach, Color(hex: 0xEAC1A9)],
                                         center: .init(x: 0.38, y: 0.32), startRadius: 0, endRadius: size * 0.65))
                    .padding(size * 0.14)
                    .shadow(color: Palette.coral.opacity(0.08), radius: 20, y: 10)
                    .scaleEffect(1 + breath)
                HStack(alignment: .center, spacing: size * 0.025) {
                    ForEach(0..<9, id: \.self) { index in
                        let shape = 1 - abs(Double(index - 4)) / 5
                        let movement = isListening && !reduceMotion ? (sin(time * 2.8 + Double(index) * 0.8) + 1) * 0.3 : 0
                        Capsule()
                            .fill(Palette.coral.opacity(index == 4 ? 1 : 0.7))
                            .frame(width: size * 0.023, height: size * (0.06 + shape * 0.17 + movement * 0.08))
                    }
                }
                Image(systemName: detected ? "sparkle" : "plus")
                    .font(.system(size: size * 0.07, weight: .light))
                    .foregroundStyle(Palette.coral.opacity(0.65))
                    .offset(x: size * 0.36, y: -size * 0.31)
                Circle().fill(Palette.peach).frame(width: 7, height: 7)
                    .offset(x: -size * 0.42, y: size * 0.19)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
