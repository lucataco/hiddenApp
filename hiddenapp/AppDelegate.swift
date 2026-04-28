//
//  AppDelegate.swift
//  hiddenapp
//
//  The main application delegate. Sets up the StatusBarController
//  which owns all menu bar items and the cover window.
//  This is a menu-bar-only app (no Dock icon, no main window).
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure no main window is shown
        // (The SwiftUI App struct has no WindowGroup, but just in case)
        for window in NSApplication.shared.windows {
            window.close()
        }
        
        // Initialize the status bar controller, which sets up everything
        statusBarController = StatusBarController()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Ensure icons are revealed before the app quits
        statusBarController?.prepareForTermination()
    }
}
