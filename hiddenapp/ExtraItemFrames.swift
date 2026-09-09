import ApplicationServices
import AppKit

/// Status-item frames in the extras menu bar, via Accessibility.
///
/// On macOS 27 extras are not independent windows. AX is how we learn where
/// icons actually sit so the overlay covers that block and not empty glass.
enum ExtraItemFrames {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestTrust() -> Bool {
        let opts = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    /// AppKit coordinates (origin bottom-left), extras whose midX is left of
    /// `separatorMinX`. Skips this app's own separator/chevron.
    static func hiddenMinX(
        separatorMinX: CGFloat,
        excludingBundleID: String?
    ) -> CGFloat? {
        frames(excludingBundleID: excludingBundleID)
            .filter { $0.midX < separatorMinX && $0.width > 1 && $0.width < 400 }
            .map(\.minX)
            .min()
    }

    private static func frames(excludingBundleID: String?) -> [CGRect] {
        var out: [CGRect] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy != .prohibited else { continue }
            if let excludingBundleID, app.bundleIdentifier == excludingBundleID {
                continue
            }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            guard let bar = copy(axApp, "AXExtrasMenuBar") else { continue }
            guard let children = copy(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement] else {
                continue
            }
            for child in children {
                if let frame = frameOf(child) {
                    out.append(frame)
                }
            }
        }
        return out
    }

    private static func copy(_ el: AXUIElement, _ attr: String) -> AnyObject? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func frameOf(_ el: AXUIElement) -> CGRect? {
        guard let posV = copy(el, kAXPositionAttribute),
              let sizeV = copy(el, kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posV as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeV as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        let screen = NSScreen.screens.first {
            $0.frame.minX <= origin.x && origin.x < $0.frame.maxX
        } ?? NSScreen.main
        guard let screen else { return nil }
        let flippedY = screen.frame.maxY - origin.y - size.height
        return CGRect(x: origin.x, y: flippedY, width: size.width, height: size.height)
    }
}
