import SwiftUI

@main
struct BabyHeroApp: App {
    @StateObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let fixture = arguments.firstIndex(of: "--preview-state").flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        _model = StateObject(wrappedValue: AppModel(preview: fixture))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in model.sceneChanged(phase) }
        }
    }
}
