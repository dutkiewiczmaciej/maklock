import AppKit
import Combine

/// Monitors app launches and activations to detect when a protected app starts.
final class AppMonitorService: ObservableObject {
    static let shared = AppMonitorService()

    /// Published when a protected app is launched or activated.
    @Published var detectedApp: ProtectedApp?

    /// Callback invoked when a protected app is detected.
    var onProtectedAppDetected: ((ProtectedApp) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    /// Apps that have been authenticated recently. Key: bundleIdentifier, Value: auth timestamp.
    private var authenticatedApps: [String: Date] = [:]

    /// Grace period after authentication during which the app won't be re-locked.
    private let gracePeriod: TimeInterval = 5

    private init() {}

    /// Start monitoring app launches and activations.
    func startMonitoring() {
        let workspace = NSWorkspace.shared

        // Monitor app launches
        workspace.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.handleAppEvent(app)
            }
            .store(in: &cancellables)

        // Monitor app activations (switching to a running protected app)
        workspace.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.handleAppEvent(app)
            }
            .store(in: &cancellables)

        NSLog("[MakLock] App monitor started")
    }

    /// Stop monitoring.
    func stopMonitoring() {
        cancellables.removeAll()
        NSLog("[MakLock] App monitor stopped")
    }

    /// Mark an app as authenticated (won't re-lock until session expires or is cleared).
    func markAuthenticated(_ bundleIdentifier: String) {
        authenticatedApps[bundleIdentifier] = Date()
        NSLog("[MakLock] App authenticated, grace period started: %@", bundleIdentifier)
    }

    /// Clear authentication for all apps (e.g., on idle lock, sleep lock).
    func clearAllAuthentications() {
        authenticatedApps.removeAll()
        NSLog("[MakLock] All app authentications cleared")
    }

    /// Clear authentication for a specific app.
    func clearAuthentication(for bundleIdentifier: String) {
        authenticatedApps.removeValue(forKey: bundleIdentifier)
    }

    private func handleAppEvent(_ runningApp: NSRunningApplication) {
        guard let bundleID = runningApp.bundleIdentifier else { return }

        // Skip blacklisted system apps
        guard !SafetyManager.isBlacklisted(bundleID) else { return }

        // Check if this app is in the protected list
        let protectedApps = Defaults.shared.protectedApps
        guard let protectedApp = protectedApps.first(where: {
            $0.bundleIdentifier == bundleID && $0.isEnabled
        }) else { return }

        // Check if global protection is enabled
        let settings = Defaults.shared.appSettings
        guard settings.isProtectionEnabled else { return }

        // Skip if app was recently authenticated (grace period)
        if let authDate = authenticatedApps[bundleID] {
            let elapsed = Date().timeIntervalSince(authDate)
            if elapsed < gracePeriod {
                return
            }
            // Grace period expired — remove and re-lock
            authenticatedApps.removeValue(forKey: bundleID)
        }

        // Don't show overlay if one is already showing
        guard !OverlayWindowService.shared.isShowing else { return }

        NSLog("[MakLock] Protected app detected: %@ (%@)", protectedApp.name, bundleID)
        detectedApp = protectedApp
        onProtectedAppDetected?(protectedApp)
    }
}
