import XCTest
@testable import BabyHeroCore

final class ToneAnalyzerTests: XCTestCase {
    private func tone(_ frequency: Double, amplitude: Double = 0.08, seconds: Double = 1.5,
                      rate: Double = 48_000, offset: Int = 0) -> [Float] {
        (0..<Int(rate * seconds)).map { Float(amplitude * sin(2 * .pi * frequency * Double($0 + offset) / rate)) }
    }

    private func analyze(_ samples: [Float], rate: Double = 48_000, chunk: Int = 913) -> [AnalysisSnapshot] {
        let analyzer = ToneAnalyzer(sampleRate: rate)!
        var results: [AnalysisSnapshot] = []
        for start in stride(from: 0, to: samples.count, by: chunk) {
            results += analyzer.process(Array(samples[start..<min(samples.count, start + chunk)]))
        }
        return results
    }

    private func noisyTone(_ frequency: Double, seconds: Double = 6, rate: Double = 48_000,
                           toneSeconds: Double? = nil, seed initialSeed: UInt64 = 23) -> [Float] {
        var seed = initialSeed
        let amplitude = pow(10.0, -55.0 / 20)
        let noiseAmplitude = pow(10.0, -35.0 / 20) * sqrt(3)
        return (0..<Int(rate * seconds)).map { index in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let noise = (Double(seed >> 32) / Double(UInt32.max) * 2 - 1) * noiseAmplitude
            let time = Double(index) / rate
            let signal = time < (toneSeconds ?? seconds) ? amplitude * sin(2 * .pi * frequency * time) : 0
            return Float(signal + noise)
        }
    }

    func testDiscoversWeakStationaryToneInNoise() {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for frequency in [9_000.0, 9_234.0] {
                let settled = analyze(noisyTone(frequency, rate: rate), rate: rate).filter { $0.elapsed >= 3 }
                let matches = settled.filter { snapshot in
                    snapshot.tones.contains { abs($0.frequency - frequency) < 20 }
                }
                XCTAssertGreaterThan(Double(matches.count) / Double(settled.count), 0.95,
                                     "Weak \(frequency) Hz tone at \(rate) Hz input should remain discoverable")
            }
        }
    }

    func testNoiseAloneAndBriefNoisyTonesDoNotBecomePersistent() {
        for seed: UInt64 in [1, 23, 97] {
            for duration in [0.0, 0.3, 0.6] {
                let results = analyze(noisyTone(9_000, toneSeconds: duration, seed: seed))
                XCTAssertTrue(results.allSatisfy { $0.tones.isEmpty }, "seed \(seed), duration \(duration)")
            }
        }
    }

    func testWeakToneDisappearsAndTrackingIsLostWhenSourceStops() throws {
        let analyzer = ToneAnalyzer(sampleRate: 48_000)!
        analyzer.select(frequency: 9_000)
        let results = analyzer.process(noisyTone(9_000, toneSeconds: 3))
        XCTAssertTrue(results.contains { !$0.tones.isEmpty })
        let afterStop = results.filter { $0.elapsed >= 3.8 }
        XCTAssertTrue(afterStop.allSatisfy { $0.tones.isEmpty && $0.tracking?.trend == .lost })
        XCTAssertNil(try XCTUnwrap(results.last?.tracking).level)
    }

    func testDetectsToneAtActualSampleRates() throws {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            let result = try XCTUnwrap(analyze(tone(12_345, rate: rate), rate: rate).last)
            let detected = try XCTUnwrap(result.tones.first)
            XCTAssertEqual(detected.frequency, 12_345, accuracy: rate / Double(ToneAnalyzer.windowSize))
            XCTAssertEqual(detected.level, 20 * log10(0.08), accuracy: 0.4)
        }
    }

    func testRequiresPersistenceBeforeShowingTone() {
        let results = analyze(tone(15_000, seconds: 1.5))
        let earliestConfirmation = Double(ToneAnalyzer.windowSize) / 48_000 + ToneAnalyzer.persistenceDuration
        XCTAssertTrue(results.filter { $0.elapsed < earliestConfirmation }.allSatisfy { $0.tones.isEmpty })
        XCTAssertFalse(results.last!.tones.isEmpty)
    }

    func testSilenceAndBriefTransientsDoNotBecomeTones() {
        XCTAssertTrue(analyze([Float](repeating: 0, count: 96_000)).allSatisfy { $0.tones.isEmpty })
        let transient = tone(14_000, seconds: 0.3) + [Float](repeating: 0, count: 72_000)
        XCTAssertTrue(analyze(transient).allSatisfy { $0.tones.isEmpty })
    }

    func testBroadbandNoiseDoesNotBecomePersistentTone() {
        var seed: UInt64 = 23
        let noise: [Float] = (0..<144_000).map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            return Float(Double(seed >> 32) / Double(UInt32.max) * 0.2 - 0.1)
        }
        XCTAssertTrue(analyze(noise).allSatisfy { $0.tones.isEmpty })
    }

    func testMultipleTonesAreSortedByLevel() throws {
        let low = tone(11_000, amplitude: 0.03)
        let high = tone(16_000, amplitude: 0.12)
        let mixed = zip(low, high).map(+)
        let detected = try XCTUnwrap(analyze(mixed).last).tones
        XCTAssertEqual(detected.count, 2)
        XCTAssertEqual(detected[0].frequency, 16_000, accuracy: 15)
        XCTAssertEqual(detected[1].frequency, 11_000, accuracy: 15)
    }

    func testDoesNotDetectOutOfBandTones() {
        for frequency in [3_000.0, 7_000.0, 21_000.0] {
            XCTAssertTrue(analyze(tone(frequency)).last!.tones.isEmpty)
        }
    }

    func testNyquistGuardAndInvalidFormats() {
        XCTAssertNil(ToneAnalyzer(sampleRate: .nan))
        XCTAssertNil(ToneAnalyzer(sampleRate: 16_000))
        let results = analyze(tone(13_000, rate: 32_000), rate: 32_000)
        XCTAssertEqual(results.last!.upperFrequency, 14_400)
        XCTAssertFalse(results.last!.tones.isEmpty)
        XCTAssertTrue(analyze(tone(15_000, rate: 32_000), rate: 32_000).last!.tones.isEmpty)
    }

    func testArbitraryBufferBoundariesProduceSameResult() {
        let samples = tone(13_250)
        let a = analyze(samples, chunk: 257).last!.tones.first!
        let b = analyze(samples, chunk: 8192).last!.tones.first!
        XCTAssertEqual(a.frequency, b.frequency, accuracy: 0.0001)
        XCTAssertEqual(a.level, b.level, accuracy: 0.0001)
    }

    func testSelectedToneDoesNotSwitchToLouderTone() throws {
        let analyzer = ToneAnalyzer(sampleRate: 48_000)!
        analyzer.select(frequency: 12_000)
        _ = analyzer.process(tone(12_000))
        let other = analyzer.process(tone(16_000, amplitude: 0.4))
        let reading = try XCTUnwrap(other.last?.tracking)
        XCTAssertEqual(reading.frequency, 12_000)
        XCTAssertEqual(reading.trend, .lost)
        XCTAssertNil(reading.level)
        XCTAssertEqual(other.last!.tones.first!.frequency, 16_000, accuracy: 15)
    }

    func testTracksAmplitudeChanges() throws {
        let analyzer = ToneAnalyzer(sampleRate: 48_000)!
        analyzer.select(frequency: 12_000)
        let a = try XCTUnwrap(analyzer.process(tone(12_000, amplitude: 0.03)).last?.tracking?.level)
        let b = try XCTUnwrap(analyzer.process(tone(12_000, amplitude: 0.12)).last?.tracking?.level)
        XCTAssertEqual(b - a, 12.04, accuracy: 0.5)
    }

    func testResetClearsPersistenceAndTrackingHistory() throws {
        let analyzer = ToneAnalyzer(sampleRate: 48_000)!
        analyzer.select(frequency: 12_000)
        XCTAssertFalse(analyzer.process(tone(12_000)).last!.tones.isEmpty)
        analyzer.reset()
        let result = try XCTUnwrap(analyzer.process(tone(12_000, seconds: 0.2)).last)
        XCTAssertTrue(result.tones.isEmpty)
        XCTAssertEqual(result.tracking?.trend, .gathering)
        XCTAssertLessThan(result.tracking!.history.count, 3)
    }

    func testClippingAndNonfiniteInputHandled() {
        let analyzer = ToneAnalyzer(sampleRate: 48_000)!
        let clipped = analyzer.process(tone(12_000, amplitude: 1)).last!
        XCTAssertTrue(clipped.isClipping)
        let invalid = analyzer.process([Float](repeating: .nan, count: ToneAnalyzer.windowSize * 2)).last!
        XCTAssertFalse(invalid.isClipping)
        XCTAssertTrue(invalid.tones.allSatisfy { $0.level.isFinite })
    }
}

final class SignalTrackerTests: XCTestCase {
    private func feed(_ tracker: inout SignalTracker, from start: Double, through end: Double,
                      level: Double) -> TrackingReading {
        var reading: TrackingReading!
        for time in stride(from: start, through: end + 0.001, by: 0.1) {
            reading = tracker.update(time: time, level: level)
        }
        return reading
    }

    func testTrendWindowsAndDeadband() {
        var tracker = SignalTracker(frequency: 12_000)
        XCTAssertEqual(feed(&tracker, from: 0, through: 2, level: -50).trend, .steady)
        XCTAssertEqual(feed(&tracker, from: 2.1, through: 3, level: -40).trend, .stronger)
        XCTAssertEqual(feed(&tracker, from: 3.1, through: 4, level: -52).trend, .weaker)
        XCTAssertEqual(feed(&tracker, from: 4.1, through: 6, level: -51).trend, .steady)
    }

    func testLossClearsComparisonsAndReacquisitionStartsFresh() {
        var tracker = SignalTracker(frequency: 12_000)
        _ = feed(&tracker, from: 0, through: 2, level: -50)
        XCTAssertEqual(tracker.update(time: 2.1, level: nil).trend, .lost)
        XCTAssertEqual(tracker.update(time: 2.2, level: -30).trend, .gathering)
        tracker.reset()
        let reading = tracker.update(time: 3, level: -50)
        XCTAssertEqual(reading.history.count, 1)
        XCTAssertEqual(reading.trend, .gathering)
    }

    func testHistoryIsBoundedAndStrengthClamped() {
        var tracker = SignalTracker(frequency: 12_000)
        let reading = feed(&tracker, from: 0, through: 120, level: -40)
        XCTAssertLessThanOrEqual(reading.history.count, 81)
        XCTAssertGreaterThanOrEqual(reading.history.first!.time, 108)
        tracker.reset()
        XCTAssertEqual(tracker.update(time: 121, level: -200).strength, 0)
        tracker.reset()
        XCTAssertEqual(tracker.update(time: 122, level: 10).strength, 1)
    }
}
