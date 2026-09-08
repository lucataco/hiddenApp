import Foundation
import os

@MainActor
final class AutoHideManager {

    var onAutoHide: (() -> Void)?

    var shouldDeferAutoHide: (() -> Bool)?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "AutoHideManager"
    )

    private let preferences: Preferences
    private var timer: Timer?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var isEnabled: Bool { preferences.autoHideEnabled }

    var delay: TimeInterval { preferences.autoHideDelay }

    func setEnabled(_ enabled: Bool) {
        preferences.autoHideEnabled = enabled
        logger.info("Auto-hide enabled set to \(enabled, privacy: .public).")
        if enabled {
            startTimer()
        } else {
            cancelTimer()
        }
    }

    func setDelay(_ newDelay: TimeInterval) {
        preferences.autoHideDelay = newDelay
        logger.info("Auto-hide delay set to \(self.preferences.autoHideDelay, privacy: .public) seconds.")
        if isEnabled {
            startTimer()
        }
    }

    func startTimer() {
        cancelTimer()
        guard isEnabled else { return }

        logger.debug("Starting auto-hide timer for \(self.delay, privacy: .public) seconds.")
        scheduleTimer(after: delay)
    }

    private func scheduleTimer(after interval: TimeInterval) {
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }

            MainActor.assumeIsolated {
                self.timerFired()
            }
        }

        timer?.tolerance = max(0.5, interval * 0.1)
    }

    private func timerFired() {

        if shouldDeferAutoHide?() == true {
            logger.debug("Auto-hide deferred; pointer is in the menu bar. Re-checking shortly.")
            scheduleTimer(after: Constants.autoHideDeferInterval)
            return
        }

        logger.debug("Auto-hide timer fired.")
        timer = nil
        onAutoHide?()
    }

    func cancelTimer() {
        guard timer != nil else { return }
        logger.debug("Cancelling auto-hide timer.")
        timer?.invalidate()
        timer = nil
    }
}
