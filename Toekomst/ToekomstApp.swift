import SwiftUI

@main
struct ToekomstApp: App {
    @State private var model = AppModel.fixtures()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.theme, model.settings.accent.colors)
                .preferredColorScheme(.dark)
                .tint(model.settings.accent.colors.signal)
        }
    }
}
