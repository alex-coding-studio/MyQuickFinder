import Foundation
import Observation

public enum PanelZone: Equatable, Sendable {
    case favorites
    case list
}

@MainActor
@Observable
public final class PanelModel {
    public let browser: BrowserModel
    public let picker: PathPickerModel

    public private(set) var favorites: FavoriteList
    public private(set) var zone = PanelZone.list
    public private(set) var showsHelp = false
    public private(set) var awaitingAuthorizationFor: URL?
    public private(set) var retriedAuthorizationFor: URL?
    public private(set) var presentationCount = 0
    public private(set) var isShowingAncestors = false

    public private(set) var missingFavoritePaths = Set<String>()

    private let storage: any FavoriteStoring
    private let existenceProbe: @Sendable (URL) -> Bool
    private var availabilityTask: Task<Void, Never>?
    private var hasChosenEntryPoint = false
    private var ancestorSelection = 0

    public var favoriteShortcutCapacity: Int {
        min(favorites.items.count, FavoriteList.shortcutCapacity)
    }

    public var isSelectionFavorited: Bool {
        guard let entry = browser.selectedEntry else {
            return false
        }
        return favorites.contains(url: entry.url)
    }

    public var canFavoriteSelection: Bool {
        browser.selectedEntry != nil
    }

    public var needsRelaunchToApplyAuthorization: Bool {
        guard let retried = retriedAuthorizationFor else {
            return false
        }
        return browser.isDenied && browser.directory == retried
    }

    public var ancestors: [BreadcrumbSegment] {
        browser.breadcrumb.ancestors
    }

    public var showsAncestors: Bool {
        isShowingAncestors && !ancestors.isEmpty
    }

    public var ancestorIndex: Int {
        guard !ancestors.isEmpty else {
            return 0
        }
        return min(max(ancestorSelection, 0), ancestors.count - 1)
    }

    public var isPicking: Bool {
        picker.isActive
    }

    public var listSelectionIsActive: Bool {
        !isPicking && !favoritesSelectionIsActive
    }

    public var favoritesSelectionIsActive: Bool {
        !isPicking && zone == .favorites && favorites.selected != nil
    }

    public var focusedFavorite: Favorite? {
        guard favoritesSelectionIsActive else {
            return nil
        }
        return favorites.selected
    }

    public var actionTarget: URL {
        if picker.isActive {
            return picker.currentTarget
        }
        if let favorite = focusedFavorite {
            return favorite.url
        }
        return browser.actionTarget
    }

    public var actionTargetIsDirectory: Bool {
        if picker.isActive {
            return picker.currentTargetIsDirectory
        }
        if let favorite = focusedFavorite {
            return favorite.kind == .directory
        }
        return browser.actionTargetIsDirectory
    }

    public init(
        browser: BrowserModel,
        picker: PathPickerModel,
        storage: any FavoriteStoring,
        existenceProbe: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(
            atPath: $0.path
        ) }
    ) {
        self.browser = browser
        self.picker = picker
        self.storage = storage
        self.existenceProbe = existenceProbe
        favorites = storage.load()
    }

    public func isMissing(_ favorite: Favorite) -> Bool {
        missingFavoritePaths.contains(favorite.url.standardizedFileURL.path)
    }

    public func refreshFavoriteAvailability() {
        availabilityTask?.cancel()
        let probe = existenceProbe
        let urls = favorites.items.map(\.url)
        guard !urls.isEmpty else {
            missingFavoritePaths = []
            return
        }
        availabilityTask = Task { [weak self] in
            let missing = await Task.detached(priority: .utility) {
                Set(urls.filter { !probe($0) }.map(\.standardizedFileURL.path))
            }.value
            guard !Task.isCancelled else {
                return
            }
            self?.applyMissing(missing)
        }
    }

    public func activatePicker() {
        showsHelp = false
        isShowingAncestors = false
        picker.activate(from: browser.directory, seeding: browser.currentListing)
    }

    public func exitPicker() {
        picker.deactivate()
    }

    public func openAncestors() {
        guard !ancestors.isEmpty else {
            return
        }
        showsHelp = false
        picker.deactivate()
        isShowingAncestors = true
        ancestorSelection = ancestors.count - 1
    }

    public func closeAncestors() {
        isShowingAncestors = false
    }

    public func moveAncestorSelection(by offset: Int) {
        guard showsAncestors, !ancestors.isEmpty else {
            return
        }
        ancestorSelection = min(max(ancestorIndex + offset, 0), ancestors.count - 1)
    }

    public func selectAncestor(_ index: Int) {
        guard ancestors.indices.contains(index) else {
            return
        }
        ancestorSelection = index
    }

    public func confirmAncestor() {
        guard showsAncestors, ancestors.indices.contains(ancestorIndex) else {
            return
        }
        let target = ancestors[ancestorIndex]
        isShowingAncestors = false
        zone = .list
        browser.navigate(to: target.url)
    }

    public func markPresented() {
        picker.deactivate()
        showsHelp = false
        isShowingAncestors = false
        presentationCount += 1
        refreshFavoriteAvailability()
    }

    public func restoreEntryPoint() {
        guard !returnToAuthorizedDirectory() else {
            return
        }
        guard hasChosenEntryPoint else {
            hasChosenEntryPoint = true
            browser.navigate(to: PanelEntry.startingDirectory(
                favorites: favorites,
                home: browser.home
            ))
            return
        }
        browser.reload()
    }

    public func markAuthorizationRequested() {
        awaitingAuthorizationFor = browser.directory
        retriedAuthorizationFor = nil
    }

    public func refreshAfterReturningToApp() {
        guard !returnToAuthorizedDirectory() else {
            return
        }
        browser.reload()
    }

    public func selectFavorite(_ id: Favorite.ID) {
        guard let favorite = favorites.items.first(where: { $0.id == id }) else {
            return
        }
        favorites.select(id)
        zone = .favorites
        commitFavorites()
        if favorite.kind == .directory {
            browser.navigate(to: favorite.url)
        } else {
            browser.navigate(to: favorite.url.deletingLastPathComponent(), selecting: favorite.url)
        }
    }

    public func activateFavorite(at index: Int) {
        guard favorites.items.indices.contains(index) else {
            return
        }
        selectFavorite(favorites.items[index].id)
    }

    @discardableResult
    public func toggleFavoriteForSelection() -> Bool {
        guard let entry = browser.selectedEntry else {
            return false
        }
        guard !favorites.contains(url: entry.url) else {
            removeFavoriteByURL(entry.url)
            return true
        }
        favorites.add(Favorite(url: entry.url, kind: entry.isDirectory ? .directory : .file))
        commitFavorites()
        return true
    }

    @discardableResult
    public func toggleFavoriteForCurrentZone() -> Bool {
        if zone == .favorites, let selected = favorites.selected {
            removeFavorite(selected.id)
            return true
        }
        zone = .list
        return toggleFavoriteForSelection()
    }

    public func addFavorite(_ entry: DirectoryEntry) {
        favorites.add(Favorite(url: entry.url, kind: entry.isDirectory ? .directory : .file))
        commitFavorites()
    }

    public func removeFavoriteByURL(_ url: URL) {
        guard let index = favorites.index(of: url) else {
            return
        }
        removeFavorite(favorites.items[index].id)
    }

    public func removeFavorite(_ id: Favorite.ID) {
        let index = favorites.items.firstIndex { $0.id == id }
        let hadFocus = zone == .favorites && favorites.selectedID == id
        favorites.remove(id: id)
        commitFavorites()
        guard hadFocus, let index else {
            return
        }
        restoreFavoritesFocus(removedAt: index)
    }

    public func moveFavorite(from source: Int, to destination: Int) {
        favorites.move(from: source, to: destination)
        commitFavorites()
    }

    public func switchZone() {
        guard !favorites.isEmpty else {
            zone = .list
            return
        }
        zone = zone == .list ? .favorites : .list
        if zone == .favorites, favorites.selected == nil, let first = favorites.items.first {
            favorites.select(first.id)
            commitFavorites()
        }
    }

    public func focusList() {
        zone = .list
    }

    public func moveFavoriteSelection(by offset: Int) {
        guard
            let current = favorites.selectedID,
            let index = favorites.items.firstIndex(where: { $0.id == current })
        else {
            if let first = favorites.items.first {
                selectFavorite(first.id)
            }
            return
        }
        let target = min(max(index + offset, 0), favorites.items.count - 1)
        guard target != index else {
            return
        }
        selectFavorite(favorites.items[target].id)
    }

    public func setHelpVisible(_ visible: Bool) {
        showsHelp = visible
        if visible {
            isShowingAncestors = false
        }
    }

    private func restoreFavoritesFocus(removedAt index: Int) {
        guard !favorites.isEmpty else {
            zone = .list
            browser.navigate(to: browser.home)
            return
        }
        let neighbour = min(max(index - 1, 0), favorites.items.count - 1)
        selectFavorite(favorites.items[neighbour].id)
    }

    private func applyMissing(_ missing: Set<String>) {
        missingFavoritePaths = missing
    }

    @discardableResult
    private func returnToAuthorizedDirectory() -> Bool {
        guard let pending = awaitingAuthorizationFor else {
            return false
        }
        awaitingAuthorizationFor = nil
        retriedAuthorizationFor = pending
        browser.navigate(to: pending)
        return true
    }

    private func commitFavorites() {
        if zone == .favorites, favorites.selected == nil {
            zone = .list
        }
        try? storage.save(favorites)
    }
}
