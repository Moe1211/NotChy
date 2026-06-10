import AppKit
import SwiftUI

/// A floating NSPanel that renders the Notch Island UI — a deep‑black
/// container with a notch cutout, glass flanking pods, search bar,
/// segment pills, and a grid of clipboard content cards.
class NotchShelfPanel: NSPanel {
  static let shared = NotchShelfPanel()

  private(set) var isShown: Bool = false

  // MARK: - Notch Island Dimensions

  /// Notch cutout dimensions (matches physical MacBook notch)
  static let notchWidth:  CGFloat = 180
  static let notchHeight: CGFloat = 36

  /// Island container
  static let islandWidth:  CGFloat = 820
  static let islandHeight: CGFloat = 300

  /// Corner radius at the bottom of the island
  static let cornerRadius: CGFloat = 30

  private let viewModel = NotchShelfViewModel()

  private init() {
    let contentRect = NSRect(x: 0, y: 0,
                             width: Self.islandWidth,
                             height: Self.islandHeight)

    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
      backing: .buffered,
      defer: false
    )

    identifier = NSUserInterfaceItemIdentifier("NotchShelfPanel")
    isFloatingPanel = true
    // Must sit above the menu bar so the notch cutout aligns with
    // the physical hardware notch at the very top of the screen.
    level = NSWindow.Level(rawValue: 1000)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    ignoresMouseEvents = false
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovable = false
    acceptsMouseMovedEvents = true

    contentView = NSHostingView(
      rootView: NotchShelfView(viewModel: viewModel)
        .ignoresSafeArea()
    )
  }

  override var canBecomeKey: Bool { true }

  // MARK: - Show / Hide

  /// Show the Notch Island positioned so the notch cutout aligns with
  /// the screen's hardware notch.
  func show() {
    guard let screen = mouseScreen() else { return }

    let originX = screen.frame.minX + (screen.frame.width - Self.islandWidth) / 2
    // setFrameOrigin sets the BOTTOM-LEFT corner.
    // We want the TOP of the panel (notch cutout) to align with
    // the top of the screen where the hardware notch sits.
    let originY = screen.frame.maxY - Self.islandHeight

    setContentSize(NSSize(width: Self.islandWidth, height: Self.islandHeight))
    setFrameOrigin(NSPoint(x: originX, y: originY))
    orderFrontRegardless()
    makeKey()
    isShown = true
  }

  func hide() {
    orderOut(nil)
    isShown = false
  }

  /// Returns the screen containing the mouse pointer.
  private func mouseScreen() -> NSScreen? {
    let loc = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(loc) }
  }
}
