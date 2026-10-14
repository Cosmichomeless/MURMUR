import Foundation
import Observation

/// Whether the user wants their notes in their own iCloud. Off unless they turn it on.
///
/// Stored in `UserDefaults` (declared in the privacy manifest as the app's own preferences). The
/// store is opened once at launch, so a change applies the next time the app starts:
/// `isActiveThisLaunch` is what the running app is actually doing.
@MainActor
@Observable
final class SyncSettings {
    nonisolated static let key = "sync.icloud"

    /// What the user chose. Takes effect at the next launch.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.key) }
    }

    /// Whether this launch opened the store with iCloud on.
    private(set) var isActiveThisLaunch = false

    /// Audio files that arrived from iCloud since launch. Views read it to refresh themselves.
    private(set) var audioRevision = 0

    /// The last problem reported by iCloud sync, in words for the user.
    var lastIssue: SyncIssue?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.key)
    }

    /// The choice read before the model container exists, which is when it has to be applied.
    nonisolated static func requested(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    func markActive(_ active: Bool) { isActiveThisLaunch = active }

    func audioDidArrive() { audioRevision += 1 }

    /// The user turned sync on or off and the running app still does the opposite.
    var needsRestart: Bool { isEnabled != isActiveThisLaunch }
}

enum SyncIssue: Equatable {
    /// No iCloud account on the device, or iCloud Drive is off for this app.
    case noAccount
    /// iCloud could not be used for this launch (the store opened without it).
    case unavailable
    /// iCloud storage is full; nothing more can be uploaded.
    case quotaExceeded
}
