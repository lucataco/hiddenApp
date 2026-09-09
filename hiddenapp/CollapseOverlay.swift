import AppKit
import os

/// Paints over the hidden extras zone on macOS 27+.
///
/// Expanding `NSStatusItem.length` no longer pushes neighboring icons off
/// the bar — the surface is a single WindowServer window and an oversized
/// item just spills off the trailing edge. Covering the zone with stacked
/// `NSVisualEffectView`s lets the compositor blur the icons out. No Screen
/// Recording permission, no private API.
///
/// macOS 27's "Menubar" WindowServer window sits at main-menu level (24).
/// Status-item level (25) paints *under* it, so these panels use pop-up-menu
/// level, which composites above the bar.
@MainActor
final class CollapseOverlay {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "CollapseOverlay"
    )

    private static let blurLayerCount = 2

    private var blurWindows: [NSWindow] = []
    private var washWindow: NSWindow?
    private var shieldWindow: NSWindow?
    private var lastRegion: CGRect = .null

    var isVisible: Bool { shieldWindow != nil }

    func show(region: CGRect) {
        guard region.width > OverlayRegion.minimumWidth else {
            hide()
            return
        }

        if blurWindows.count != Self.blurLayerCount {
            rebuild()
        }

        let baseLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        for (index, window) in blurWindows.enumerated() {
            position(window, region: region, level: baseLevel + index)
        }
        if let washWindow {
            position(washWindow, region: region, level: baseLevel + Self.blurLayerCount)
        }
        if let shieldWindow {
            position(shieldWindow, region: region, level: baseLevel + Self.blurLayerCount + 1)
        }

        if lastRegion != region {
            lastRegion = region
            logger.info(
                "Showing overlay x=\(region.minX, privacy: .public) w=\(region.width, privacy: .public)"
            )
        }
    }

    func hide() {
        guard isVisible || !blurWindows.isEmpty else { return }
        blurWindows.forEach { $0.orderOut(nil) }
        washWindow?.orderOut(nil)
        shieldWindow?.orderOut(nil)
        blurWindows = []
        washWindow = nil
        shieldWindow = nil
        lastRegion = .null
        logger.info("Hid overlay.")
    }

    private func rebuild() {
        hide()

        blurWindows = (0..<Self.blurLayerCount).map { _ in
            let window = makePanel()
            let effect = NSVisualEffectView(frame: .zero)
            effect.material = .menu
            effect.blendingMode = .behindWindow
            effect.state = .active
            window.contentView = effect
            return window
        }

        let wash = makePanel()
        wash.backgroundColor = washColor
        wash.isOpaque = false
        washWindow = wash

        // Eats clicks so hidden icons cannot be activated while collapsed.
        let shield = makePanel()
        shield.ignoresMouseEvents = false
        shieldWindow = shield
    }

    private func position(_ window: NSWindow, region: CGRect, level: Int) {
        window.setFrame(region, display: true)
        window.level = NSWindow.Level(rawValue: level)
        window.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        return panel
    }

    private var washColor: NSColor {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isDark {
            return NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.12)
        }
        return NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 0.12)
    }
}
