import SwiftUI

@main struct MyApp: App {
    init() {
        #if DEBUG
        PrototypeChecks.run()
        #endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
