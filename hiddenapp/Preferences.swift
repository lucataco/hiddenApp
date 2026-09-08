import Foundation

@MainActor
final class Preferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Constants.autoHideEnabled: Constants.defaultAutoHideEnabled,
            Constants.autoHideDelay: Constants.defaultAutoHideDelay,
        ])
    }

    var autoHideEnabled: Bool {
        get {
            defaults.object(forKey: Constants.autoHideEnabled) as? Bool
                ?? Constants.defaultAutoHideEnabled
        }
        set {
            defaults.set(newValue, forKey: Constants.autoHideEnabled)
        }
    }

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

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Constants.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Constants.hasCompletedOnboarding) }
    }
}
