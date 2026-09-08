import Foundation
import Testing
@testable import hiddenapp

@MainActor
@Suite struct AutoHideManagerTests {

    private let defaults: UserDefaults

    init() {
        let suite = "hiddenapp-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

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

        defaults.set(60.0, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }

        manager.setEnabled(true)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        #expect(fired == false)

        manager.setDelay(Constants.minimumAutoHideDelay)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 3.0))
        #expect(fired == true)
    }

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

    @Test func shouldDeferAutoHidePreventsImmediateFiring() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }
        manager.shouldDeferAutoHide = { true }

        manager.startTimer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
        #expect(fired == false)
    }

    @Test func deferredAutoHideFiresOnceDeferConditionClears() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        var shouldDefer = true
        manager.onAutoHide = { fired = true }
        manager.shouldDeferAutoHide = { shouldDefer }

        manager.startTimer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        shouldDefer = false

        RunLoop.main.run(until: Date(timeIntervalSinceNow: Constants.autoHideDeferInterval + 1.0))
        #expect(fired == true)
    }

    @Test func cancelTimerAlsoCancelsDeferredRecheck() {
        let prefs = Preferences(defaults: defaults)
        defaults.set(0.1, forKey: Constants.autoHideDelay)

        let manager = AutoHideManager(preferences: prefs)
        var fired = false
        manager.onAutoHide = { fired = true }
        manager.shouldDeferAutoHide = { false }

        manager.startTimer()
        manager.cancelTimer()

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        #expect(fired == false)
    }
}
