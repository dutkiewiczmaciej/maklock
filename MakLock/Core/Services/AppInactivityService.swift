import AppKit

/// Tracks per-app inactivity and terminates protected apps that have auto-close enabled
/// after the configured timeout. Prevents notifications from locked messaging apps.
final class AppInactivityService: ObservableObject {
    static let shared = AppInactivityService()

    @Published private(set) var isMonitoring = false

    /// Per-app close timers: bundleID → Timer
    private var closeTimers: [String: Timer] = [:]

    /// Last active protected app bundle ID (to start timer when it loses focus).
    private var lastActiveProtectedBundleID: String?

    private var activateObserver: Any?

    private init() {}

    /// Start monitoring app activations for auto-close.
    func startMonitoring() {
        guard !isMonitoring else { return }

        activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }

        isMonitoring = true
        NSLog("[MakLock] AppInactivityService started monitoring")
    }

    /// Stop monitoring and cancel all pending close timers.
    func stopMonitoring() {
        if let observer = activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            activateObserver = nil
        }

        cancelAllTimers()
        lastActiveProtectedBundleID = nil
        isMonitoring = false
        NSLog("[MakLock] AppInactivityService stopped monitoring")
    }

    /// Cancel the close timer for a specific app (e.g. when auto-close is toggled off).
    func cancelTimer(for bundleID: String) {
        closeTimers[bundleID]?.invalidate()
        closeTimers.removeValue(forKey: bundleID)
    }

    // MARK: - Private

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        // If the previously active app was a protected auto-close app, start its timer
        if let previousBundleID = lastActiveProtectedBundleID, previousBundleID != bundleID {
            startCloseTimer(for: previousBundleID)
        }

        // If the newly activated app is a protected auto-close app, cancel its timer
        if shouldAutoClose(bundleID) {
            cancelTimer(for: bundleID)
            lastActiveProtectedBundleID = bundleID
        } else {
            lastActiveProtectedBundleID = nil
        }
    }

    private func shouldAutoClose(_ bundleID: String) -> Bool {
        guard !SafetyManager.isBlacklisted(bundleID) else { return false }
        return ProtectedAppsManager.shared.apps.contains {
            $0.bundleIdentifier == bundleID && $0.isEnabled && $0.autoClose
        }
    }

    private func startCloseTimer(for bundleID: String) {
        guard shouldAutoClose(bundleID) else { return }

        // Cancel existing timer if any
        cancelTimer(for: bundleID)

        let timeout = TimeInterval(Defaults.shared.appSettings.inactiveCloseMinutes) * 60

        closeTimers[bundleID] = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.terminateApp(bundleID)
        }

        NSLog("[MakLock] Auto-close timer started for %@ (%.0f min)", bundleID, timeout / 60)
    }

    private func cancelAllTimers() {
        closeTimers.values.forEach { $0.invalidate() }
        closeTimers.removeAll()
    }

    private func terminateApp(_ bundleID: String) {
        closeTimers.removeValue(forKey: bundleID)

        guard !SafetyManager.isBlacklisted(bundleID) else {
            NSLog("[MakLock] Refusing to auto-close blacklisted app: %@", bundleID)
            return
        }

        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            NSLog("[MakLock] App already closed: %@", bundleID)
            return
        }

        let name = app.localizedName ?? bundleID
        app.terminate()
        NSLog("[MakLock] Auto-closed inactive app: %@ (%@)", name, bundleID)

        // Clear authentication so overlay appears on next launch
        AppMonitorService.shared.clearAuthentication(for: bundleID)
    }
}
