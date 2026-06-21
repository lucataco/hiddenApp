//
//  PreferencesTests.swift
//  hiddenappTests
//
//  Tests for the Preferences wrapper: defaults, clamping, and persistence.
//

import Foundation
import Testing
@testable import hiddenapp

@MainActor
@Suite struct PreferencesTests {
    /// A fresh UserDefaults suite for each test, removed on deinit so tests
    /// don't leak state to each other.
    private let defaults: UserDefaults

    init() {
        let suite = "hiddenapp-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    @Test func autoHideEnabledDefaultsToTrue() {
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.autoHideEnabled == true)
    }

    @Test func autoHideEnabledPersists() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideEnabled = false
        #expect(defaults.bool(forKey: Constants.autoHideEnabled) == false)

        let prefs2 = Preferences(defaults: defaults)
        #expect(prefs2.autoHideEnabled == false)
    }

    @Test func autoHideDelayDefaultsToTenSeconds() {
        let prefs = Preferences(defaults: defaults)
        #expect(prefs.autoHideDelay == 10.0)
    }

    @Test func autoHideDelayClampsToMinimum() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = 0.5
        #expect(prefs.autoHideDelay == Constants.minimumAutoHideDelay)
    }

    @Test func autoHideDelayClampsToMaximum() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = 120.0
        #expect(prefs.autoHideDelay == Constants.maximumAutoHideDelay)
    }

    @Test func autoHideDelayAcceptsInBoundsValue() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = 15.0
        #expect(prefs.autoHideDelay == 15.0)
    }

    @Test func autoHideDelayClampsToMinimumBoundary() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = Constants.minimumAutoHideDelay
        #expect(prefs.autoHideDelay == Constants.minimumAutoHideDelay)
    }

    @Test func autoHideDelayClampsToMaximumBoundary() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = Constants.maximumAutoHideDelay
        #expect(prefs.autoHideDelay == Constants.maximumAutoHideDelay)
    }

    @Test func autoHideDelayPersistsAcrossInstances() {
        let prefs = Preferences(defaults: defaults)
        prefs.autoHideDelay = 30.0

        let prefs2 = Preferences(defaults: defaults)
        #expect(prefs2.autoHideDelay == 30.0)
    }
}
