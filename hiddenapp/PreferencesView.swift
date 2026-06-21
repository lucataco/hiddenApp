//
//  PreferencesView.swift
//  hiddenapp
//
//  SwiftUI view shown in a popover from the preferences status item.
//  Provides controls for auto-hide and launch at login.
//

import AppKit
import SwiftUI
import ServiceManagement
import os

struct PreferencesView: View {
    let preferences: Preferences
    let autoHideManager: AutoHideManager

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.catacolabs.hiddenapp",
        category: "PreferencesView"
    )

    @State private var autoHideEnabled: Bool
    @State private var autoHideDelay: Double
    @State private var launchAtLogin = false

    init(preferences: Preferences, autoHideManager: AutoHideManager) {
        self.preferences = preferences
        self.autoHideManager = autoHideManager
        _autoHideEnabled = State(initialValue: preferences.autoHideEnabled)
        _autoHideDelay = State(initialValue: preferences.autoHideDelay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("HiddenApp")
                .font(.headline)

            Divider()

            // Auto-hide section
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Auto-hide icons", isOn: $autoHideEnabled)
                    .onChange(of: autoHideEnabled) { _, newValue in
                        autoHideManager.setEnabled(newValue)
                    }

                if autoHideEnabled {
                    HStack {
                        Text("Delay:")
                            .foregroundStyle(.secondary)

                        Slider(
                            value: $autoHideDelay,
                            in: Constants.minimumAutoHideDelay...Constants.maximumAutoHideDelay,
                            step: 1.0
                        )
                        .onChange(of: autoHideDelay) { _, newValue in
                            autoHideManager.setDelay(newValue)
                        }

                        Text("\(Int(autoHideDelay))s")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }

            Divider()

            // Launch at Login
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Divider()

            // Version info
            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            // Read current launch-at-login state
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                logger.info("Launch at login enabled.")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at login disabled.")
            }
        } catch {
            logger.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
            // If registration fails, revert the toggle and explain why.
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            presentLaunchAtLoginError(error)
        }
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Launch at login could not be changed.")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
