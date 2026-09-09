import CoreGraphics

/// Screen facts OverlayRegion needs. Kept as a value type so the maths
/// can be tested without constructing an `NSScreen`.
struct ScreenMetrics: Equatable {
    var frame: CGRect

    /// Leading edge of the status-item area on a notched display
    /// (`NSScreen.auxiliaryTopRightArea.minX`). `nil` on screens without a notch.
    var auxiliaryTopRightMinX: CGFloat?
}

enum OverlayRegion {
    /// Narrowest overlay worth showing. Below this the separator is already
    /// at the extras leading edge and there is nothing to cover.
    static let minimumWidth: CGFloat = 1

    /// On a notched screen the extras live in the top-right auxiliary area.
    /// Without a notch they pack from the trailing edge; the midline is a
    /// conservative bound so we never paint over app menus on the leading half.
    static func extrasLeadingX(screen: ScreenMetrics) -> CGFloat {
        if let extrasMinX = screen.auxiliaryTopRightMinX {
            return extrasMinX
        }
        return screen.frame.midX
    }

    /// Rectangle covering everything in the extras area to the left of the
    /// separator. Empty if the separator sits at or before that leading edge.
    static func span(
        separatorMinX: CGFloat,
        screen: ScreenMetrics,
        barHeight: CGFloat
    ) -> CGRect {
        let minX = extrasLeadingX(screen: screen)
        let width = separatorMinX - minX
        guard width > minimumWidth, barHeight > 0 else { return .zero }
        return CGRect(
            x: minX,
            y: screen.frame.maxY - barHeight,
            width: width,
            height: barHeight
        )
    }
}
