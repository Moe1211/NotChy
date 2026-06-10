import SwiftUI

// MARK: - Notch Island Shape

/// A shape with a hardware-notch cutout at the top center and aggressively
/// rounded bottom corners (24–32 pt). The notch corners use smooth S-curve
/// transitions for a fluid, Apple-polished silhouette.
struct NotchIslandShape: Shape {
  var notchWidth: CGFloat  = 180
  var notchHeight: CGFloat = 36
  var cornerRadius: CGFloat = 30
  var bridgeRadius: CGFloat = 14

  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    let nx = (w - notchWidth) / 2      // notch left edge
    let nr = notchWidth                 // notch right edge = nx + nr
    let br = bridgeRadius
    let cr = cornerRadius

    return Path { path in
      // ── start top‑left (slightly inset for top‑corner polish) ──
      path.move(to: CGPoint(x: 0, y: br + 1))

      // left flank top edge
      path.addArc(tangent1End: CGPoint(x: 0, y: 0),
                  tangent2End: CGPoint(x: nx, y: 0),
                  radius: 4)
      path.addLine(to: CGPoint(x: nx - br, y: 0))

      // ▼ S‑curve bridge: left notch corner ──────────────────────
      path.addArc(tangent1End: CGPoint(x: nx, y: 0),
                  tangent2End: CGPoint(x: nx, y: notchHeight),
                  radius: br)

      // left notch side
      path.addLine(to: CGPoint(x: nx, y: notchHeight - br))

      // notch bottom‑left
      path.addArc(tangent1End: CGPoint(x: nx, y: notchHeight),
                  tangent2End: CGPoint(x: nx + br, y: notchHeight),
                  radius: br)

      // notch bottom edge
      path.addLine(to: CGPoint(x: nx + nr - br, y: notchHeight))

      // notch bottom‑right
      path.addArc(tangent1End: CGPoint(x: nx + nr, y: notchHeight),
                  tangent2End: CGPoint(x: nx + nr, y: notchHeight - br),
                  radius: br)

      // right notch side
      path.addLine(to: CGPoint(x: nx + nr, y: br))

      // ▲ S‑curve bridge: right notch corner ─────────────────────
      path.addArc(tangent1End: CGPoint(x: nx + nr, y: 0),
                  tangent2End: CGPoint(x: nx + nr + br, y: 0),
                  radius: br)

      // right flank top edge
      path.addLine(to: CGPoint(x: w - 4, y: 0))
      path.addArc(tangent1End: CGPoint(x: w, y: 0),
                  tangent2End: CGPoint(x: w, y: cr),
                  radius: 4)

      // right side
      path.addLine(to: CGPoint(x: w, y: h - cr))

      // bottom‑right
      path.addArc(tangent1End: CGPoint(x: w, y: h),
                  tangent2End: CGPoint(x: w - cr, y: h),
                  radius: cr)

      // bottom edge
      path.addLine(to: CGPoint(x: cr, y: h))

      // bottom‑left
      path.addArc(tangent1End: CGPoint(x: 0, y: h),
                  tangent2End: CGPoint(x: 0, y: h - cr),
                  radius: cr)

      // left side → close
      path.addLine(to: CGPoint(x: 0, y: br + 1))
      path.closeSubpath()
    }
  }
}

// MARK: - VisualEffect Blur View (AppKit bridge)

/// Bridges NSVisualEffectView into SwiftUI for glass‑morphism pods.
struct VisualEffectBlur: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
  var state: NSVisualEffectView.State = .active

  func makeNSView(context: Context) -> NSVisualEffectView {
    let v = NSVisualEffectView()
    v.material = material
    v.blendingMode = blendingMode
    v.state = state
    v.wantsLayer = true
    v.layer?.cornerRadius = 16
    return v
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.state = state
  }
}

// MARK: - System Time Provider

/// Simple time source for the right‑hand flanking pod.
class TimeProvider: ObservableObject {
  @Published var now = Date()
  private var timer: Timer?

  init() {
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.now = Date()
    }
  }

  deinit { timer?.invalidate() }
}
