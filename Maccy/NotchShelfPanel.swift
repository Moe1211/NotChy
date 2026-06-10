import AppKit
import SwiftUI

/// A floating panel that appears at the top center of the screen below the camera notch.
/// Shows recent clipboard items as a horizontal shelf with search and filters.
class NotchShelfPanel: NSPanel {
  static let shared = NotchShelfPanel()

  private(set) var isShown: Bool = false

  /// Height of the shelf when expanded (search + filters + items + padding)
  static let shelfHeight: CGFloat = 148

  /// Width of the shelf as a fraction of screen width
  static let screenWidthFraction: CGFloat = 0.75

  /// Maximum absolute width
  static let maxWidth: CGFloat = 800

  private let viewModel = NotchShelfViewModel()

  private init() {
    let contentRect = NSRect(x: 0, y: 0, width: 400, height: Self.shelfHeight)

    super.init(
      contentRect: contentRect,
      styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
      backing: .buffered,
      defer: false
    )

    identifier = NSUserInterfaceItemIdentifier("NotchShelfPanel")
    isFloatingPanel = true
    level = .floating
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

  /// Allow the panel to become key so text fields (search bar) can accept input
  override var canBecomeKey: Bool { true }

  /// Show the shelf at the top center of the screen the mouse is on
  func show() {
    guard let screen = mouseScreen() else { return }

    let shelfWidth = min(screen.visibleFrame.width * Self.screenWidthFraction, Self.maxWidth)
    let shelfHeight = Self.shelfHeight

    // Position below the notch: screen.frame.maxY is the top edge of the screen
    let notchAreaHeight: CGFloat = 50  // approx from screen top to bottom of notch
    let topY = screen.frame.maxY - notchAreaHeight - shelfHeight
    let originX = screen.frame.minX + (screen.frame.width - shelfWidth) / 2

    setContentSize(NSSize(width: shelfWidth, height: shelfHeight))
    setFrameOrigin(NSPoint(x: originX, y: topY))
    orderFrontRegardless()
    makeKey()
    isShown = true
  }

  func hide() {
    orderOut(nil)
    isShown = false
  }

  /// Returns the screen containing the mouse pointer
  private func mouseScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
  }
}
