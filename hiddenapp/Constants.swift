import CoreGraphics
import Foundation

enum Constants {

    static let autoHideEnabled = "autoHideEnabled"
    static let autoHideDelay = "autoHideDelay"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"

    static let defaultAutoHideEnabled = true
    static let defaultAutoHideDelay: TimeInterval = 10.0
    static let minimumAutoHideDelay: TimeInterval = 2.0
    static let maximumAutoHideDelay: TimeInterval = 60.0

    static let autoHideDeferInterval: TimeInterval = 2.0

    static let projectURL = "https://catacolabs.com"

    static let separatorNormalLength: CGFloat = 20

    static let separatorMinCollapseLength: CGFloat = 500

    static let fallbackScreenWidth: CGFloat = 1728

    static let separatorCollapsePadding: CGFloat = 500

    static let separatorPositionValidationMaxRetries = 20
    static let separatorPositionValidationRetryDelay: TimeInterval = 0.25

    static let toggleAutosaveName = "hiddenapp_toggle"
    static let separatorAutosaveName = "hiddenapp_separator"
}
