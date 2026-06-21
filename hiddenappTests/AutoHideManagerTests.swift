//
//  AutoHideManagerTests.swift
//  hiddenappTests
//
//  Tests for AutoHideManager: enable/disable, delay persistence, and timer
//  lifecycle (start, cancel, fire).
//

import Foundation
import Testing
@testable import hiddenapp

@MainActor
@Suite struct AutoHideManagerTests {
    /// A fresh UserDefaults suite for each test, UUID-named to prevent
    /// cross-test contamination.
    private let defaults: UserDefaults

    init() {
        let suite = "hiddenapp-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    // MARK: - State mirroring

    @Test func isEnabledReflectsPreferences() {
        let prefs = Preferences(defaults: defaults)
        let manager = AutoHideManager(preferences: prefs)
        #expect(manager.isEnabled == true)

        prefs.autoHideEnabled = false
        #expect(manager.isEnabled == false)
    }

    @Test func delayReflectsPreferences() {
        let prefs = Preferences(defaults: defaults)
        let manager = AutoHideManager(preferences: prefs)
        #expect(manager.delay == 10.0)

        prefs.autoHideDelay = 20.0
        #expect(manager.delay == 20.0)
    }

    // MARK: - setEnabled

    @Test func setEnabledPersistsToPreferences() {
        let prefs = Preferences(defaults: defaults)
        let manager = AutoHideManager(preferences: prefs)

        manager.setEnabled(false)
        #expect(prefs.autoHideEnabled == false)

        manager.setEnabled(true)
        #expect(prefs.autoHideEnabled == true)
    }

    @Test func setEnabledFalseCancelsPendingTimer() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.setEnabled(true)
        manager.setEnabled(false)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        #expect(fired == false)
    }

    // MARK: - setDelay

    @Test func setDelayPersistsClampedToPreferences() {
        let prefs = Preferences(defaults: defaults)
        let manager = AutoHideManager(preferences: prefs)

        manager.setDelay(0.5)
        #expect(prefs.autoHideDelay == Constants.minimumAutoHideDelay)

        manager.setDelay(120.0)
        #expect(prefs.autoHideDelay == Constants.maximumAutoHideDelay)
    }

    @Test func setDelayRestartsTimerWhenEnabled() {
        let prefs = Preferences(defaults: defaults)
        // Start with a long delay so the first timer won't fire quickly.
        defaults.set(60.0, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.setEnabled(true)

        // With a 60s delay the callback should not fire in 0.3s.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        #expect(fired == false)

        // setDelay clamps to the minimum (2.0s) and restarts the timer.
        manager.setDelay(Constants.minimumAutoHideDelay)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.0))
        #expect(fired == true)
    }

    // MARK: - Timer lifecycle

    @Test func startTimerDoesNothingWhenDisabled() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideEnabled = false

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.startTimer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        #expect(fired == false)
    }

    @Test func cancelTimerPreventsCallbackFromFiring() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.setEnabled(true)
        manager.cancelTimer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        #expect(fired == false)
    }

    @Test func timerFiresOnAutoHideCallback() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.setEnabled(true)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        #expect(fired == true)
    }
}
