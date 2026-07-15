//
//  Constants.swift
//  hiddenapp
//

import CoreGraphics
import Foundation

enum Constants {
    // MARK: - UserDefaults Keys
    static let autoHideEnabled = "autoHideEnabled"
    static let autoHideDelay = "autoHideDelay"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    
    // MARK: - Default Values
    static let defaultAutoHideEnabled = true
    static let defaultAutoHideDelay: TimeInterval = 10.0
    static let minimumAutoHideDelay: TimeInterval = 2.0
    static let maximumAutoHideDelay: TimeInterval = 60.0

    /// How long to wait before re-checking when auto-hide is deferred because
    /// the pointer is in the menu bar (the user is likely mid-interaction).
    static let autoHideDeferInterval: TimeInterval = 2.0

    // MARK: - Links
    /// Catacolabs home page, linked from the preferences popover.
    static let projectURL = "https://catacolabs.com"
    
    // MARK: - Separator
    /// The normal width of the separator item when icons are visible (expanded).
    /// A thin line so the user can see the boundary.
    static let separatorNormalLength: CGFloat = 20
    
    /// Minimum collapse length (for very small screens or if screen detection fails).
    static let separatorMinCollapseLength: CGFloat = 500

    /// Fallback screen width used when no connected display can be detected
    /// (e.g., during early launch or headless test runs). A common MacBook width.
    static let fallbackScreenWidth: CGFloat = 1728
    
    /// Extra pixels beyond screen width to ensure icons are fully pushed off-screen.
    /// Generous padding so even edge cases are covered.
    static let separatorCollapsePadding: CGFloat = 500

    /// Retry transient status-item placement failures during startup/login.
    static let separatorPositionValidationMaxRetries = 20
    static let separatorPositionValidationRetryDelay: TimeInterval = 0.25
    
    // MARK: - Autosave Names
    /// macOS uses these to remember status item positions across launches.
    static let toggleAutosaveName = "hiddenapp_toggle"
    static let separatorAutosaveName = "hiddenapp_separator"
}
