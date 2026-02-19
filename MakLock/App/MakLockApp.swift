import SwiftUI

@main
struct MakLockApp: App {
    var body: some Scene {
        MenuBarExtra("MakLock", systemImage: "lock") {
            VStack {
                Text("MakLock")
                    .font(.headline)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}
