//
//  AppDelegate.swift
//  hiddenapp
//
//  The main application delegate. Sets up the StatusBarController
//  which owns all menu bar items and the cover window.
//  This is a menu-bar-only app (no Dock icon, no main window).
//

import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "AppDelegate"
    )

    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("HiddenApp launching.")
        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("HiddenApp terminating; revealing hidden icons.")
        statusBarController?.prepareForTermination()
    }
}
