//
//  AutoHideManager.swift
//  hiddenapp
//
//  Manages a timer that automatically collapses (hides) menu bar icons
//  after a configurable delay when the user has expanded them.
//

import Foundation
import os

@MainActor
final class AutoHideManager {

    /// Called when the auto-hide timer fires and icons should be collapsed.
    var onAutoHide: (() -> Void)?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "AutoHideManager"
    )

    private let preferences: Preferences
    private var timer: Timer?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    // MARK: - Public API

    /// Whether auto-hide is enabled. Reads from ``Preferences``.
    var isEnabled: Bool { preferences.autoHideEnabled }

    /// The auto-hide delay in seconds. Reads from ``Preferences``.
    var delay: TimeInterval { preferences.autoHideDelay }

    /// Update the auto-hide enabled flag, persist it, and start/stop the timer.
    func setEnabled(_ enabled: Bool) {
        preferences.autoHideEnabled = enabled
        logger.info("Auto-hide enabled set to \(enabled, privacy: .public).")
        if enabled {
            startTimer()
        } else {
            cancelTimer()
        }
    }

    /// Update the auto-hide delay, persist it (clamped), and restart the timer
    /// if auto-hide is currently enabled.
    func setDelay(_ newDelay: TimeInterval) {
        preferences.autoHideDelay = newDelay
        logger.info("Auto-hide delay set to \(self.preferences.autoHideDelay, privacy: .public) seconds.")
        if isEnabled {
            startTimer()
        }
    }

    /// Start the auto-hide countdown. Call this when icons are revealed.
    /// If auto-hide is disabled, this does nothing.
    func startTimer() {
        cancelTimer()
        guard isEnabled else { return }

        logger.debug("Starting auto-hide timer for \(self.delay, privacy: .public) seconds.")
        timer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.logger.debug("Auto-hide timer fired.")
            self?.onAutoHide?()
        }
        // Allow the OS to coalesce this non-strict timer with other work,
        // saving energy on a menu-bar utility that runs continuously.
        timer?.tolerance = max(0.5, delay * 0.1)
    }

    /// Cancel any running auto-hide timer. Call this when the user
    /// manually collapses icons or when the app is about to quit.
    func cancelTimer() {
        guard timer != nil else { return }
        logger.debug("Cancelling auto-hide timer.")
        timer?.invalidate()
        timer = nil
    }
}
