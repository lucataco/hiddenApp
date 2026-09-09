import Foundation

enum CollapseMode: Equatable {
    /// Pre-macOS 27: expand `NSStatusItem.length` so items left of the
    /// separator are clipped off the leading edge of the bar.
    case length

    /// macOS 27+: the bar is a single WindowServer surface and no longer
    /// reflows around an oversized status item. Cover the hidden zone with
    /// compositor overlays instead.
    case overlay

    static func mode(forMajorVersion version: Int) -> CollapseMode {
        version >= 27 ? .overlay : .length
    }

    static var current: CollapseMode {
        mode(forMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }
}
