import SwiftUI

@main struct MyApp: App {
    @State private var settings = ExampleSettings()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 760)
        #endif
    }
}
