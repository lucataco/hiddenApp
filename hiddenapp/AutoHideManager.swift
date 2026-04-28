//
//  AutoHideManager.swift
//  hiddenapp
//
//  Manages a timer that automatically collapses (hides) menu bar icons
//  after a configurable delay when the user has expanded them.
//

import Foundation

final class AutoHideManager {
    
    /// Called when the auto-hide timer fires and icons should be collapsed.
    var onAutoHide: (() -> Void)?
    
    private var timer: Timer?
    
    // MARK: - Public API
    
    /// Whether auto-hide is enabled. Reads from UserDefaults.
    var isEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Constants.autoHideEnabled) as? Bool
                ?? Constants.defaultAutoHideEnabled
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.autoHideEnabled)
            if newValue {
                startTimer()
            } else {
                cancelTimer()
            }
        }
    }
    
    /// The auto-hide delay in seconds. Reads from UserDefaults.
    var delay: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: Constants.autoHideDelay)
            return stored > 0 ? stored : Constants.defaultAutoHideDelay
        }
        set {
            let clamped = min(max(newValue, Constants.minimumAutoHideDelay), Constants.maximumAutoHideDelay)
            UserDefaults.standard.set(clamped, forKey: Constants.autoHideDelay)
            if isEnabled {
                startTimer()
            }
        }
    }
    
    /// Start the auto-hide countdown. Call this when icons are revealed.
    /// If auto-hide is disabled, this does nothing.
    func startTimer() {
        cancelTimer()
        guard isEnabled else { return }
        
        timer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            self?.onAutoHide?()
        }
    }
    
    /// Cancel any running auto-hide timer. Call this when the user
    /// manually collapses icons or when the app is about to quit.
    func cancelTimer() {
        timer?.invalidate()
        timer = nil
    }
}
