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
    /// Narrowest overlay worth showing.
    static let minimumWidth: CGFloat = 1

    /// Pad around a measured hidden-icon block so the plate doesn't clip glyphs.
    static let iconPad: CGFloat = 3

    /// When icon frames are unknown, cover this much immediately left of the
    /// separator — extras pack against `|`. Do not stretch to the notch:
    /// that empty glass is what read as a second plate.
    static let fallbackPackedWidth: CGFloat = 80

    static func extrasLeadingX(screen: ScreenMetrics) -> CGFloat {
        if let extrasMinX = screen.auxiliaryTopRightMinX {
            return extrasMinX
        }
        return screen.frame.midX
    }

    /// Overlay for hidden extras packed against the separator.
    ///
    /// `hiddenMinX` is the leading edge of the leftmost extra that should be
    /// covered (from Accessibility). `nil` uses `fallbackPackedWidth`.
    static func span(
        separatorMinX: CGFloat,
        hiddenMinX: CGFloat? = nil,
        screen: ScreenMetrics,
        barHeight: CGFloat
    ) -> CGRect {
        let extrasMinX = extrasLeadingX(screen: screen)
        let proposedMinX: CGFloat
        if let hiddenMinX {
            proposedMinX = hiddenMinX - iconPad
        } else {
            proposedMinX = separatorMinX - fallbackPackedWidth
        }
        let minX = max(extrasMinX, proposedMinX)
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
