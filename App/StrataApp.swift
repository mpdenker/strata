import SwiftUI

@main
struct StrataApp: App {
    @State private var content = ContentStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(content)
                .tint(Color.ink)
        }
    }
}
