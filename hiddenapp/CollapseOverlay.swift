import AppKit
import os

/// Paints over the hidden extras zone on macOS 27+.
///
/// Expanding `NSStatusItem.length` no longer pushes neighboring icons off
/// the bar — the surface is a single WindowServer window and an oversized
/// item just spills off the trailing edge.
///
/// macOS 27's "Menubar" WindowServer window sits at main-menu level (24).
/// Status-item level paints *under* it, so these windows use pop-up-menu
/// level. `NSVisualEffectView` at that level renders HUD chrome (a gray
/// box on a transparent bar). `NSGlassEffectView` `.clear` is the same
/// Liquid Glass the system menu bar uses, so it follows wallpaper and
/// light/dark without a tinted wash.
@MainActor
final class CollapseOverlay {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "CollapseOverlay"
    )

    private static let blurLayerCount = 1

    private var blurWindows: [NSWindow] = []
    private var shieldWindow: NSWindow?
    private var lastRegion: CGRect = .null
    nonisolated(unsafe) private var appearanceObserver: NSObjectProtocol?

    var isVisible: Bool { shieldWindow != nil }

    init() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyAppearance()
            }
        }
    }

    deinit {
        if let appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(appearanceObserver)
        }
    }

    func show(region: CGRect) {
        guard region.width > OverlayRegion.minimumWidth else {
            hide()
            return
        }

        if blurWindows.count != Self.blurLayerCount {
            rebuild()
        }

        applyAppearance()

        let baseLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        for (index, window) in blurWindows.enumerated() {
            position(window, region: region, level: baseLevel + index)
        }
        if let shieldWindow {
            position(shieldWindow, region: region, level: baseLevel + Self.blurLayerCount)
        }

        if lastRegion != region {
            lastRegion = region
            logger.info(
                "Showing overlay x=\(region.minX, privacy: .public) w=\(region.width, privacy: .public) dark=\(OverlayAppearance.isSystemDark, privacy: .public)"
            )
        }
    }

    func hide() {
        guard isVisible || !blurWindows.isEmpty else { return }
        blurWindows.forEach { $0.orderOut(nil) }
        shieldWindow?.orderOut(nil)
        blurWindows = []
        shieldWindow = nil
        lastRegion = .null
        logger.info("Hid overlay.")
    }

    func applyAppearance() {
        let appearance = Self.systemBarAppearance()
        for window in blurWindows {
            window.appearance = appearance
            window.contentView?.appearance = appearance
            if #available(macOS 26.0, *), let glass = window.contentView as? NSGlassEffectView {
                glass.style = .clear
                glass.tintColor = nil
                glass.cornerRadius = 0
            }
        }
        shieldWindow?.appearance = appearance
    }

    private static func systemBarAppearance() -> NSAppearance {
        let name: NSAppearance.Name = OverlayAppearance.isSystemDark ? .darkAqua : .aqua
        return NSAppearance(named: name) ?? NSApp.effectiveAppearance
    }

    private func rebuild() {
        hide()

        let appearance = Self.systemBarAppearance()
        blurWindows = (0..<Self.blurLayerCount).map { _ in
            let window = makeWindow()
            window.contentView = Self.makeGlassContent()
            window.appearance = appearance
            window.contentView?.appearance = appearance
            return window
        }

        let shield = makeWindow()
        shield.ignoresMouseEvents = false
        shield.appearance = appearance
        shieldWindow = shield
    }

    private static func makeGlassContent() -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: .zero)
            glass.style = .clear
            glass.cornerRadius = 0
            glass.tintColor = nil
            glass.autoresizingMask = [.width, .height]
            let filler = NSView(frame: .zero)
            filler.autoresizingMask = [.width, .height]
            glass.contentView = filler
            return glass
        }

        let effect = NSVisualEffectView(frame: .zero)
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        return effect
    }

    private func position(_ window: NSWindow, region: CGRect, level: Int) {
        window.setFrame(region, display: true)
        window.level = NSWindow.Level(rawValue: level)
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.isExcludedFromWindowsMenu = true
        window.animationBehavior = .none
        return window
    }
}
