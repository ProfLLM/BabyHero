import Foundation

public struct Tone: Identifiable, Equatable, Sendable {
    public let id: Int
    public let frequency: Double
    /// Relative digital level, not calibrated sound pressure.
    public let level: Double
    public let prominence: Double

    public init(id: Int, frequency: Double, level: Double, prominence: Double) {
        self.id = id
        self.frequency = frequency
        self.level = level
        self.prominence = prominence
    }
}

public enum SignalTrend: String, Sendable {
    case stronger = "Getting stronger"
    case weaker = "Getting weaker"
    case steady = "About the same"
    case gathering = "Measuring this tone"
    case lost = "Signal lost"
}

public struct SignalPoint: Equatable, Sendable {
    public let time: Double
    public let level: Double

    public init(time: Double, level: Double) {
        self.time = time
        self.level = level
    }
}

public struct TrackingReading: Equatable, Sendable {
    public let frequency: Double
    public let level: Double?
    public let trend: SignalTrend
    public let history: [SignalPoint]

    public init(frequency: Double, level: Double?, trend: SignalTrend, history: [SignalPoint]) {
        self.frequency = frequency
        self.level = level
        self.trend = trend
        self.history = history
    }

    public var strength: Double {
        guard let level else { return 0 }
        return min(1, max(0, (level + 90) / 80))
    }
}

public struct AnalysisSnapshot: Sendable {
    public let elapsed: Double
    public let upperFrequency: Double
    public let tones: [Tone]
    public let tracking: TrackingReading?
    public let isClipping: Bool

    public init(elapsed: Double, upperFrequency: Double, tones: [Tone], tracking: TrackingReading?, isClipping: Bool = false) {
        self.elapsed = elapsed
        self.upperFrequency = upperFrequency
        self.tones = tones
        self.tracking = tracking
        self.isClipping = isClipping
    }
}
