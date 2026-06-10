import AppKit

/// Tracks global mouse position and shows/hides the notch shelf
/// when the cursor nears the top center of any screen.
class NotchHoverDetector {
  static let shared = NotchHoverDetector()

  /// Distance from the top of the screen that triggers the island to appear
  private var activationThreshold: CGFloat = 15

  /// Once visible, the mouse must drop below this Y (relative to screen top)
  /// before the shelf hides. Prevents flicker.
  private var deactivationThreshold: CGFloat = 180

  /// Horizontal zone: mouse must be within this fraction of screen center
  private var horizontalActivationFraction: CGFloat = 0.25

  private var monitor: Any?
  private var isWithinZone = false
  private var hideWorkItem: DispatchWorkItem?
  private var hideGeneration = 0

  private init() {}

  /// Start monitoring global mouse movements
  func start() {
    guard monitor == nil else { return }

    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) {
      [weak self] event in
      self?.handleMouseMove(event)
    }
  }

  /// Stop monitoring
  func stop() {
    if let monitor = monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    hideWorkItem?.cancel()
    hideWorkItem = nil
  }

  /// Update thresholds from settings (called by NotchSettingsPane)
  func updateThresholds(activation: CGFloat, deactivation: CGFloat, horizontalZone: CGFloat) {
    activationThreshold = activation
    deactivationThreshold = deactivation
    horizontalActivationFraction = horizontalZone
  }

  private func handleMouseMove(_ event: NSEvent) {
    let mouseLocation = NSEvent.mouseLocation

    // Find which screen the mouse is on
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
      hideIfNotHovered()
      return
    }

    let distanceFromTop = screen.frame.maxY - mouseLocation.y
    let distanceFromCenterX = abs(mouseLocation.x - screen.frame.midX)
    let horizontalZone = screen.frame.width * horizontalActivationFraction

    let nearTop = distanceFromTop <= activationThreshold
    let centered = distanceFromCenterX <= horizontalZone

    if nearTop && centered {
      // Mouse is in the activation zone — show shelf
      showIfNeeded()
    } else if distanceFromTop > deactivationThreshold {
      // Mouse moved well away — hide shelf
      hideIfNotHovered()
    }
    // else: keep alive zone between activation and deactivation thresholds
  }

  private func showIfNeeded() {
    hideWorkItem?.cancel()
    hideWorkItem = nil
    hideGeneration += 1

    if !NotchShelfPanel.shared.isShown {
      NotchShelfPanel.shared.show()
    }
  }

  private func hideIfNotHovered() {
    guard NotchShelfPanel.shared.isShown else { return }

    // Debounce hide to avoid flicker when moving past the notch
    hideWorkItem?.cancel()
    hideGeneration += 1
    let capturedGeneration = hideGeneration

    let workItem = DispatchWorkItem { [weak self] in
      guard let self = self, self.hideGeneration == capturedGeneration else { return }
      NotchShelfPanel.shared.hide()
    }
    hideWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
  }
}
