# Validation

## Automated verification

The macOS signal test suite checks:

- Frequency and amplitude accuracy at 44.1, 48, and 96 kHz.
- One-second persistence and rejection of silence, broadband noise, brief tones, and out-of-band signals.
- Multiple tones, strongest-first ordering, arbitrary buffer boundaries, and Nyquist limits.
- Selected-tone locking, amplitude changes, signal loss, reacquisition, and reset behavior.
- Trend comparison windows, smoothing, bounded history, clipping, and nonfinite samples.

The iPhone simulator UI suite checks launch without a microphone prompt, information-sheet navigation, selecting tones, returning to sounds, stopping, quiet/lost states, permission denial and grant, foreground/background pause, and controls at the largest accessibility text size. Sample-data screens are explicitly labeled.

Results on October 17, 2026, using Xcode 27.1:

| Check | Result |
| --- | --- |
| macOS signal-analysis and tracker tests | 15 passed, 0 failures |
| iPhone 18 Pro simulator, iOS 27.0, UI tests | 7 passed, 0 failures |
| iOS Simulator Debug build, iOS 17 deployment target | Passed |
| iPhone Release build, iOS 17 deployment target, signing disabled | Passed |
| Project, Info.plist, and privacy manifest syntax | Passed |
| Welcome, finder, and largest-text screenshot review | Passed; screenshots included in `Screenshots/` |
| Physical microphone sensitivity and walking comparisons | Pending; only a simulated iPhone is connected |

The microphone-grant test reached live capture and successfully stopped it in the simulator. Audio setup/teardown run off the UI thread. Permission callbacks wait for an active scene; cancellation and session operation identifiers prevent stale capture work from updating a newer session. At accessibility text sizes, the pinned action uses a shorter label and omits the decorative privacy tagline to keep readings reachable.

Simulator capture and synthetic PCM tests do not establish real iPhone high-frequency sensitivity. The build emits only Xcode’s informational App Intents metadata warning because this app has no App Intents dependency.

## Physical iPhone protocol — pending

No hardware detection performance or effective range is claimed. A physical iPhone and a controlled, independently checked source are needed to finish this section.

1. Record the iPhone model, iOS version, case, microphone orientation, source, room, and actual input sample rate (inspect `AVAudioEngine.inputNode.outputFormat(forBus: 0)` in Xcode).
2. Away from babies, use a controlled source at a comfortable, independently measured level. Do not increase an inaudible source just because you cannot hear it. Verify the source with suitable reference equipment; ordinary speakers may fail to produce the intended frequency or introduce other tones.
3. Check several tones across the search band, including near 8, 12, 16, 18, and 20 kHz. Record which tones are detected, detection time, and displayed frequency. A digital sample rate alone does not confirm sensitivity at the top of the band.
4. Hold orientation and grip steady. Compare fixed positions nearer and farther from a stationary source. Repeat in a reflective room and record cases where reflections reverse the expected trend.
5. Switch the source off and verify **Signal lost**. Introduce a louder tone at another frequency and confirm the finder stays on the original selection.
6. Compare readings with the case on/off and the microphone partly obstructed. Record attenuation and false negatives rather than treating them as quiet-room results.
7. Exercise microphone denial/revocation, an incoming call, lock/unlock, home/app switching, and connection/disconnection of external audio devices. Capture must stop and require an explicit restart, with cleared readings.
8. Confirm the iOS microphone indicator clears after Stop and backgrounding. Use airplane mode to confirm the full listening/finding flow works offline. Verify no audio files or session history are written in the app container.

These thresholds are initial engineering settings, not validated hearing or infant-discomfort thresholds. Hardware validation can motivate adjustments to detection defaults without changing that distinction.
