//
//  Preferences.swift
//  hiddenapp
//
//  Centralized, testable wrapper around UserDefaults for all app preferences.
//  AutoHideManager and PreferencesView both read and write through this object
//  so there is a single source of truth for keys, defaults, and clamping.
//

import Foundation

@MainActor
final class Preferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Auto-hide

    /// Whether auto-hide is enabled. Persists to UserDefaults.
    var autoHideEnabled: Bool {
        get {
            defaults.object(forKey: Constants.autoHideEnabled) as? Bool
                ?? Constants.defaultAutoHideEnabled
        }
        set {
            defaults.set(newValue, forKey: Constants.autoHideEnabled)
        }
    }

    /// The auto-hide delay in seconds, clamped to
    /// `Constants.minimumAutoHideDelay...Constants.maximumAutoHideDelay`.
    /// Persists to UserDefaults.
    var autoHideDelay: TimeInterval {
        get {
            let stored = defaults.double(forKey: Constants.autoHideDelay)
            return stored > 0 ? stored : Constants.defaultAutoHideDelay
        }
        set {
            let clamped = min(
                max(newValue, Constants.minimumAutoHideDelay),
                Constants.maximumAutoHideDelay
            )
            defaults.set(clamped, forKey: Constants.autoHideDelay)
        }
    }

    // MARK: - Onboarding

    /// Whether the first-run welcome popover has been shown and dismissed.
    /// Defaults to `false` so new installs see the onboarding once.
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Constants.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Constants.hasCompletedOnboarding) }
    }
}
