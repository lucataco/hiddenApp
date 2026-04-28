//
//  PreferencesView.swift
//  hiddenapp
//
//  SwiftUI view shown in a popover from the preferences status item.
//  Provides controls for auto-hide and launch at login.
//

import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    let autoHideManager: AutoHideManager
    
    @AppStorage(Constants.autoHideEnabled) private var autoHideEnabled = Constants.defaultAutoHideEnabled
    @AppStorage(Constants.autoHideDelay) private var autoHideDelay = Constants.defaultAutoHideDelay
    
    @State private var launchAtLogin = false
    
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
                        autoHideManager.isEnabled = newValue
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
                            autoHideManager.delay = newValue
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
        .frame(width: 260)
        .onAppear {
            // Read current launch-at-login state
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // If registration fails, revert the toggle
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
