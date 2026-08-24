import AppKit
import SwiftUI

/// The overlay's content view. It hosts the rig and does nothing else — the type exists so the
/// panel's content view is nameable, and to hold the note below.
///
/// It deliberately does **not** override `hitTest` to reject clicks off the rig. That was tried and
/// it does nothing visible: hit testing chooses which view *inside a window* receives an event the
/// window server has already routed to that window, so refusing it means nothing takes the click —
/// not that the application underneath gets it. The switch that hands a click to the desktop is
/// `NSWindow.ignoresMouseEvents`, steered from the drift loop; see
/// `BearOverlayWindowController.updateClickThrough`.
final class RigHostingView<Content: View>: NSHostingView<Content> {}
