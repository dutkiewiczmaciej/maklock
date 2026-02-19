import AppKit

/// Application delegate responsible for lifecycle and menu bar setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.setup()

        // Initialize safety manager and wire up panic key
        SafetyManager.shared.onPanicKeyPressed = {
            OverlayWindowService.shared.dismissAll()
        }

        // Initialize settings window controller (listens for openSettings notification)
        _ = SettingsWindowController.shared

        // Wire up app monitor → overlay
        AppMonitorService.shared.onProtectedAppDetected = { app in
            OverlayWindowService.shared.show(for: app)
        }

        // For now, unlock just hides the overlay (auth service comes in Task 10)
        OverlayWindowService.shared.onUnlockRequested = { _ in
            OverlayWindowService.shared.hide()
        }

        // Start monitoring
        AppMonitorService.shared.startMonitoring()
    }
}
