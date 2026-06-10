import SwiftUI
import AppKit

// MARK: - Clipboard Filter

/// Categories for filtering clipboard items.
enum ClipboardFilter: String, CaseIterable, Identifiable {
  case all
  case text
  case image
  case link
  case file
  case color

  var id: String { rawValue }

  var label: String {
    switch self {
    case .all:   return "History"
    case .text:  return "Prompts"
    case .image: return "Images"
    case .link:  return "Links"
    case .file:  return "Files"
    case .color: return "Colors"
    }
  }

  var icon: String {
    switch self {
    case .all:   return "clock.arrow.circlepath"
    case .text:  return "text.alignleft"
    case .image: return "photo"
    case .link:  return "link"
    case .file:  return "doc"
    case .color: return "paintpalette"
    }
  }
}

// MARK: - Segment Tab

/// A segment‑tab descriptor matching the Notch Island pill style.
struct SegmentTab: Identifiable, Equatable {
  let id: String
  let label: String
  let count: Int?
  let icon: String
}

// MARK: - View Model

@MainActor
class NotchShelfViewModel: ObservableObject {
  @Published var recentItems: [HistoryItem] = []
  @Published var searchText: String = ""
  @Published var activeSegment: String = "history"

  private let maxItems = 24

  /// Segments that appear as pill tabs below the search bar.
  var segments: [SegmentTab] {
    [
      SegmentTab(id: "history", label: "History", count: recentItems.count, icon: "clock.arrow.circlepath"),
      SegmentTab(id: "images",  label: "Images",  count: nil, icon: "photo"),
      SegmentTab(id: "links",   label: "Links",   count: nil, icon: "link"),
      SegmentTab(id: "files",   label: "Files",   count: nil, icon: "doc"),
      SegmentTab(id: "colors",  label: "Colors",  count: nil, icon: "paintpalette"),
      SegmentTab(id: "prompts", label: "Prompts", count: nil, icon: "text.alignleft"),
    ]
  }

  var filteredItems: [HistoryItem] {
    // Derive filter from active segment
    let filter = filterForSegment(activeSegment)
    let items = recentItems
    let filtered: [HistoryItem]
    switch filter {
    case .all:   filtered = items
    case .text:  filtered = items.filter { $0.text != nil && !isHexColor($0.text) && $0.image == nil && $0.fileURLs.isEmpty }
    case .image: filtered = items.filter { $0.image != nil }
    case .link:  filtered = items.filter { hasLink($0) }
    case .file:  filtered = items.filter { !$0.fileURLs.isEmpty }
    case .color: filtered = items.filter { isHexColor($0.text) }
    }
    guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return filtered }
    return filtered.filter { itemMatchesSearch($0) }
  }

  /// Map segment tab ID to clipboard filter.
  private func filterForSegment(_ id: String) -> ClipboardFilter {
    switch id {
    case "history": return .all
    case "images":  return .image
    case "links":   return .link
    case "files":   return .file
    case "colors":  return .color
    case "prompts": return .text
    default:        return .all
    }
  }

  init() {
    loadExistingHistory()
    Clipboard.shared.onNewCopy { [weak self] item in
      DispatchQueue.main.async {
        self?.prependItem(item)
      }
    }
  }

  private func loadExistingHistory() {
    let decorated = History.shared.all
    recentItems = Array(decorated.prefix(maxItems).map(\.item))
  }

  private func prependItem(_ item: HistoryItem) {
    recentItems.removeAll { $0.title == item.title && $0.firstCopiedAt == item.firstCopiedAt }
    recentItems.insert(item, at: 0)
    if recentItems.count > maxItems {
      recentItems = Array(recentItems.prefix(maxItems))
    }
  }

  

  func selectItem(_ item: HistoryItem) {
    Clipboard.shared.copy(item)
    Clipboard.shared.paste()
  }

  // MARK: - Helpers

  private func hasLink(_ item: HistoryItem) -> Bool {
    guard let text = item.text else { return false }
    let pattern = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)
    return pattern.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)) != nil
  }

  func isHexColor(_ text: String?) -> Bool {
    guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
    return t.range(of: "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$", options: .regularExpression) != nil
  }

  private func itemMatchesSearch(_ item: HistoryItem) -> Bool {
    let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
    if q.isEmpty { return true }
    if item.title.lowercased().contains(q) { return true }
    if let t = item.text?.lowercased(), t.contains(q) { return true }
    if let a = item.application?.lowercased(), a.contains(q) { return true }
    return false
  }
}

// MARK: - Notch Island View

/// The full Notch‑Island UI: black notch‑shaped backdrop, glass flanking pods,
/// search bar, segment pills, and a horizontal grid of content cards.
struct NotchShelfView: View {
  @ObservedObject var viewModel: NotchShelfViewModel
  @State private var searchFocused = false

  /// Pre‑cached shape — avoids recomputing the notch path on every render pass.
  private static let islandShape = NotchIslandShape()

  // Apple‑native spring: mass 1.0, stiffness 120, damping 18
  var body: some View {
    ZStack(alignment: .top) {
      // ── 1. Notch island backdrop ──────────────────────────────
      Self.islandShape
        .fill(Color.black)
        .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 12)
        .drawingGroup()    // GPU-cache only the static background, not the content

      // ── 2. Flanking pods (left / right of notch) ──────────────
      flankingBars
        .padding(.top, 4)

      // ── 3. Main content (below notch level) ──────────────────
      VStack(spacing: 0) {
        Spacer().frame(height: 44)

        HStack(alignment: .center, spacing: 0) {
          searchBar
          Spacer(minLength: 16)
          actionPills
        }
        .padding(.horizontal, 16)

        Spacer().frame(height: 10)

        segmentPills
          .padding(.horizontal, 16)

        Spacer().frame(height: 12)

        if viewModel.filteredItems.isEmpty {
          emptyState
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          cardsGrid
        }
      }
    }
    .frame(width: panelWidth, height: panelHeight)
    .clipShape(Self.islandShape)
  }

  // MARK: - Dimensions

  private let panelWidth:   CGFloat = 820
  private let panelHeight:  CGFloat = 300

  // MARK: - Flanking Bars

  private var flankingBars: some View {
    HStack(spacing: 0) {
      // Left pod — app identity
      FlankingPod(icon: "chevron.left", text: "NotChy", alignment: .leading)
        .padding(.leading, 12)

      // Notch gap — the physical notch sits here
      Spacer()
        .frame(width: 180)

      // Right pod — system metrics with live clock
      RightFlankingPod()
        .padding(.trailing, 12)
    }
    .frame(height: 28)
  }

  // MARK: - Search Bar

  private var searchBar: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Color(white: 0.5))

      TextField("Search your soul…", text: $viewModel.searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .regular, design: .default))
        .foregroundColor(.white)
        .focusedValue(\.isSearchFocused, searchFocused)

      if !viewModel.searchText.isEmpty {
        Button { viewModel.searchText = "" } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12))
            .foregroundColor(Color(white: 0.45))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 10)
    .frame(height: 32)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(white: 0.12))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(white: 0.2), lineWidth: 0.5)
    )
  }

  // MARK: - Action Pills

  private var actionPills: some View {
    HStack(spacing: 6) {
      actionPill("star")
      actionPill("square.grid.2x2")
      actionPill("square.and.arrow.up")
    }
  }

  private func actionPill(_ icon: String) -> some View {
    Button {} label: {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(Color(white: 0.55))
        .frame(width: 28, height: 28)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(Color(white: 0.12))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color(white: 0.18), lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Segment Pills

  private var segmentPills: some View {
    HStack(spacing: 6) {
      ForEach(viewModel.segments) { seg in
        let isActive = viewModel.activeSegment == seg.id
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            viewModel.activeSegment = seg.id
          }
        } label: {
          HStack(spacing: 5) {
            Image(systemName: seg.icon)
              .font(.system(size: 10, weight: .semibold))
            Text(seg.label)
              .font(.system(size: 11, weight: isActive ? .semibold : .regular))
            if let c = seg.count {
              Text("\(c)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .black.opacity(0.6) : Color(white: 0.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                  Capsule()
                    .fill(isActive ? .white.opacity(0.2) : Color(white: 0.1))
                )
            }
          }
          .foregroundColor(isActive ? .black : Color(white: 0.55))
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(
            Group {
              if isActive {
                Capsule().fill(Color.white)
              } else {
                Capsule().fill(Color(white: 0.12))
              }
            }
          )
          .overlay(
            Capsule()
              .stroke(isActive ? .clear : Color(white: 0.18), lineWidth: 0.5)
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "clipboard")
        .font(.system(size: 20))
        .foregroundColor(Color(white: 0.3))
      Text("Nothing here")
        .font(.system(size: 12))
        .foregroundColor(Color(white: 0.4))
    }
  }

  // MARK: - Cards Grid

  private var cardsGrid: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(viewModel.filteredItems, id: \.persistentModelID) { item in
          NotchShelfItemView(item: item)
            .onTapGesture { viewModel.selectItem(item) }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 2)
    }
  }
}

// MARK: - Flanking Pod

/// A glass‑morphism pill displayed on the left / right of the notch.
struct FlankingPod: View {
  let icon: String
  let text: String
  let alignment: Alignment

  var body: some View {
    HStack(spacing: 5) {
      if alignment == .trailing { Spacer(minLength: 0) }

      Image(systemName: icon)
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(.white.opacity(0.6))

      Text(text)
        .font(.system(size: 11, weight: .semibold, design: .default))
        .foregroundColor(.white)
        .lineLimit(1)

      if alignment == .leading { Spacer(minLength: 0) }
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(
      Capsule()
        .fill(.ultraThinMaterial)
    )
    .background(
      Capsule()
        .fill(
          LinearGradient(
            colors: [.white.opacity(0.12), .white.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      Capsule()
        .stroke(
          LinearGradient(
            colors: [.white.opacity(0.25), .white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    )
  }
}

// MARK: - Time Label View

/// A lightweight self‑updating clock label that redraws once per second
/// without causing its parent view to re‑render.
private struct TimeLabelView: View {
  @State private var now = Date()
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(now, style: .time)
      .font(.system(size: 11, weight: .semibold, design: .default))
      .foregroundColor(.white)
      .monospacedDigit()
      .onReceive(timer) { now = $0 }
  }
}

// MARK: - Right Flanking Pod

/// Self‑contained right‑hand notch pod with Wi‑Fi icon and live clock.
/// Extracted as a separate struct so its timer doesn't cause the parent view to re‑render.
private struct RightFlankingPod: View {
  var body: some View {
    HStack(spacing: 5) {
      Spacer(minLength: 0)
      Image(systemName: "wifi")
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(.white.opacity(0.6))
      TimeLabelView()
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(Capsule().fill(.ultraThinMaterial))
    .background(
      Capsule()
        .fill(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.02)],
                             startPoint: .topLeading, endPoint: .bottomTrailing))
    )
    .overlay(
      Capsule()
        .stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5)
    )
  }
}

// MARK: - Focus Key

struct SearchFocusKey: FocusedValueKey { typealias Value = Bool }
extension FocusedValues {
  var isSearchFocused: Bool? {
    get { self[SearchFocusKey.self] }
    set { self[SearchFocusKey.self] = newValue }
  }
}
