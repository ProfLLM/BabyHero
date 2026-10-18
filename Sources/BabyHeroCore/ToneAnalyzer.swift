import Accelerate
import Foundation

/// Streaming, bounded-memory tone detector. Access from one serial queue.
public final class ToneAnalyzer {
    public static let windowSize = 4096
    public static let hopSize = 2048
    public let sampleRate: Double
    public var upperFrequency: Double { min(20_000, sampleRate * 0.45) }
    private let fft: FFTSetup
    private var ring = [Float](repeating: 0, count: windowSize)
    private var real = [Float](repeating: 0, count: windowSize)
    private var imaginary = [Float](repeating: 0, count: windowSize)
    private var window = [Float](repeating: 0, count: windowSize)
    private var levels = [Double](repeating: -160, count: windowSize / 2)
    private var writeIndex = 0
    private var totalSamples = 0
    private var sinceFrame = 0
    private var tracks: [Track] = []
    private var nextID = 0
    private var tracker: SignalTracker?

    private struct Peak {
        let frequency: Double
        let level: Double
        let prominence: Double
    }
    private struct Track {
        let id: Int
        var frequency: Double
        var level: Double
        var prominence: Double
        let firstSeen: Double
        var lastSeen: Double
    }

    public init?(sampleRate: Double) {
        guard sampleRate.isFinite, sampleRate >= 20_000,
              let fft = vDSP_create_fftsetup(12, FFTRadix(kFFTRadix2)) else { return nil }
        self.sampleRate = sampleRate
        self.fft = fft
        vDSP_hann_window(&window, vDSP_Length(Self.windowSize), Int32(vDSP_HANN_DENORM))
    }

    deinit { vDSP_destroy_fftsetup(fft) }

    public func select(frequency: Double?) {
        tracker = frequency.map { SignalTracker(frequency: $0) }
    }

    /// Reset all persistence and comparisons after a discontinuity or route change.
    public func reset() {
        writeIndex = 0
        totalSamples = 0
        sinceFrame = 0
        tracks.removeAll(keepingCapacity: true)
        ring = [Float](repeating: 0, count: Self.windowSize)
        tracker?.reset()
    }

    public func process(_ samples: [Float]) -> [AnalysisSnapshot] {
        var snapshots: [AnalysisSnapshot] = []
        for sample in samples {
            ring[writeIndex] = sample.isFinite ? sample : 0
            writeIndex = (writeIndex + 1) % Self.windowSize
            totalSamples += 1
            sinceFrame += 1
            if totalSamples >= Self.windowSize && sinceFrame >= Self.hopSize {
                sinceFrame = 0
                snapshots.append(analyzeFrame())
            }
        }
        return snapshots
    }

    private func analyzeFrame() -> AnalysisSnapshot {
        var clipped = false
        for index in 0..<Self.windowSize {
            let value = ring[(writeIndex + index) % Self.windowSize]
            clipped = clipped || abs(value) >= 0.99
            real[index] = value * window[index]
            imaginary[index] = 0
        }
        real.withUnsafeMutableBufferPointer { r in
            imaginary.withUnsafeMutableBufferPointer { i in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)
                vDSP_fft_zip(fft, &split, 1, 12, FFTDirection(FFT_FORWARD))
            }
        }
        // One-sided amplitude, corrected for the Hann window's coherent gain.
        let scale = 4.0 / Double(Self.windowSize)
        for bin in levels.indices {
            let magnitude = hypot(Double(real[bin]), Double(imaginary[bin])) * scale
            levels[bin] = 20 * log10(max(magnitude, 1e-8))
        }
        let time = Double(totalSamples) / sampleRate
        let peaks = findPeaks()
        updateTracks(peaks, time: time)
        let tones = tracks.filter { time - $0.firstSeen >= 1 && time - $0.lastSeen < 0.2 }
            .sorted { $0.level > $1.level }
            .prefix(3)
            .map { Tone(id: $0.id, frequency: $0.frequency, level: $0.level, prominence: $0.prominence) }

        var reading: TrackingReading?
        if var active = tracker {
            // This band stays fixed even if another, louder tone appears elsewhere.
            let match = peaks.filter { abs($0.frequency - active.frequency) <= 100 }
                .max { $0.level < $1.level }
            reading = active.update(time: time, level: match.map { bandLevel(near: $0.frequency) })
            tracker = active
        }
        return AnalysisSnapshot(elapsed: time, upperFrequency: upperFrequency, tones: tones,
                                tracking: reading, isClipping: clipped)
    }

    private func findPeaks() -> [Peak] {
        let step = sampleRate / Double(Self.windowSize)
        let lower = max(24, Int(ceil(8_000 / step)))
        let upper = min(levels.count - 25, Int(floor(upperFrequency / step)))
        guard lower <= upper else { return [] }
        var peaks: [Peak] = []
        for bin in lower...upper {
            let level = levels[bin]
            guard level > -85, level > levels[bin - 1], level >= levels[bin + 1] else { continue }
            // Exclude the main lobe; median of neighboring bins estimates local noise.
            let neighbors = ((bin - 24)...(bin - 5)).map { levels[$0] }
                + ((bin + 5)...(bin + 24)).map { levels[$0] }
            let ordered = neighbors.sorted()
            let background = ordered[ordered.count / 2]
            let prominence = level - background
            guard prominence >= 12 else { continue }
            let left = levels[bin - 1], right = levels[bin + 1]
            let denominator = left - 2 * level + right
            let offset = abs(denominator) > 1e-9 ? max(-0.5, min(0.5, 0.5 * (left - right) / denominator)) : 0
            let frequency = (Double(bin) + offset) * step
            guard frequency >= 8_000, frequency <= upperFrequency else { continue }
            peaks.append(Peak(frequency: frequency, level: bandLevel(near: frequency), prominence: prominence))
        }
        // Non-maximum suppression avoids treating one tone's leakage as more sources.
        var distinct: [Peak] = []
        for peak in peaks.sorted(by: { $0.level > $1.level }) {
            if !distinct.contains(where: { abs($0.frequency - peak.frequency) < 100 }) {
                distinct.append(peak)
            }
            if distinct.count == 12 { break }
        }
        return distinct
    }

    private func bandLevel(near frequency: Double) -> Double {
        let center = Int((frequency * Double(Self.windowSize) / sampleRate).rounded())
        let low = max(1, center - 2), high = min(levels.count - 1, center + 2)
        guard low <= high else { return -160 }
        // Hann equivalent noise bandwidth is 1.5 bins. Normalize to sine amplitude.
        let power = (low...high).reduce(0.0) { $0 + pow(10, levels[$1] / 10) }
        return 10 * log10(max(power / 1.5, 1e-16))
    }

    private func updateTracks(_ peaks: [Peak], time: Double) {
        let frameDuration = Double(Self.hopSize) / sampleRate
        // Require uninterrupted evidence; broadband spikes cannot accumulate over time.
        tracks.removeAll { time - $0.lastSeen > frameDuration * 1.6 }
        var matched = Set<Int>()
        for peak in peaks {
            let candidate = tracks.indices.filter { !matched.contains(tracks[$0].id) }
                .min { abs(tracks[$0].frequency - peak.frequency) < abs(tracks[$1].frequency - peak.frequency) }
            if let index = candidate, abs(tracks[index].frequency - peak.frequency) < 80 {
                tracks[index].frequency = tracks[index].frequency * 0.8 + peak.frequency * 0.2
                tracks[index].level = tracks[index].level * 0.65 + peak.level * 0.35
                tracks[index].prominence = peak.prominence
                tracks[index].lastSeen = time
                matched.insert(tracks[index].id)
            } else {
                tracks.append(Track(id: nextID, frequency: peak.frequency, level: peak.level,
                                    prominence: peak.prominence, firstSeen: time, lastSeen: time))
                matched.insert(nextID)
                nextID += 1
            }
        }
    }
}
