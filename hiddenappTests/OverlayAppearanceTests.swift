import Foundation
import Testing
@testable import hiddenapp

@Suite struct OverlayAppearanceTests {
    @Test func nilStyleIsLight() {
        #expect(OverlayAppearance.isSystemDark(appleInterfaceStyle: nil) == false)
    }

    @Test func emptyStyleIsLight() {
        #expect(OverlayAppearance.isSystemDark(appleInterfaceStyle: "") == false)
    }

    @Test func darkStyleIsDark() {
        #expect(OverlayAppearance.isSystemDark(appleInterfaceStyle: "Dark") == true)
    }

    @Test func lightKeywordIsNotDark() {
        #expect(OverlayAppearance.isSystemDark(appleInterfaceStyle: "Light") == false)
    }
}
