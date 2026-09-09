import CoreGraphics
import Testing
@testable import hiddenapp

@Suite struct OverlayRegionTests {
    private let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        auxiliaryTopRightMinX: 920
    )
    private let unnotched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        auxiliaryTopRightMinX: nil
    )
    private let barHeight: CGFloat = 24

    @Test func notchedExtrasStartAtAuxiliaryArea() {
        #expect(OverlayRegion.extrasLeadingX(screen: notched) == 920)
    }

    @Test func unnotchedExtrasStartAtMidline() {
        #expect(OverlayRegion.extrasLeadingX(screen: unnotched) == 960)
    }

    @Test func spanCoversFromExtrasLeadingEdgeToSeparator() {
        let region = OverlayRegion.span(
            separatorMinX: 1300,
            screen: notched,
            barHeight: barHeight
        )
        #expect(region.minX == 920)
        #expect(region.maxX == 1300)
        #expect(region.width == 380)
        #expect(region.height == barHeight)
        #expect(region.minY == 982 - barHeight)
    }

    @Test func spanIsEmptyWhenSeparatorIsAtLeadingEdge() {
        let region = OverlayRegion.span(
            separatorMinX: 920,
            screen: notched,
            barHeight: barHeight
        )
        #expect(region == .zero)
    }

    @Test func spanIsEmptyWhenSeparatorIsLeftOfExtras() {
        let region = OverlayRegion.span(
            separatorMinX: 800,
            screen: notched,
            barHeight: barHeight
        )
        #expect(region == .zero)
    }

    @Test func spanIsEmptyWhenBarHeightIsZero() {
        let region = OverlayRegion.span(
            separatorMinX: 1300,
            screen: notched,
            barHeight: 0
        )
        #expect(region == .zero)
    }

    @Test func unnotchedSpanNeverCrossesMidline() {
        let region = OverlayRegion.span(
            separatorMinX: 1700,
            screen: unnotched,
            barHeight: barHeight
        )
        #expect(region.minX == 960)
        #expect(region.maxX == 1700)
    }
}
