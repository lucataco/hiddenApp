//
//  ConstantsTests.swift
//  hiddenappTests
//
//  Sanity checks for Constants values that other tests depend on.
//

import CoreGraphics
import Foundation
import Testing
@testable import hiddenapp

@Suite struct ConstantsTests {
    @Test func defaultAutoHideDelayIsWithinBounds() {
        #expect(Constants.defaultAutoHideDelay >= Constants.minimumAutoHideDelay)
        #expect(Constants.defaultAutoHideDelay <= Constants.maximumAutoHideDelay)
    }

    @Test func separatorNormalLengthIsPositive() {
        #expect(Constants.separatorNormalLength > 0)
    }

    @Test func separatorMinCollapseLengthExceedsNormalLength() {
        #expect(Constants.separatorMinCollapseLength > Constants.separatorNormalLength)
    }

    @Test func separatorCollapsePaddingIsPositive() {
        #expect(Constants.separatorCollapsePadding > 0)
    }

    @Test func fallbackScreenWidthIsPositive() {
        #expect(Constants.fallbackScreenWidth > 0)
    }

    @Test func retryConfigIsSane() {
        #expect(Constants.separatorPositionValidationMaxRetries > 0)
        #expect(Constants.separatorPositionValidationRetryDelay > 0)
    }
}
