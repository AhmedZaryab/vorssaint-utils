import AppKit

extension NSScreen {
    /// The CoreGraphics display id behind this screen; 0 when missing, which
    /// callers treat as not capturable.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
