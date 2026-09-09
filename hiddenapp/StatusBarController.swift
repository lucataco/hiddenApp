import AppKit
import os
import Sparkle
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "StatusBarController"
    )

    private var toggleItem: NSStatusItem!

    private var separatorItem: NSStatusItem!

    private let preferences = Preferences()
    private let autoHideManager: AutoHideManager
    private let updaterController: SPUStandardUpdaterController

    private(set) var isCollapsed = false

    private var collapseLength: CGFloat = 2000

    private let overlay = CollapseOverlay()

    nonisolated(unsafe) private var overlayRefreshTimer: Timer?

    nonisolated(unsafe) private var screenObserver: NSObjectProtocol?

    nonisolated(unsafe) private var pendingCollapseRetry: DispatchWorkItem?

    private var contextMenu: NSMenu!
    private var preferencesPopover: NSPopover?
    private var welcomePopover: NSPopover?

    nonisolated(unsafe) private var rightClickMonitor: Any?

    private var isShowingPositionAlert = false

    override init() {
        autoHideManager = AutoHideManager(preferences: preferences)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()

        setupToggleItem()
        setupSeparatorItem()
        setupContextMenu()
        setupRightClickMonitor()
        setupAutoHide()
        setupScreenObserver()
        updateCollapseLength()
        startInitialAutoHideTimer()
        showWelcomeIfNeeded()
    }

    deinit {
        pendingCollapseRetry?.cancel()
        overlayRefreshTimer?.invalidate()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
    }

    private func setupToggleItem() {
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = Constants.toggleAutosaveName

        guard let button = toggleItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "chevron.right",
            accessibilityDescription: nil
        )
        button.image?.size = NSSize(width: 12, height: 12)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggleClicked(_:))
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = String(localized: "Hide menu bar icons — right-click for preferences")

        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(String(localized: "HiddenApp"))
        button.setAccessibilityHelp(String(localized: "Click to show or hide menu bar icons"))
    }

    private func setupSeparatorItem() {
        separatorItem = NSStatusBar.system.statusItem(withLength: Constants.separatorNormalLength)
        separatorItem.autosaveName = Constants.separatorAutosaveName

        guard let button = separatorItem.button else { return }

        button.image = makeSeparatorImage()
        button.imagePosition = .imageOnly

        button.appearsDisabled = true
        button.toolTip = String(localized: "Hold ⌘ and drag icons to the left of this line to hide them")

        button.setAccessibilityRole(.image)
        button.setAccessibilityLabel(String(localized: "Separator"))
    }

    private func makeSeparatorImage() -> NSImage {
        let height: CGFloat = 16
        let width: CGFloat = 2
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            NSColor.tertiaryLabelColor.setFill()
            let lineRect = NSRect(x: 0, y: 2, width: 1, height: height - 4)
            lineRect.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    private func setupContextMenu() {
        contextMenu = NSMenu()

        let updateItem = NSMenuItem(
            title: String(localized: "Check for Updates…"),
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = updaterController
        contextMenu.addItem(updateItem)

        contextMenu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: String(localized: "Preferences…"),
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        contextMenu.addItem(prefsItem)

        contextMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: String(localized: "Quit HiddenApp"),
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    private func setupRightClickMonitor() {

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard let button = self.toggleItem.button else { return event }
            guard let buttonWindow = button.window else { return event }

            let isContextClick = event.type == .rightMouseDown
                || event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.control)
            guard isContextClick else { return event }

            if event.window === buttonWindow {
                self.contextMenu.popUp(
                    positioning: nil,
                    at: NSPoint(x: 0, y: button.bounds.height + 5),
                    in: button
                )
                return nil
            }
            return event
        }
    }

    private func setupAutoHide() {
        autoHideManager.onAutoHide = { [weak self] in
            self?.collapse()
        }

        autoHideManager.shouldDeferAutoHide = { [weak self] in
            self?.isPointerInMenuBar ?? false
        }
    }

    private var isPointerInMenuBar: Bool {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let frame = screen.frame

            let menuBarHeight = max(
                frame.maxY - screen.visibleFrame.maxY,
                NSStatusBar.system.thickness
            )
            let menuBarRect = NSRect(
                x: frame.minX,
                y: frame.maxY - menuBarHeight,
                width: frame.width,
                height: menuBarHeight
            )
            return menuBarRect.contains(location)
        }
    }

    private func startInitialAutoHideTimer() {

        DispatchQueue.main.async { [weak self] in
            self?.autoHideManager.startTimer()
        }
    }

    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            MainActor.assumeIsolated {
                self.handleScreenChange()
            }
        }
    }

    private func updateCollapseLength() {

        let separatorScreenWidth = separatorItem.button?.window?.screen?.frame.width
        let widestScreenWidth = NSScreen.screens.map(\.frame.width).max()
        let screenWidth = max(separatorScreenWidth ?? 0, widestScreenWidth ?? Constants.fallbackScreenWidth)

        collapseLength = max(
            Constants.separatorMinCollapseLength,
            screenWidth + Constants.separatorCollapsePadding
        )
    }

    private var isSeparatorValidPosition: Bool {
        guard
            let toggleX = toggleItem.button?.window?.frame.origin.x,
            let separatorX = separatorItem.button?.window?.frame.origin.x
        else {
            return false
        }

        let layoutDirection = toggleItem.button?.userInterfaceLayoutDirection
            ?? NSApp.userInterfaceLayoutDirection
        if layoutDirection == .rightToLeft {
            return separatorX >= toggleX
        }
        return toggleX >= separatorX
    }

    func collapse(userInitiated: Bool = false) {
        attemptCollapse(
            retriesRemaining: Constants.separatorPositionValidationMaxRetries,
            userInitiated: userInitiated
        )
    }

    private func attemptCollapse(retriesRemaining: Int, userInitiated: Bool = false) {
        guard !isCollapsed else { return }
        guard isSeparatorValidPosition else {

            if userInitiated {
                logger.error("User-initiated collapse failed: separator is not to the left of the toggle.")
                showSeparatorPositionAlert()
                return
            }
            scheduleCollapseRetry(retriesRemaining: retriesRemaining)
            return
        }

        pendingCollapseRetry?.cancel()
        pendingCollapseRetry = nil

        if retriesRemaining < Constants.separatorPositionValidationMaxRetries {
            logger.info("Collapse retry succeeded after status-item positions became valid.")
        }

        updateCollapseLength()

        isCollapsed = true
        applyCollapsedPresentation()
        updateChevron()

        autoHideManager.cancelTimer()
    }

    private func scheduleCollapseRetry(retriesRemaining: Int) {
        pendingCollapseRetry?.cancel()

        let toggleX = toggleItem.button?.window?.frame.origin.x
        let separatorX = separatorItem.button?.window?.frame.origin.x

        guard retriesRemaining > 0 else {
            logger.error(
                "Unable to collapse hidden icons because separator position is invalid. toggleX=\(String(describing: toggleX), privacy: .public), separatorX=\(String(describing: separatorX), privacy: .public)"
            )
            return
        }

        if retriesRemaining == Constants.separatorPositionValidationMaxRetries {
            logger.warning(
                "Separator position is not ready or invalid; retrying collapse. retriesRemaining=\(retriesRemaining, privacy: .public), toggleX=\(String(describing: toggleX), privacy: .public), separatorX=\(String(describing: separatorX), privacy: .public)"
            )
        } else {
            logger.debug(
                "Retrying collapse while separator position remains invalid. retriesRemaining=\(retriesRemaining, privacy: .public), toggleX=\(String(describing: toggleX), privacy: .public), separatorX=\(String(describing: separatorX), privacy: .public)"
            )
        }

        let retry = DispatchWorkItem { [weak self] in
            self?.pendingCollapseRetry = nil
            self?.attemptCollapse(retriesRemaining: retriesRemaining - 1)
        }

        pendingCollapseRetry = retry
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.separatorPositionValidationRetryDelay,
            execute: retry
        )
    }

    private func showSeparatorPositionAlert() {
        guard !isShowingPositionAlert else { return }
        isShowingPositionAlert = true
        defer { isShowingPositionAlert = false }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "HiddenApp can't hide icons")
        alert.informativeText = String(
            localized: "The | separator must be to the left of the chevron. Hold ⌘ and drag the | separator to the left of the chevron, then try again."
        )
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate()
        alert.runModal()
    }

    func expand() {
        guard isCollapsed else { return }

        isCollapsed = false
        applyExpandedPresentation()
        updateChevron()

        autoHideManager.startTimer()
    }

    func prepareForTermination() {
        pendingCollapseRetry?.cancel()
        pendingCollapseRetry = nil

        if isCollapsed {
            isCollapsed = false
            applyExpandedPresentation()
            updateChevron()
        }

        autoHideManager.cancelTimer()
    }

    func toggle() {
        if isCollapsed {
            expand()
        } else {
            collapse(userInitiated: true)
        }
    }

    private func handleScreenChange() {

        updateCollapseLength()

        if isCollapsed {
            applyCollapsedPresentation()
        }
    }

    private var usesOverlayCollapse: Bool {
        CollapseMode.current == .overlay
    }

    private func applyCollapsedPresentation() {
        if usesOverlayCollapse {
            separatorItem.length = Constants.separatorNormalLength
            refreshOverlay()
            startOverlayRefresh()
        } else {
            overlay.hide()
            stopOverlayRefresh()
            separatorItem.length = collapseLength
        }
    }

    private func applyExpandedPresentation() {
        overlay.hide()
        stopOverlayRefresh()
        separatorItem.length = Constants.separatorNormalLength
    }

    private func refreshOverlay() {
        guard usesOverlayCollapse, isCollapsed else {
            overlay.hide()
            return
        }
        guard let separatorMinX = separatorItem.button?.window?.frame.minX else {
            logger.error("Cannot place overlay: separator has no window frame.")
            overlay.hide()
            return
        }

        let nsScreen = separatorItem.button?.window?.screen
            ?? NSScreen.main
        guard let nsScreen else {
            overlay.hide()
            return
        }

        let menuBarHeight = nsScreen.frame.maxY - nsScreen.visibleFrame.maxY
        // Autohidden / fullscreen: visibleFrame already fills the display.
        // Do not fall back to NSStatusBar.thickness — that would paint a
        // click-eating strip over the desktop.
        guard menuBarHeight > OverlayRegion.minimumWidth else {
            overlay.hide()
            return
        }

        let hiddenMinX: CGFloat?
        if ExtraItemFrames.isTrusted {
            hiddenMinX = ExtraItemFrames.hiddenMinX(
                separatorMinX: separatorMinX,
                excludingBundleID: Bundle.main.bundleIdentifier
            )
            if hiddenMinX == nil {
                overlay.hide()
                return
            }
        } else {
            hiddenMinX = nil
        }

        let metrics = ScreenMetrics(
            frame: nsScreen.frame,
            auxiliaryTopRightMinX: nsScreen.auxiliaryTopRightArea?.minX
        )
        let region = OverlayRegion.span(
            separatorMinX: separatorMinX,
            hiddenMinX: hiddenMinX,
            screen: metrics,
            barHeight: menuBarHeight
        )
        overlay.show(region: region)
    }

    private func startOverlayRefresh() {
        guard usesOverlayCollapse else { return }
        if overlayRefreshTimer != nil { return }
        overlayRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.overlayRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshOverlay()
            }
        }
        overlayRefreshTimer?.tolerance = 0.25
    }

    private func stopOverlayRefresh() {
        overlayRefreshTimer?.invalidate()
        overlayRefreshTimer = nil
    }

    private func updateChevron() {
        let symbolName = isCollapsed ? "chevron.left" : "chevron.right"
        toggleItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
        toggleItem.button?.image?.size = NSSize(width: 12, height: 12)
        toggleItem.button?.toolTip = isCollapsed
            ? String(localized: "Show hidden menu bar icons — right-click for preferences")
            : String(localized: "Hide menu bar icons — right-click for preferences")
        toggleItem.button?.setAccessibilityValue(
            isCollapsed
                ? String(localized: "hidden")
                : String(localized: "shown")
        )
    }

    @objc private func toggleClicked(_ sender: Any?) {
        toggle()
    }

    @objc private func showPreferences(_ sender: Any?) {
        if let popover = preferencesPopover, popover.isShown {
            popover.performClose(sender)
            return
        }

        expand()
        autoHideManager.cancelTimer()

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 240)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let prefsView = PreferencesView(preferences: preferences, autoHideManager: autoHideManager)
        popover.contentViewController = NSHostingController(rootView: prefsView)

        if let button = toggleItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        preferencesPopover = popover
    }

    private func showWelcomeIfNeeded() {
        guard !preferences.hasCompletedOnboarding else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let button = self.toggleItem.button else { return }
            guard self.welcomePopover == nil else { return }

            self.autoHideManager.cancelTimer()

            let popover = NSPopover()
            popover.behavior = .transient
            popover.animates = true
            popover.delegate = self

            let welcomeView = WelcomeView { [weak self] in
                self?.welcomePopover?.performClose(nil)
            }
            popover.contentViewController = NSHostingController(rootView: welcomeView)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            self.welcomePopover = popover
            self.logger.info("Showing first-run welcome popover.")
        }
    }

    @objc private func quitApp(_ sender: Any?) {
        prepareForTermination()
        NSApplication.shared.terminate(nil)
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover else { return }

        if popover === welcomePopover {
            welcomePopover = nil

            preferences.hasCompletedOnboarding = true
            logger.info("First-run welcome popover dismissed; onboarding complete.")
        }

        if popover === preferencesPopover {
            preferencesPopover = nil
        }

        if !isCollapsed {
            autoHideManager.startTimer()
        }
    }
}
