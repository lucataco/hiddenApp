import Foundation

enum OverlayAppearance {
    /// System-wide light/dark, not the accessory app's often-stale
    /// `NSApp.effectiveAppearance`. Menu-bar extras must match the bar,
    /// which follows `AppleInterfaceStyle`.
    static func isSystemDark(appleInterfaceStyle: String?) -> Bool {
        appleInterfaceStyle == "Dark"
    }

    static var isSystemDark: Bool {
        isSystemDark(
            appleInterfaceStyle: UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        )
    }
}
