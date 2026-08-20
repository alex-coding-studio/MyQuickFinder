import Foundation
import Observation

public enum PathPickerState: Equatable, Sendable {
    case listing([DirectoryEntry])
    case loading
    case empty
    case denied
    case missing
    case failed(String)
}

@MainActor
@Observable
public final class PathPickerModel {
    public private(set) var isActive = false
    public private(set) var text = ""
    public private(set) var state = PathPickerState.empty
    public private(set) var selectionIndex = 0
    public private(set) var resolvedDirectory: URL
    public private(set) var activationCount = 0
    public private(set) var isPristine = false
    public private(set) var hasActionableTarget = true
    public private(set) var hasChosenRow = false

    private let home: URL
    private let loader: DirectoryLoader
    private var base: URL
    private var cachedDirectoryPath: String?
    private var cachedEntries = [DirectoryEntry]()
    private var currentFragment = ""

    public var entries: [DirectoryEntry] {
        guard case let .listing(entries) = state else {
            return []
        }
        return entries
    }

    public var selectedEntry: DirectoryEntry? {
        entries.indices.contains(selectionIndex) ? entries[selectionIndex] : nil
    }

    public var inlineSuggestion: String? {
        guard text.isEmpty == false, text.hasSuffix(PathCompletion.separator) == false else {
            return nil
        }
        guard let completed = completionText(), completed.lowercased().hasPrefix(
            text.lowercased()
        ) else {
            return nil
        }
        return completed.hasSuffix(PathCompletion.separator) ? String(
            completed.dropLast()
        ) : completed
    }

    public var isRowChosen: Bool {
        hasChosenRow || !currentFragment.isEmpty
    }

    public var highlightedIndex: Int? {
        guard isRowChosen, entries.indices.contains(selectionIndex) else {
            return nil
        }
        return selectionIndex
    }

    public var currentTarget: URL {
        guard isRowChosen else {
            return resolvedDirectory
        }
        return selectedEntryInResolvedDirectory?.url ?? resolvedDirectory
    }

    public var currentTargetIsDirectory: Bool {
        guard isRowChosen else {
            return true
        }
        return selectedEntryInResolvedDirectory?.isDirectory ?? true
    }

    var pendingLoad: Task<Void, Never>? {
        loader.pending
    }

    private var selectedEntryInResolvedDirectory: DirectoryEntry? {
        guard let entry = selectedEntry else {
            return nil
        }
        let parent = entry.url.deletingLastPathComponent().standardizedFileURL.path
        return parent == resolvedDirectory.standardizedFileURL.path ? entry : nil
    }

    public init(
        home: URL,
        reader: any DirectoryReading,
        readabilityProbe: @escaping @Sendable (URL) -> Bool = ProtectedDirectory.isReadable
    ) {
        self.home = home
        loader = DirectoryLoader(reader: reader, home: home, probe: readabilityProbe)
        base = home
        resolvedDirectory = home
    }

    public func activate(from directory: URL, seeding listing: [DirectoryEntry]? = nil) {
        base = directory
        isActive = true
        activationCount += 1
        text = PathCompletion.defaultPrefix(for: directory, home: home)
        isPristine = true
        hasActionableTarget = true
        hasChosenRow = false
        selectionIndex = 0
        cachedDirectoryPath = listing == nil ? nil : directory.standardizedFileURL.path
        cachedEntries = listing ?? []
        reload()
    }

    public func deactivate() {
        loader.cancel()
        isActive = false
        isPristine = false
        hasActionableTarget = true
        hasChosenRow = false
        currentFragment = ""
        text = ""
        state = .empty
        selectionIndex = 0
        cachedDirectoryPath = nil
        cachedEntries = []
    }

    public func updateText(_ raw: String) {
        guard raw != text else {
            return
        }
        text = raw
        isPristine = false
        hasChosenRow = false
        selectionIndex = 0
        reload()
    }

    public func markInteracted() {
        isPristine = false
    }

    public func moveSelection(by offset: Int) {
        let count = entries.count
        guard count > 0 else {
            return
        }
        guard isRowChosen else {
            hasChosenRow = true
            selectionIndex = offset < 0 ? count - 1 : 0
            return
        }
        selectionIndex = min(max(selectionIndex + offset, 0), count - 1)
    }

    public func selectRow(_ index: Int) {
        guard entries.indices.contains(index) else {
            return
        }
        hasChosenRow = true
        selectionIndex = index
    }

    public func completionText() -> String? {
        if let shared = PathCompletion.completeToCommonPrefix(
            text,
            entries: entries,
            home: home,
            base: base
        ) {
            return shared
        }
        guard let entry = selectedEntry else {
            return nil
        }
        return PathCompletion.complete(text, with: entry, home: home, base: base)
    }

    private func reload() {
        loader.cancel()
        let input = PathCompletion.parse(text, home: home, base: base)
        let whole = PathCompletion.wholePath(text, home: home, base: base)
        resolvedDirectory = whole ?? input.directory

        if let whole, whole.standardizedFileURL.path == cachedDirectoryPath {
            present(cachedEntries, fragment: "")
            return
        }
        if input.directory.standardizedFileURL.path == cachedDirectoryPath, !descendable(whole) {
            resolvedDirectory = input.directory
            present(cachedEntries, fragment: input.fragment)
            return
        }
        if entries.isEmpty {
            state = .loading
        }

        let fragment = input.fragment
        let candidates = whole.map { [$0, input.directory] } ?? [input.directory]
        loader.load(candidates) { [weak self] settled, outcome in
            guard let self else {
                return
            }
            switch outcome {
            case let .success(listed):
                accept(listed, directory: settled, fragment: settled == whole ? "" : fragment)
            case let .failure(error):
                reportFailure(error, for: settled)
            }
        }
    }

    private func descendable(_ whole: URL?) -> Bool {
        guard let whole else {
            return false
        }
        let target = whole.standardizedFileURL.path
        return cachedEntries.contains { $0.isDirectory && $0.url.standardizedFileURL.path == target }
    }

    private func accept(_ listed: [DirectoryEntry], directory: URL, fragment: String) {
        cachedDirectoryPath = directory.standardizedFileURL.path
        cachedEntries = listed
        resolvedDirectory = directory
        present(listed, fragment: fragment)
    }

    private func present(_ listed: [DirectoryEntry], fragment: String) {
        let arranged = DirectoryListing.arrange(listed, showingHidden: fragment.hasPrefix("."))
        let matched = PathCompletion.filter(arranged.entries, fragment: fragment)
        state = matched.isEmpty ? .empty : .listing(matched)
        hasActionableTarget = !matched.isEmpty || fragment.isEmpty
        currentFragment = fragment
        selectionIndex = 0
    }

    private func reportFailure(_ error: any Error, for directory: URL) {
        cachedDirectoryPath = nil
        cachedEntries = []
        resolvedDirectory = directory
        if DirectoryListing.state(for: error) == .denied {
            state = .denied
            hasActionableTarget = true
        } else {
            let failure = error as NSError
            state = failure.code == NSFileReadNoSuchFileError
                ? .missing
                : .failed(failure.localizedDescription)
            hasActionableTarget = false
        }
        selectionIndex = 0
    }
}
