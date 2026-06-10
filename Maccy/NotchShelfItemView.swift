import AppKit
import SwiftUI

// MARK: - Notch Island Content Card

/// A content card for the Notch Island grid with a 16 px corner radius,
/// type‑aware preview, and a lower metadata overlay (app icon, timestamp, size).
struct NotchShelfItemView: View {
  let item: HistoryItem

  @State private var isHovered = false

  private let cardWidth:  CGFloat = 110
  private let cardHeight: CGFloat = 106

  var body: some View {
    ZStack(alignment: .bottom) {
      // ── Card body ──────────────────────────────────────────
      ZStack(alignment: .top) {
        // content preview
        contentPreview
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(8)

        // type badge (top‑trailing)
        typeBadge
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .padding(6)
      }
      .frame(width: cardWidth, height: cardHeight)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(white: 0.09))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(
            isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.06),
            lineWidth: isHovered ? 1.0 : 0.5
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 16))

      // ── Metadata overlay ──────────────────────────────────
      metadataOverlay
    }
    .frame(width: cardWidth, height: cardHeight + 28)
    .contentShape(RoundedRectangle(cornerRadius: 16))
    .onHover { isHovered = $0 }
  }

  // MARK: - Type Badge

  @ViewBuilder
  private var typeBadge: some View {
    if item.image != nil {
      badgeIcon("photo.fill", color: .blue)
    } else if !item.fileURLs.isEmpty {
      badgeIcon("doc.fill", color: .orange)
    } else if let text = item.text, isHexColor(text) {
      badgeIcon("paintpalette.fill", color: .purple)
    }
  }

  private func badgeIcon(_ systemName: String, color: Color) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 7, weight: .bold))
      .foregroundColor(.white)
      .padding(3)
      .background(Circle().fill(color.opacity(0.75)))
  }

  // MARK: - Content Preview

  @ViewBuilder
  private var contentPreview: some View {
    if let image = item.image {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: cardWidth - 16, height: cardHeight - 16)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    } else if let text = item.text, isHexColor(text) {
      colorSwatch(text)
    } else if let text = item.text {
      textPreview(text)
    } else if !item.fileURLs.isEmpty {
      filePreview
    } else {
      fallbackIcon
    }
  }

  @ViewBuilder
  private func textPreview(_ text: String) -> some View {
    let isCode = looksLikeCode(text)
    VStack(alignment: .leading, spacing: 2) {
      Text(text)
        .font(.system(size: isCode ? 7 : 9, design: isCode ? .monospaced : .default))
        .foregroundColor(.white.opacity(0.85))
        .lineLimit(5, reservesSpace: true)
        .truncationMode(.tail)
    }
  }

  @ViewBuilder
  private var filePreview: some View {
    VStack(spacing: 4) {
      Image(systemName: "doc.fill")
        .font(.system(size: 20))
        .foregroundColor(.white.opacity(0.4))
      if let url = item.fileURLs.first {
        Text(url.lastPathComponent)
          .font(.system(size: 7))
          .foregroundColor(.white.opacity(0.5))
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var fallbackIcon: some View {
    Image(systemName: "doc.on.clipboard")
      .font(.system(size: 22))
      .foregroundColor(.white.opacity(0.35))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func colorSwatch(_ text: String) -> some View {
    if let color = nsColorFromHex(text) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(Color(nsColor: color))
        if isTranslucent(color) {
          checkerboard
        }
      }
      .frame(width: cardWidth - 16, height: cardHeight - 16)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        Text(text.uppercased())
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .foregroundColor(color.isLight ? .black : .white)
          .padding(4),
        alignment: .bottom
      )
    }
  }

  private var checkerboard: some View {
    Grid(horizontalSpacing: 2, verticalSpacing: 2) {
      ForEach(0..<3) { _ in
        GridRow {
          ForEach(0..<3) { _ in
            Rectangle().fill(.quaternary)
          }
        }
      }
    }
    .drawingGroup(opaque: false).blendMode(.difference).opacity(0.12)
  }

  // MARK: - Metadata Overlay

  private var metadataOverlay: some View {
    HStack(spacing: 4) {
      // app icon
      appIcon
        .frame(width: 12, height: 12)

      // relative timestamp
      Text(relativeTime)
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(.white.opacity(0.5))
        .lineLimit(1)

      Spacer(minLength: 2)

      // size
      if let size = contentSize {
        Text(size)
          .font(.system(size: 8, weight: .regular))
          .foregroundColor(.white.opacity(0.35))
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 24)
    .background(
      LinearGradient(
        colors: [
          Color.black.opacity(0.0),
          Color.black.opacity(0.55),
          Color.black.opacity(0.75),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }

  @ViewBuilder
  private var appIcon: some View {
    if let app = item.application, let icon = appIcon(for: app) {
      Image(nsImage: icon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    } else {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 8))
        .foregroundColor(.white.opacity(0.4))
    }
  }

  // MARK: - Derived Values

  private var relativeTime: String {
    let date = item.lastCopiedAt ?? item.firstCopiedAt ?? Date()
    let interval = -date.timeIntervalSinceNow
    switch interval {
    case ..<60:     return "just now"
    case ..<3600:   return "\(Int(interval / 60))m"
    case ..<86400:  return "\(Int(interval / 3600))h"
    default:        return "\(Int(interval / 86400))d"
    }
  }

  private var contentSize: String? {
    if let text = item.text {
      let kb = text.utf8.count / 1024
      return kb > 0 ? "\(kb)KB" : "\(text.utf8.count)B"
    }
    if let image = item.image {
      if let tiff = image.tiffRepresentation {
        let kb = tiff.count / 1024
        return kb > 1024 ? "\(kb / 1024)MB" : "\(kb)KB"
      }
    }
    return nil
  }

  // MARK: - Helpers

  private func isHexColor(_ text: String?) -> Bool {
    guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
    return t.range(of: "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", options: .regularExpression) != nil
  }

  private func nsColorFromHex(_ text: String?) -> NSColor? {
    guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: ""),
          let hex = Int(t, radix: 16) else { return nil }
    switch t.count {
    case 3:
      return NSColor(red: CGFloat((hex >> 8) & 0xF) / 15,
                     green: CGFloat((hex >> 4) & 0xF) / 15,
                     blue: CGFloat(hex & 0xF) / 15, alpha: 1)
    case 6:
      return NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                     green: CGFloat((hex >> 8) & 0xFF) / 255,
                     blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    case 8:
      return NSColor(red: CGFloat((hex >> 24) & 0xFF) / 255,
                     green: CGFloat((hex >> 16) & 0xFF) / 255,
                     blue: CGFloat((hex >> 8) & 0xFF) / 255,
                     alpha: CGFloat(hex & 0xFF) / 255)
    default: return nil
    }
  }

  private func isTranslucent(_ color: NSColor) -> Bool { color.alphaComponent < 0.9 }

  private func looksLikeCode(_ text: String) -> Bool {
    let indicators = ["{", "}", ";", "->", "=>", "func ", "def ", "import ", "//", "/*", "```"]
    return indicators.contains { text.contains($0) }
  }

  private func appIcon(for bundleId: String) -> NSImage? {
    if let cached = Self.iconCache.object(forKey: bundleId as NSString) {
      return cached
    }
    guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
          !appUrl.path.isEmpty
    else { return nil }
    let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
    Self.iconCache.setObject(icon, forKey: bundleId as NSString)
    return icon
  }

  /// Cache app icons so scrolling doesn't hit NSWorkspace for every card.
  private static let iconCache: NSCache<NSString, NSImage> = {
    let c = NSCache<NSString, NSImage>()
    c.countLimit = 50
    return c
  }()
}

// MARK: - Color Brightness Helper

private extension NSColor {
  var isLight: Bool {
    guard let c = usingColorSpace(.sRGB)?.cgColor.components else { return true }
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) > 0.6
  }
}
