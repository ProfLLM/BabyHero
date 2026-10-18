# Contributing to BabyHero

Issues and pull requests are welcome at [ProfLLM/BabyHero](https://github.com/ProfLLM/BabyHero).

## Project foundations

Every change must preserve these commitments:

- Customer data stays on the phone. Process audio and measurements locally; do not add uploads, servers, remote inference, or cloud synchronization.
- No ads, accounts, account tracking, usage tracking, analytics, fingerprinting, or telemetry SDKs.
- Microphone access starts with an explicit user action. Stop and foreground/background behavior must remain clear and reliable.
- Do not store recordings or session history. Use bounded, temporary memory for analysis.
- Describe measured signals honestly. A detected tone does not establish what a baby hears or finds uncomfortable, and signal strength does not establish distance or direction.

Keep the privacy policy, in-app explanation, and privacy manifest consistent with the implementation. Prefer Apple frameworks and avoid adding dependencies.

## Development and checks

Follow the [README](README.md) to run the app in Xcode. Run `swift test` for signal-analysis tests. For capture, lifecycle, or interface changes, also build the iOS app and run the relevant simulator tests in the BabyHero scheme.

Use synthetic signals to reproduce detector issues. For UI changes, include a screenshot with sample data clearly labeled. Never include microphone recordings, credentials, signing identities, provisioning profiles, or personal device data in a contribution.

Keep changes focused and describe the resulting behavior, validation performed, and remaining hardware limitations. Physical-device results should state the iPhone model and test setup without making claims about infant discomfort.

## License

By contributing, you agree that your contributions are provided under this project’s [MIT license](LICENSE).
