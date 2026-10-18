import BabyHeroCore
import SwiftUI

struct FinderView: View {
    let tone: Tone
    let reading: TrackingReading?
    let elapsed: Double
    let back: () -> Void

    private var current: TrackingReading? {
        guard let reading, abs(reading.frequency - tone.frequency) < 1 else { return nil }
        return reading
    }
    private var trend: SignalTrend { current?.trend ?? .gathering }
    private var strength: Double { current?.strength ?? 0 }

    var body: some View {
        VStack(spacing: 22) {
            Button(action: back) {
                Label("All sounds", systemImage: "chevron.left")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.coral)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("backToSounds")

            VStack(spacing: 9) {
                Eyebrow(text: "Following this tone")
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tone.frequency / 1000, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 48, weight: .regular, design: .serif)).monospacedDigit()
                    Text("kHz").font(.system(.title3, design: .rounded)).foregroundStyle(Palette.secondary)
                }.foregroundStyle(Palette.ink)
                Text("Let the signal be your guide.")
                    .font(.subheadline).foregroundStyle(Palette.secondary)
            }

            SignalGauge(strength: strength, trend: trend)
                .padding(.vertical, 4)

            Card {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("The last few steps")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("12 seconds").font(.caption).foregroundStyle(Palette.secondary)
                    }
                    SignalHistory(points: current?.history ?? [], elapsed: elapsed)
                        .frame(height: 64)
                    HStack {
                        Text("Earlier")
                        Spacer()
                        Text("Now")
                    }.font(.caption2).foregroundStyle(Palette.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Slow steps. Steady phone.", systemImage: "figure.walk")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("Walk slowly. Keep your phone facing the same way. Pause near suspected sources.")
                    .font(.footnote).foregroundStyle(Palette.secondary).lineSpacing(3)
                Text("Try switching off one nearby electronic device at a time and watch for a change.")
                    .font(.footnote).foregroundStyle(Palette.secondary).lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Signal strength is relative. Reflections and phone position can change the reading; it doesn’t measure distance.")
                .font(.caption).foregroundStyle(Palette.secondary).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SignalGauge: View {
    let strength: Double
    let trend: SignalTrend

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 12)
                Circle().trim(from: 0, to: strength)
                    .stroke(AngularGradient(colors: [Palette.peach, Palette.coral], center: .center,
                                             startAngle: .degrees(0), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(Palette.softPeach.opacity(0.65)).padding(20)
                VStack(spacing: 7) {
                    Image(systemName: trend == .lost ? "waveform.slash" : "waveform")
                        .font(.system(size: 30, weight: .light)).foregroundStyle(Palette.coral)
                    Text(trend == .lost ? "—" : strength > 0.65 ? "Strong" : strength > 0.35 ? "Clear" : "Soft")
                        .font(.system(.title2, design: .serif)).foregroundStyle(Palette.ink)
                    Text("RELATIVE SIGNAL")
                        .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(1.6)
                        .foregroundStyle(Palette.secondary)
                }
            }
            .frame(width: 192, height: 192)
            Text(trend.rawValue)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(trend == .lost ? Palette.secondary : Palette.coral)
            Text(trend == .lost ? "This tone is no longer clear. Try your last spot." :
                 trend == .gathering ? "Hold still for a moment to begin comparing." :
                 "Watch how this changes as you move.")
                .font(.caption).foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Relative signal, \(trend.rawValue)")
        .accessibilityValue(trend == .lost ? "No clear signal" : "\(Int(strength * 100)) out of 100, uncalibrated scale")
        .accessibilityIdentifier("signalGauge")
    }
}

private struct SignalHistory: View {
    let points: [SignalPoint]
    let elapsed: Double

    var body: some View {
        Canvas { context, size in
            for fraction in [0.0, 0.5, 1.0] {
                var line = Path()
                let y = size.height * fraction
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Palette.line), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            guard !points.isEmpty else { return }
            let end = max(elapsed, points.last!.time)
            var line = Path()
            var previous: SignalPoint?
            var lastPosition: CGPoint?
            for point in points where point.time >= end - 12 {
                let x = size.width * (point.time - (end - 12)) / 12
                let y = size.height * (1 - min(1, max(0, (point.level + 90) / 80)))
                let position = CGPoint(x: x, y: y)
                if let previous, point.time - previous.time < 0.4 { line.addLine(to: position) }
                else { line.move(to: position) }
                previous = point
                lastPosition = position
            }
            context.stroke(line, with: .color(Palette.coral), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            if let p = lastPosition {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(Palette.coral))
            }
        }
        .accessibilityLabel("Recent relative signal strength. Gaps indicate the tone was not clear.")
    }
}
