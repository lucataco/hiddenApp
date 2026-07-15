//
//  StatusBarController.swift
//  hiddenapp
//
//  Manages two NSStatusItems in the menu bar:
//    1. Toggle (chevron) — the button the user clicks to hide/show icons
//    2. Separator        — an expandable item whose width pushes icons off-screen
//
//  When collapsed, the separator item's length is set to ~screenWidth,
//  pushing all status items to its LEFT off the left edge of the screen.
//  macOS naturally clips items that don't fit. No overlay window needed.
//
//  Layout (left to right):
//    [Apple] [App Menus] ... [hidden icons] [|] [<] [visible icons] [system] [clock]
//                                            ^    ^
//                                     separator  toggle
//

import AppKit
import os
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "StatusBarController"
    )
    
    // MARK: - Status Items
    
    /// The chevron toggle button. Always visible, to the RIGHT of the separator.
    /// Created first so macOS positions it further right in the menu bar.
    private var toggleItem: NSStatusItem!
    
    /// The expandable separator. Normally a thin line (~20px).
    /// When collapsed, expands to ~screenWidth to push items off-screen.
    /// Created second so macOS positions it to the LEFT of the toggle.
    private var separatorItem: NSStatusItem!
    
    // MARK: - Core Components
    
    private let preferences = Preferences()
    private let autoHideManager: AutoHideManager
    
    // MARK: - State
    
    /// `true` = icons to the left of the separator are hidden (pushed off-screen).
    private(set) var isCollapsed = false
    
    /// The computed length to set on the separator when collapsing.
    /// Dynamically based on screen width.
    private var collapseLength: CGFloat = 2000
    
    /// Observation for screen parameter changes.
    private var screenObserver: NSObjectProtocol?

    /// Pending retry for a collapse attempt that raced status-item placement.
    private var pendingCollapseRetry: DispatchWorkItem?
    
    // MARK: - Right-click Menu & Popovers
    
    private var contextMenu: NSMenu!
    private var preferencesPopover: NSPopover?
    private var welcomePopover: NSPopover?
    private var rightClickMonitor: Any?

    /// True when the wrong-side-separator alert is already on screen,
    /// preventing duplicate alerts from queued retries.
    private var isShowingPositionAlert = false
    
    // MARK: - Initialization
    
    override init() {
        autoHideManager = AutoHideManager(preferences: preferences)
        super.init()

        // Order matters: toggle is created first so it's placed further right.
        // Separator is created second so it's placed to the toggle's left.
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
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
    }
    
    // MARK: - Setup
    
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

        // Accessibility: announce as a button with a descriptive label and hint.
        button.setAccessibilityRole(.button)
        button.setAccessibilityLabel(String(localized: "HiddenApp"))
        button.setAccessibilityHelp(String(localized: "Click to show or hide menu bar icons"))
    }

    private func setupSeparatorItem() {
        separatorItem = NSStatusBar.system.statusItem(withLength: Constants.separatorNormalLength)
        separatorItem.autosaveName = Constants.separatorAutosaveName

        guard let button = separatorItem.button else { return }

        // Draw a thin vertical line as the separator visual
        button.image = makeSeparatorImage()
        button.imagePosition = .imageOnly
        // The separator button itself doesn't need an action — it's just a visual divider.
        // Users drag other status items around it to decide which get hidden.
        button.appearsDisabled = true
        button.toolTip = String(localized: "Hold ⌘ and drag icons to the left of this line to hide them")

        // Accessibility: the separator is decorative. Announce it as an image
        // with a simple label so VoiceOver users know what it is.
        button.setAccessibilityRole(.image)
        button.setAccessibilityLabel(String(localized: "Separator"))
    }
    
    /// Create a thin vertical line image for the separator.
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
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self else { return event }
            guard let button = self.toggleItem.button else { return event }
            guard let buttonWindow = button.window else { return event }
            
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
        // Don't yank icons away while the user is interacting with the menu
        // bar (e.g. another status item's menu is open, or they're mid-drag).
        autoHideManager.shouldDeferAutoHide = { [weak self] in
            self?.isPointerInMenuBar ?? false
        }
    }

    /// Whether the mouse pointer is currently inside the menu bar strip of
    /// any connected screen. Used to defer auto-hide during interaction.
    private var isPointerInMenuBar: Bool {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            let frame = screen.frame
            // The menu bar occupies the strip between the screen's top edge
            // and its visibleFrame. Fall back to the status bar thickness
            // (e.g. when the menu bar is set to auto-hide).
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
        // A login-launch starts expanded but never calls expand(), so schedule
        // the same auto-hide countdown once the status items have joined the bar.
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
            self?.handleScreenChange()
        }
    }
    
    // MARK: - Collapse Length Calculation
    
    /// Compute how wide the separator needs to be to push all items off-screen.
    /// Uses the WIDEST connected screen (not just NSScreen.main) to handle
    /// multi-monitor setups where the menu bar may appear on an ultrawide display.
    /// No upper cap — a wider separator is harmless (macOS just clips it).
    private func updateCollapseLength() {
        // Try the actual screen the separator lives on first, fall back to widest screen
        let separatorScreenWidth = separatorItem.button?.window?.screen?.frame.width
        let widestScreenWidth = NSScreen.screens.map(\.frame.width).max()
        let screenWidth = max(separatorScreenWidth ?? 0, widestScreenWidth ?? Constants.fallbackScreenWidth)
        
        collapseLength = max(
            Constants.separatorMinCollapseLength,
            screenWidth + Constants.separatorCollapsePadding
        )
    }
    
    // MARK: - Position Validation
    
    /// Ensure the separator item is positioned to the LEFT of the toggle item.
    /// macOS places status items right-to-left based on creation order, but the
    /// user can drag them around. If they're in the wrong order, collapsing
    /// would push the wrong icons off-screen.
    private var isSeparatorValidPosition: Bool {
        guard
            let toggleX = toggleItem.button?.window?.frame.origin.x,
            let separatorX = separatorItem.button?.window?.frame.origin.x
        else {
            return false
        }
        // In LTR layout, the separator should be to the LEFT (lower x) of the toggle.
        return toggleX >= separatorX
    }
    
    // MARK: - Toggle Logic
    
    /// Collapse: push icons to the left of the separator off-screen.
    /// - Parameter userInitiated: `true` when the user explicitly clicked the
    ///   chevron. Enables visible feedback if the collapse can't proceed
    ///   because the separator was dragged to the wrong side of the toggle.
    func collapse(userInitiated: Bool = false) {
        attemptCollapse(
            retriesRemaining: Constants.separatorPositionValidationMaxRetries,
            userInitiated: userInitiated
        )
    }

    private func attemptCollapse(retriesRemaining: Int, userInitiated: Bool = false) {
        guard !isCollapsed else { return }
        guard isSeparatorValidPosition else {
            // A user-initiated click should fail fast with visible feedback —
            // if the positions are wrong now, retrying won't fix them (only
            // the user dragging the separator back will).
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
        
        // Recompute collapse length at collapse time so it always reflects
        // the current display configuration (handles monitor connect/disconnect,
        // menu bar moving between screens, etc.)
        updateCollapseLength()
        
        isCollapsed = true
        separatorItem.length = collapseLength
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

    /// Tell the user why hiding isn't working and how to fix it, instead of
    /// failing silently into the log.
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
    
    /// Expand: restore the separator to its normal thin width, revealing hidden icons.
    func expand() {
        guard isCollapsed else { return }
        
        isCollapsed = false
        separatorItem.length = Constants.separatorNormalLength
        updateChevron()
        
        autoHideManager.startTimer()
    }

    /// Reveal icons during app shutdown without scheduling another auto-hide timer.
    func prepareForTermination() {
        pendingCollapseRetry?.cancel()
        pendingCollapseRetry = nil

        if isCollapsed {
            isCollapsed = false
            separatorItem.length = Constants.separatorNormalLength
            updateChevron()
        }

        autoHideManager.cancelTimer()
    }
    
    /// Toggle between collapsed and expanded states.
    func toggle() {
        if isCollapsed {
            expand()
        } else {
            collapse(userInitiated: true)
        }
    }
    
    // MARK: - Screen Change Handling
    
    private func handleScreenChange() {
        // Recompute the collapse length for the new screen dimensions.
        updateCollapseLength()
        
        // If currently collapsed, update the separator length to match.
        if isCollapsed {
            separatorItem.length = collapseLength
        }
    }
    
    // MARK: - UI Updates
    
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
    
    // MARK: - Actions
    
    @objc private func toggleClicked(_ sender: Any?) {
        toggle()
    }
    
    @objc private func showPreferences(_ sender: Any?) {
        if let popover = preferencesPopover, popover.isShown {
            popover.performClose(sender)
            return
        }

        // Reveal the hidden icons so changes (like toggling auto-hide) have
        // visible feedback, and pause the auto-hide countdown while the
        // popover is open so icons aren't yanked away mid-adjustment.
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

    // MARK: - First-run Onboarding

    /// Show a one-time welcome popover anchored to the chevron that explains
    /// the ⌘-drag setup step. Without it, a first-time user sees two glyphs
    /// appear in the menu bar and has no idea what to do next.
    private func showWelcomeIfNeeded() {
        guard !preferences.hasCompletedOnboarding else { return }

        // Give the status items a beat to join the menu bar so the popover
        // has a valid anchor, and pause auto-hide during onboarding.
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

// MARK: - NSPopoverDelegate

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        guard let popover = notification.object as? NSPopover else { return }

        if popover === welcomePopover {
            welcomePopover = nil
            // Mark onboarding complete however the popover was dismissed
            // ("Got It" or clicking elsewhere) so it only ever shows once.
            preferences.hasCompletedOnboarding = true
            logger.info("First-run welcome popover dismissed; onboarding complete.")
        }

        if popover === preferencesPopover {
            preferencesPopover = nil
        }

        // Resume the auto-hide countdown now that the user is done.
        if !isCollapsed {
            autoHideManager.startTimer()
        }
    }
}
