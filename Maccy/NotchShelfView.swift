import AppKit
import SwiftUI

// MARK: - Clipboard Filter

/// Categories for filtering clipboard items in the shelf.
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
    case .all:   return "All"
    case .text:  return "Text"
    case .image: return "Image"
    case .link:  return "Link"
    case .file:  return "File"
    case .color: return "Color"
    }
  }

  var icon: String {
    switch self {
    case .all:   return "square.grid.2x2"
    case .text:  return "text.alignleft"
    case .image: return "photo"
    case .link:  return "link"
    case .file:  return "doc"
    case .color: return "paintpalette"
    }
  }
}

// MARK: - View Model

/// View model for the notch shelf.
/// Hooks into clipboard history and provides search/filter functionality.
@MainActor
class NotchShelfViewModel: ObservableObject {
  @Published var recentItems: [HistoryItem] = []
  @Published var searchText: String = ""
  @Published var activeFilter: ClipboardFilter = .all

  /// Maximum items to keep in the shelf
  private let maxItems = 24

  var filteredItems: [HistoryItem] {
    let items = recentItems

    // Apply content-type filter
    let filtered: [HistoryItem]
    switch activeFilter {
    case .all:
      filtered = items
    case .text:
      filtered = items.filter { $0.text != nil && !isHexColor($0.text) && $0.image == nil && $0.fileURLs.isEmpty }
    case .image:
      filtered = items.filter { $0.image != nil }
    case .link:
      filtered = items.filter { hasLink($0) }
    case .file:
      filtered = items.filter { !$0.fileURLs.isEmpty }
    case .color:
      filtered = items.filter { isHexColor($0.text) }
    }

    // Apply search text
    guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
      return filtered
    }
    return filtered.filter { itemMatchesSearch($0) }
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
    let items = decorated.prefix(maxItems).map(\.item)
    recentItems = Array(items)
  }

  private func prependItem(_ item: HistoryItem) {
    recentItems.removeAll { $0.title == item.title && $0.firstCopiedAt == item.firstCopiedAt }
    recentItems.insert(item, at: 0)
    if recentItems.count > maxItems {
      recentItems = Array(recentItems.prefix(maxItems))
    }
  }

  /// Build an NSItemProvider from a HistoryItem for drag-and-drop
  func dragProvider(for item: HistoryItem) -> NSItemProvider {
    let provider = NSItemProvider()

    if let text = item.text {
      provider.registerObject(text as NSString, visibility: .all)
    }
    if let image = item.image {
      provider.registerObject(image, visibility: .all)
    }
    for url in item.fileURLs {
      provider.registerObject(url as NSURL, visibility: .all)
    }
    return provider
  }

  /// Copy and paste the item (click handler)
  func selectItem(_ item: HistoryItem) {
    Clipboard.shared.copy(item)
    Clipboard.shared.paste()
  }

  // MARK: - Filter Helpers

  private func hasLink(_ item: HistoryItem) -> Bool {
    guard let text = item.text else { return false }
    let linkPattern = try! NSRegularExpression(pattern: #"https?://[^\s]+"#)
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return linkPattern.firstMatch(in: text, range: range) != nil
  }

  func isHexColor(_ text: String?) -> Bool {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
    let hexPattern = "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"
    return text.range(of: hexPattern, options: .regularExpression) != nil
  }

  private func itemMatchesSearch(_ item: HistoryItem) -> Bool {
    let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
    if query.isEmpty { return true }
    if item.title.lowercased().contains(query) { return true }
    if let text = item.text?.lowercased(), text.contains(query) { return true }
    if let app = item.application?.lowercased(), app.contains(query) { return true }
    return false
  }
}

// MARK: - Shelf View

/// Horizontal shelf view showing search, filters, and recent clipboard items
/// in an Apple glass-liquid aesthetic.
struct NotchShelfView: View {
  @ObservedObject var viewModel: NotchShelfViewModel
  @State private var searchFocused = false

  var body: some View {
    VStack(spacing: 0) {
      // Search bar
      searchBar
        .padding(.horizontal, 8)
        .padding(.top, 6)

      // Filter chips
      filterBar
        .padding(.horizontal, 8)
        .padding(.top, 4)

      // Items
      if viewModel.filteredItems.isEmpty {
        emptyState
      } else {
        itemsList
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(shelfBackground)
  }

  // MARK: - Search Bar

  private var searchBar: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)

      TextField("Search clipboard…", text: $viewModel.searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 11))
        .focusedValue(\.isSearchFocused, searchFocused)

      if !viewModel.searchText.isEmpty {
        Button(action: { viewModel.searchText = "" }) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 8)
    .frame(height: 26)
    .background(
      RoundedRectangle(cornerRadius: 13)
        .fill(.regularMaterial)
        .opacity(0.6)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 13)
        .stroke(.white.opacity(0.1), lineWidth: 0.5)
    )
  }

  // MARK: - Filter Bar

  private var filterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        ForEach(ClipboardFilter.allCases) { filter in
          filterChip(filter)
        }
      }
      .padding(.horizontal, 1)
    }
    .frame(height: 26)
  }

  private func filterChip(_ filter: ClipboardFilter) -> some View {
    let isActive = viewModel.activeFilter == filter

    return Button(action: {
      viewModel.activeFilter = filter
    }) {
      HStack(spacing: 4) {
        Image(systemName: filter.icon)
          .font(.system(size: 9, weight: .semibold))
        Text(filter.label)
          .font(.system(size: 10, weight: isActive ? .semibold : .regular))
      }
      .foregroundStyle(isActive ? .white : .secondary)
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(
        Group {
          if isActive {
            RoundedRectangle(cornerRadius: 11)
              .fill(Color.accentColor)
          } else {
            RoundedRectangle(cornerRadius: 11)
              .fill(.regularMaterial)
              .opacity(0.5)
          }
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: 11)
          .stroke(isActive ? .white.opacity(0.15) : .white.opacity(0.05), lineWidth: 0.5)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Items

  private var emptyState: some View {
    VStack(spacing: 4) {
      Image(systemName: "clipboard")
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
      Text("Nothing here")
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var itemsList: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 6) {
        ForEach(viewModel.filteredItems, id: \.persistentModelID) { item in
          NotchShelfItemView(item: item)
            .onDrag { viewModel.dragProvider(for: item) }
            .onTapGesture { viewModel.selectItem(item) }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
    }
  }

  // MARK: - Glass Background

  private var shelfBackground: some View {
    ZStack {
      // Base glass layer
      RoundedRectangle(cornerRadius: 18)
        .fill(.ultraThinMaterial)

      // Shine overlay — subtle gradient from top-left
      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [.white.opacity(0.06), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      // Ambient glow at top edge
      RoundedRectangle(cornerRadius: 18)
        .fill(
          LinearGradient(
            colors: [Color.accentColor.opacity(0.04), .clear],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      // Subtle border with gradient
      RoundedRectangle(cornerRadius: 18)
        .strokeBorder(
          LinearGradient(
            colors: [.white.opacity(0.2), .white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    }
    .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
    .shadow(color: Color.accentColor.opacity(0.03), radius: 16, x: 0, y: 4)
  }
}

// MARK: - Search Focus Environment Key

struct SearchFocusKey: FocusedValueKey {
  typealias Value = Bool
}

extension FocusedValues {
  var isSearchFocused: Bool? {
    get { self[SearchFocusKey.self] }
    set { self[SearchFocusKey.self] = newValue }
  }
}
