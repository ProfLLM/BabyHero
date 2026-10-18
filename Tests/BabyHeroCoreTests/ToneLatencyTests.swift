import XCTest
@testable import BabyHeroCore

final class ToneLatencyTests: XCTestCase {
    private func samples(rate: Double, duration: Double, toneDuration: Double,
                         noisy: Bool = false, seed initialSeed: UInt64 = 23) -> [Float] {
        var seed = initialSeed
        let amplitude = noisy ? pow(10.0, -55.0 / 20) : 0.08
        let noiseAmplitude = noisy ? pow(10.0, -35.0 / 20) * sqrt(3) : 0
        return (0..<Int(rate * duration)).map { index in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let noise = (Double(seed >> 32) / Double(UInt32.max) * 2 - 1) * noiseAmplitude
            let time = Double(index) / rate
            let signal = time < toneDuration ? amplitude * sin(2 * .pi * 9_000 * time) : 0
            return Float(signal + noise)
        }
    }

    func testClearToneAppearsWithinAboutOneSecondOfAudio() throws {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            let analyzer = try XCTUnwrap(ToneAnalyzer(sampleRate: rate))
            let readings = analyzer.process(samples(rate: rate, duration: 1.2, toneDuration: 1.2))
            let first = try XCTUnwrap(readings.first { !$0.tones.isEmpty })
            // Includes the first FFT window and rounding to the next analysis hop.
            XCTAssertLessThanOrEqual(first.elapsed, 1.05, "Sample rate: \(rate)")
            XCTAssertTrue(readings.filter { $0.elapsed < ToneAnalyzer.persistenceDuration }.allSatisfy { $0.tones.isEmpty })
        }
    }

    func testShortTonesStayRejectedWithFasterConfirmation() throws {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for noisy in [false, true] {
                for seed: UInt64 in [1, 23, 97] {
                    let analyzer = try XCTUnwrap(ToneAnalyzer(sampleRate: rate))
                    let readings = analyzer.process(samples(rate: rate, duration: 2,
                                                            toneDuration: 0.6, noisy: noisy, seed: seed))
                    XCTAssertTrue(readings.allSatisfy { $0.tones.isEmpty }, "Rate: \(rate), noise: \(noisy), seed: \(seed)")
                }
            }
        }
    }

    func testWeakToneAppearsPromptlyInNoise() throws {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            let analyzer = try XCTUnwrap(ToneAnalyzer(sampleRate: rate))
            let readings = analyzer.process(samples(rate: rate, duration: 2, toneDuration: 2, noisy: true))
            let first = try XCTUnwrap(readings.first { $0.tones.contains { abs($0.frequency - 9_000) < 20 } })
            XCTAssertLessThanOrEqual(first.elapsed, 1.5, "Sample rate: \(rate)")
        }
    }
}
