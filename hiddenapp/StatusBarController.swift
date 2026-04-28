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

final class StatusBarController {
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
    
    private let autoHideManager = AutoHideManager()
    
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
    
    // MARK: - Right-click Menu & Preferences Popover
    
    private var contextMenu: NSMenu!
    private var preferencesPopover: NSPopover?
    private var rightClickMonitor: Any?
    
    // MARK: - Initialization
    
    init() {
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
            accessibilityDescription: "Toggle hidden menu bar icons"
        )
        button.image?.size = NSSize(width: 12, height: 12)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggleClicked(_:))
        button.sendAction(on: [.leftMouseUp])
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
            title: "Preferences...",
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        contextMenu.addItem(prefsItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit HiddenApp",
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
        let screenWidth = max(separatorScreenWidth ?? 0, widestScreenWidth ?? 1728)
        
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
    func collapse() {
        attemptCollapse(retriesRemaining: Constants.separatorPositionValidationMaxRetries)
    }

    private func attemptCollapse(retriesRemaining: Int) {
        guard !isCollapsed else { return }
        guard isSeparatorValidPosition else {
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
            collapse()
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
            accessibilityDescription: isCollapsed ? "Show hidden icons" : "Hide icons"
        )
        toggleItem.button?.image?.size = NSSize(width: 12, height: 12)
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
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.behavior = .transient
        popover.animates = true
        
        let prefsView = PreferencesView(autoHideManager: autoHideManager)
        popover.contentViewController = NSHostingController(rootView: prefsView)
        
        if let button = toggleItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        
        preferencesPopover = popover
    }
    
    @objc private func quitApp(_ sender: Any?) {
        prepareForTermination()
        NSApplication.shared.terminate(nil)
    }
}
