import AppKit
import SwiftUI

/// A single tile in the notch shelf showing a preview of a clipboard item.
/// Supports drag-and-drop and click-to-paste.
struct NotchShelfItemView: View {
  let item: HistoryItem

  @State private var isHovered = false

  private let tileWidth: CGFloat = 72
  private let tileHeight: CGFloat = 72

  var body: some View {
    ZStack {
      tileBackground
      contentPreview
    }
    .frame(width: tileWidth, height: tileHeight)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isHovered ? Color.accentColor.opacity(0.5) : .white.opacity(0.05),
                lineWidth: isHovered ? 1.5 : 0.5)
    )
    .scaleEffect(isHovered ? 1.05 : 1.0)
    .animation(.easeOut(duration: 0.15), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
    .help(item.text ?? item.title)
  }

  @ViewBuilder
  private var contentPreview: some View {
    if let image = item.image {
      // Image thumbnail
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: tileWidth - 4, height: tileHeight - 4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    } else if isHexColor(item.text) {
      // Color swatch
      colorSwatch
    } else if let text = item.text {
      // Text or code preview
      textPreview(text)
    } else if !item.fileURLs.isEmpty {
      // File URL icon
      filePreview
    } else {
      // Fallback
      fallbackIcon
    }
  }

  private var tileBackground: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
  }

  @ViewBuilder
  private var colorSwatch: some View {
    if let color = colorFromHex(item.text) {
      ZStack {
        Rectangle()
          .fill(Color(nsColor: color))
        // Checkerboard overlay for transparent-ish colors
        if color.isTranslucent {
          checkerboard
        }
      }
      .frame(width: tileWidth - 4, height: tileHeight - 4)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        Text(item.text?.uppercased() ?? "")
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .foregroundColor(color.isLight ? .black : .white)
          .padding(4),
        alignment: .bottom
      )
    }
  }

  @ViewBuilder
  private func textPreview(_ text: String) -> some View {
    let isCode = looksLikeCode(text)
    VStack(alignment: .leading, spacing: 2) {
      // Source app badge
      if let app = item.application, let appName = appName(from: app) {
        Text(appName)
          .font(.system(size: 7, weight: .medium))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }

      Text(text)
        .font(.system(size: isCode ? 8 : 9, design: isCode ? .monospaced : .default))
        .foregroundStyle(.primary)
        .lineLimit(3, reservesSpace: true)
        .truncationMode(.tail)
    }
    .padding(6)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var filePreview: some View {
    VStack(spacing: 4) {
      Image(systemName: "doc.fill")
        .font(.title3)
        .foregroundStyle(.secondary)

      if let firstURL = item.fileURLs.first {
        Text(firstURL.lastPathComponent)
          .font(.system(size: 7))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
  }

  private var fallbackIcon: some View {
    Image(systemName: "doc.on.clipboard")
      .font(.title2)
      .foregroundStyle(.secondary)
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
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return false
    }
    let hexPattern = "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
    return text.range(of: hexPattern, options: .regularExpression) != nil
  }

  private func colorFromHex(_ text: String?) -> NSColor? {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: ""),
          let hex = Int(text, radix: 16) else {
      return nil
    }

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

  /// Strip bundle identifier to a short app name
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
    guard let components = usingColorSpace(.sRGB)?.cgColor.components else {
      return true
    }
    let brightness = (0.299 * components[0] + 0.587 * components[1] + 0.114 * components[2])
    return brightness > 0.6
  }

  var isTranslucent: Bool {
    alphaComponent < 0.9
  }
}
