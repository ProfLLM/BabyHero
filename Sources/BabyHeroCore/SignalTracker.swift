import Foundation

/// Compares consecutive one-second windows of the same narrow-band signal.
/// Used on the analysis queue only. Missing signal breaks the comparison history.
public struct SignalTracker {
    public private(set) var frequency: Double
    private var samples: [SignalPoint] = []
    private var history: [SignalPoint] = []
    private var smoothedLevel: Double?
    private var lastHistoryTime = -Double.infinity

    public init(frequency: Double) { self.frequency = frequency }

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        history.removeAll(keepingCapacity: true)
        smoothedLevel = nil
        lastHistoryTime = -.infinity
    }

    public mutating func update(time: Double, level: Double?) -> TrackingReading {
        history.removeAll { time - $0.time > 12 }
        guard let level, level.isFinite else {
            samples.removeAll(keepingCapacity: true)
            smoothedLevel = nil
            return TrackingReading(frequency: frequency, level: nil, trend: .lost, history: history)
        }
        let smoothed = smoothedLevel.map { $0 * 0.75 + level * 0.25 } ?? level
        smoothedLevel = smoothed
        samples.append(SignalPoint(time: time, level: level))
        samples.removeAll { time - $0.time > 2.1 }
        if time - lastHistoryTime >= 0.15 {
            history.append(SignalPoint(time: time, level: smoothed))
            lastHistoryTime = time
        }
        var trend: SignalTrend = .gathering
        if let first = samples.first, time - first.time >= 1.9 {
            let previous = samples.filter { $0.time <= time - 1 }
            let current = samples.filter { $0.time > time - 1 }
            if !previous.isEmpty && !current.isEmpty {
                let difference = current.map(\.level).reduce(0, +) / Double(current.count)
                    - previous.map(\.level).reduce(0, +) / Double(previous.count)
                trend = difference > 3 ? .stronger : difference < -3 ? .weaker : .steady
            }
        }
        return TrackingReading(frequency: frequency, level: smoothed, trend: trend, history: history)
    }
}
