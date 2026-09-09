import Foundation
import Testing
@testable import hiddenapp

@Suite struct CollapseModeTests {
    @Test func macos26AndEarlierUseLength() {
        #expect(CollapseMode.mode(forMajorVersion: 15) == .length)
        #expect(CollapseMode.mode(forMajorVersion: 26) == .length)
    }

    @Test func macos27AndLaterUseOverlay() {
        #expect(CollapseMode.mode(forMajorVersion: 27) == .overlay)
        #expect(CollapseMode.mode(forMajorVersion: 28) == .overlay)
    }
}
