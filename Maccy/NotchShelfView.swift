import AppKit
import SwiftUI

/// View model for the notch shelf.
/// Hooks into the clipboard history to surface recent items.
@MainActor
class NotchShelfViewModel: ObservableObject {
  @Published var recentItems: [HistoryItem] = []

  /// Maximum items shown in the shelf
  private let maxItems = 12

  init() {
    // 1. Load existing history from storage
    loadExistingHistory()

    // 2. Hook into new clipboard copies
    Clipboard.shared.onNewCopy { [weak self] item in
      DispatchQueue.main.async {
        self?.prependItem(item)
      }
    }
  }

  private func loadExistingHistory() {
    // History.shared.all has decorators — extract the underlying HistoryItems
    let decorated = History.shared.all
    let items = decorated.prefix(maxItems).map(\.item)
    recentItems = Array(items)
  }

  private func prependItem(_ item: HistoryItem) {
    // Remove duplicate if it exists
    recentItems.removeAll { $0.title == item.title && $0.firstCopiedAt == item.firstCopiedAt }
    recentItems.insert(item, at: 0)

    // Trim to max
    if recentItems.count > maxItems {
      recentItems = Array(recentItems.prefix(maxItems))
    }
  }

  /// Build an NSItemProvider from a HistoryItem for drag-and-drop
  func dragProvider(for item: HistoryItem) -> NSItemProvider {
    let provider = NSItemProvider()

    // Register string representation
    if let text = item.text {
      provider.registerObject(text as NSString, visibility: .all)
    }

    // Register image representation
    if let image = item.image {
      provider.registerObject(image, visibility: .all)
    }

    // Register URL if it's a file URL
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
}

/// Horizontal shelf view showing recent clipboard items
struct NotchShelfView: View {
  @ObservedObject var viewModel: NotchShelfViewModel

  var body: some View {
    Group {
      if viewModel.recentItems.isEmpty {
        emptyState
      } else {
        itemsList
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(shelfBackground)
  }

  private var emptyState: some View {
    HStack {
      Image(systemName: "clipboard")
        .foregroundStyle(.secondary)
      Text("Copy something to see it here")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var itemsList: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(spacing: 8) {
        ForEach(viewModel.recentItems, id: \.persistentModelID) { item in
          NotchShelfItemView(item: item)
            .onDrag { viewModel.dragProvider(for: item) }
            .onTapGesture { viewModel.selectItem(item) }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
  }

  private var shelfBackground: some View {
    ZStack {
      // Ultra-thin material with rounded rect
      RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

      // Subtle border
      RoundedRectangle(cornerRadius: 14)
        .stroke(.white.opacity(0.1), lineWidth: 0.5)
    }
  }
}
