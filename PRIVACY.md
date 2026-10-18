# Privacy promise

**Your data stays on your phone. No ads. No accounts. No tracking.**

BabyHero is an open-source iPhone app published by [ProfLLM](https://github.com/ProfLLM) under the [MIT license](LICENSE). Privacy is a foundation of this project.

## Data stays on your iPhone

All sound analysis runs locally on your iPhone. BabyHero does not transmit microphone audio, sound measurements, identifiers, or usage data to ProfLLM or anyone else. There is no backend, cloud processing, upload, or remote account service. The listening and finding features work offline.

Microphone samples are analyzed in bounded, temporary memory and discarded. The app does not save audio recordings or session history. The short signal trace exists only for the current session and is cleared when listening stops. It is not written to a file or synchronized to iCloud.

## No ads or tracking

BabyHero has no advertising, advertising identifiers, account creation, account tracking, usage tracking, analytics, profiling, or third-party crash-reporting SDKs. There are no third-party app dependencies.

## Microphone permission

The app requests access only after you tap **Start listening**. It uses the built-in microphone to look for persistent high-pitched tones. **Stop listening** ends capture; leaving the foreground or changing the audio connection pauses it and clears the session. Listening requires an explicit restart. You can revoke microphone access in iPhone Settings.

## Links you choose to open

The information sheet includes optional links to research and Apple documentation. They open in your browser only when tapped. BabyHero attaches no microphone samples, measurements, account information, or identifiers to those links. The destination website and browser have their own privacy policies.

## Open-source collaboration

The source and privacy manifest are available for inspection. GitHub handles information you choose to post in an issue, discussion, or pull request under GitHub’s own policies. Please use synthetic test signals and avoid posting household recordings or personal information.

Contributions must preserve these privacy commitments; see [CONTRIBUTING.md](CONTRIBUTING.md).
