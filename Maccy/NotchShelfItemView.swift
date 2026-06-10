import AppKit
import SwiftUI

/// A glass-liquid tile showing a preview of a clipboard item.
/// Supports drag-and-drop and click-to-paste.
struct NotchShelfItemView: View {
  let item: HistoryItem

  @State private var isHovered = false

  private let tileSize: CGFloat = 58

  var body: some View {
    ZStack {
      // Glass tile background
      glassBackground

      // Content
      contentPreview
        .padding(4)

      // Content-type badge
      typeBadge
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(3)
    }
    .frame(width: tileSize, height: tileSize)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .scaleEffect(isHovered ? 1.08 : 1.0)
    .shadow(
      color: .black.opacity(isHovered ? 0.25 : 0.1),
      radius: isHovered ? 12 : 4,
      y: isHovered ? 4 : 2
    )
    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
    .help(item.title)
  }

  // MARK: - Glass Background

  private var glassBackground: some View {
    ZStack {
      // Base material
      RoundedRectangle(cornerRadius: 12)
        .fill(.regularMaterial)
        .opacity(0.7)

      // Hover glow
      if isHovered {
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.accentColor.opacity(0.1))
      }

      // Shine
      RoundedRectangle(cornerRadius: 12)
        .fill(
          LinearGradient(
            colors: [.white.opacity(isHovered ? 0.12 : 0.06), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      // Border
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          LinearGradient(
            colors: [
              .white.opacity(isHovered ? 0.25 : 0.08),
              .white.opacity(isHovered ? 0.10 : 0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: isHovered ? 1.0 : 0.5
        )
    }
  }

  // MARK: - Type Badge

  @ViewBuilder
  private var typeBadge: some View {
    if item.image != nil {
      Image(systemName: "photo.fill")
        .font(.system(size: 6))
        .foregroundStyle(.white)
        .padding(2)
        .background(Circle().fill(.blue.opacity(0.7)))
    } else if !item.fileURLs.isEmpty {
      Image(systemName: "doc.fill")
        .font(.system(size: 6))
        .foregroundStyle(.white)
        .padding(2)
        .background(Circle().fill(.orange.opacity(0.7)))
    } else if isHexColor(item.text) {
      Image(systemName: "paintpalette.fill")
        .font(.system(size: 6))
        .foregroundStyle(.white)
        .padding(2)
        .background(Circle().fill(.purple.opacity(0.7)))
    }
  }

  // MARK: - Content Preview

  @ViewBuilder
  private var contentPreview: some View {
    if let image = item.image {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: tileSize - 8, height: tileSize - 8)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else if isHexColor(item.text) {
      colorSwatch
    } else if let text = item.text {
      textPreview(text)
    } else if !item.fileURLs.isEmpty {
      filePreview
    } else {
      fallbackIcon
    }
  }

  @ViewBuilder
  private var colorSwatch: some View {
    if let color = colorFromHex(item.text) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(nsColor: color))
        if color.isTranslucent {
          checkerboard
        }
      }
      .frame(width: tileSize - 8, height: tileSize - 8)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        Text(item.text?.uppercased() ?? "")
          .font(.system(size: 7, weight: .bold, design: .monospaced))
          .foregroundColor(color.isLight ? .black : .white)
          .padding(3),
        alignment: .bottom
      )
    }
  }

  @ViewBuilder
  private func textPreview(_ text: String) -> some View {
    let isCode = looksLikeCode(text)
    VStack(alignment: .leading, spacing: 1) {
      if let app = item.application, let appName = appName(from: app) {
        Text(appName)
          .font(.system(size: 6, weight: .semibold))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .blendMode(.overlay)
      }

      Text(text)
        .font(.system(size: isCode ? 7 : 8, design: isCode ? .monospaced : .default))
        .foregroundStyle(.primary)
        .lineLimit(3, reservesSpace: true)
        .truncationMode(.tail)
        .opacity(0.85)
    }
    .padding(5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var filePreview: some View {
    VStack(spacing: 2) {
      Image(systemName: "doc.fill")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .blendMode(.overlay)

      if let firstURL = item.fileURLs.first {
        Text(firstURL.lastPathComponent)
          .font(.system(size: 6))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
          .blendMode(.overlay)
      }
    }
  }

  private var fallbackIcon: some View {
    Image(systemName: "doc.on.clipboard")
      .font(.system(size: 16))
      .foregroundStyle(.secondary)
      .blendMode(.overlay)
  }

  private var checkerboard: some View {
    Grid(horizontalSpacing: 2, verticalSpacing: 2) {
      ForEach(0..<3) { _ in
        GridRow {
          ForEach(0..<3) { _ in
            Rectangle()
              .fill(.quaternary)
          }
        }
      }
    }
    .drawingGroup(opaque: false)
    .blendMode(.difference)
    .opacity(0.15)
  }

  // MARK: - Helpers

  private func isHexColor(_ text: String?) -> Bool {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
    let hexPattern = "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
    return text.range(of: hexPattern, options: .regularExpression) != nil
  }

  private func colorFromHex(_ text: String?) -> NSColor? {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: ""),
          let hex = Int(text, radix: 16) else { return nil }

    switch text.count {
    case 3:
      let r = CGFloat((hex >> 8) & 0xF) / 15.0
      let g = CGFloat((hex >> 4) & 0xF) / 15.0
      let b = CGFloat(hex & 0xF) / 15.0
      return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    case 6:
      return NSColor(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                     green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                     blue: CGFloat(hex & 0xFF) / 255.0,
                     alpha: 1.0)
    case 8:
      return NSColor(red: CGFloat((hex >> 24) & 0xFF) / 255.0,
                     green: CGFloat((hex >> 16) & 0xFF) / 255.0,
                     blue: CGFloat((hex >> 8) & 0xFF) / 255.0,
                     alpha: CGFloat(hex & 0xFF) / 255.0)
    default:
      return nil
    }
  }

  private func looksLikeCode(_ text: String) -> Bool {
    let codeIndicators = ["{", "}", ";", "->", "=>", "func ", "def ", "import ", "//", "/*", "```"]
    return codeIndicators.contains { text.contains($0) }
  }

  private func appName(from bundleIdentifier: String) -> String? {
    let known: [String: String] = [
      "com.apple.Safari": "Safari",
      "com.apple.finder": "Finder",
      "com.apple.dt.xcode": "Xcode",
      "com.figma.Desktop": "Figma",
      "com.tinyspeck.slackmacgap": "Slack",
      "com.google.Chrome": "Chrome",
      "org.mozilla.firefox": "Firefox",
      "com.apple.mail": "Mail",
      "com.apple.Notes": "Notes",
      "com.apple.TextEdit": "TextEdit",
      "com.microsoft.VSCode": "VS Code",
      "com.sublimetext.4": "Sublime"
    ]
    return known[bundleIdentifier] ?? bundleIdentifier.components(separatedBy: ".").last?.capitalized
  }
}

// MARK: - Color helpers

private extension NSColor {
  var isLight: Bool {
    guard let components = usingColorSpace(.sRGB)?.cgColor.components else { return true }
    let brightness = (0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2])
    return brightness > 0.6
  }

  var isTranslucent: Bool {
    alphaComponent < 0.9
  }
}
