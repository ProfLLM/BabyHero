import AVFoundation
import BabyHeroCore
import Foundation

enum CaptureError: LocalizedError {
    case noBuiltInMicrophone
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .noBuiltInMicrophone: "Your iPhone’s built-in microphone isn’t available. Disconnect external audio devices and try again."
        case .unsupportedFormat: "This microphone configuration can’t capture the high-frequency range. Try again using the iPhone microphone."
        }
    }
}

actor AudioCapture {
    private var engine: AVAudioEngine?
    private var worker: AnalysisWorker?
    private var currentOperation = 0
    private var hasTap = false

    func start(operation: Int, onSnapshot: @escaping @MainActor @Sendable (AnalysisSnapshot) -> Void) throws {
        guard operation >= currentOperation else { throw CancellationError() }
        currentOperation = operation
        stopEngine()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setPreferredSampleRate(48_000)
            try session.setActive(true)
            guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                throw CaptureError.noBuiltInMicrophone
            }
            try session.setPreferredInput(builtIn)
            try Task.checkCancellation()
            guard session.currentRoute.inputs.contains(where: { $0.portType == .builtInMic }) else {
                throw CaptureError.noBuiltInMicrophone
            }
            let engine = AVAudioEngine()
            self.engine = engine
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.channelCount > 0, format.commonFormat == .pcmFormatFloat32, !format.isInterleaved,
                  let analyzer = ToneAnalyzer(sampleRate: format.sampleRate) else {
                throw CaptureError.unsupportedFormat
            }
            let worker = AnalysisWorker(analyzer: analyzer) { snapshot in
                Task { @MainActor in onSnapshot(snapshot) }
            }
            self.worker = worker
            input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, time in
                worker.receive(buffer, time: time)
            }
            hasTap = true
            engine.prepare()
            try engine.start()
        } catch {
            stopEngine()
            throw error
        }
    }

    func select(frequency: Double?, operation: Int) {
        guard operation == currentOperation else { return }
        worker?.select(frequency: frequency)
    }

    func stop(operation: Int) {
        guard operation >= currentOperation else { return }
        currentOperation = operation
        stopEngine()
    }

    private func stopEngine() {
        if hasTap { engine?.inputNode.removeTap(onBus: 0) }
        hasTap = false
        engine?.stop()
        engine = nil
        worker = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// At most one pending buffer, so analysis never queues unbounded microphone audio.
/// The analyzer and selection are confined to `queue`.
private final class AnalysisWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.babyhero.analysis", qos: .userInitiated)
    private let slot = DispatchSemaphore(value: 1)
    private let analyzer: ToneAnalyzer
    private let deliver: @Sendable (AnalysisSnapshot) -> Void
    private var lastDelivery = -Double.infinity
    private var expectedSampleTime: AVAudioFramePosition?

    init(analyzer: ToneAnalyzer, deliver: @escaping @Sendable (AnalysisSnapshot) -> Void) {
        self.analyzer = analyzer
        self.deliver = deliver
    }

    func receive(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard slot.wait(timeout: .now()) == .success else { return }
        guard let channel = buffer.floatChannelData?[0] else { slot.signal(); return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let sampleTime = time.isSampleTimeValid ? time.sampleTime : nil
        queue.async { [self] in
            defer { slot.signal() }
            if let sampleTime, let expectedSampleTime, sampleTime != expectedSampleTime {
                analyzer.reset()
                lastDelivery = -.infinity
            }
            expectedSampleTime = sampleTime.map { $0 + AVAudioFramePosition(samples.count) }
            for snapshot in analyzer.process(samples) {
                if snapshot.elapsed - lastDelivery >= 0.09 {
                    lastDelivery = snapshot.elapsed
                    deliver(snapshot)
                }
            }
        }
    }

    func select(frequency: Double?) {
        queue.async { [self] in analyzer.select(frequency: frequency) }
    }
}
