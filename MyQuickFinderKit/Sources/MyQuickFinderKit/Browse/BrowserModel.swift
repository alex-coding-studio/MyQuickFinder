import Foundation
import Observation

@MainActor
@Observable
public final class BrowserModel {
    public static let skeletonDelay = Duration.milliseconds(200)

    public let home: URL

    public private(set) var directory: URL
    public private(set) var breadcrumb: Breadcrumb
    public private(set) var state = DirectoryState.loading(read: 0, total: nil)
    public private(set) var arranged = ArrangedDirectory(
        entries: [],
        hiddenCount: 0,
        showsTimeColumn: false
    )
    public private(set) var selectionIndex = 0
    public private(set) var keyboardEngaged = false
    public private(set) var showsSkeleton = false
    public private(set) var showsHidden = false

    private let loader: DirectoryLoader
    private var skeletonTask: Task<Void, Never>?
    private var loadedEntries = [DirectoryEntry]()
    private var pendingSelectionIndex: Int?
    private var pendingSelectionPath: String?

    public var entries: [DirectoryEntry] {
        arranged.entries
    }

    public var selectedEntry: DirectoryEntry? {
        entries.indices.contains(selectionIndex) ? entries[selectionIndex] : nil
    }

    public var actionTarget: URL {
        selectedEntry?.url ?? directory
    }

    public var actionTargetIsDirectory: Bool {
        selectedEntry?.isDirectory ?? true
    }

    public var currentListing: [DirectoryEntry]? {
        switch state {
        case .populated, .empty:
            loadedEntries
        default:
            nil
        }
    }

    public var isDenied: Bool {
        state == .denied
    }

    public var deniedBySystemProtection: Bool {
        ProtectedDirectory.isProtected(directory, home: home)
    }

    var pendingLoad: Task<Void, Never>? {
        loader.pending
    }

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        reader: any DirectoryReading = DirectoryReader(),
        readabilityProbe: @escaping @Sendable (URL) -> Bool = ProtectedDirectory.isReadable
    ) {
        self.home = home
        loader = DirectoryLoader(reader: reader, home: home, probe: readabilityProbe)
        directory = home
        breadcrumb = Breadcrumb.make(for: home, home: home)
    }

    public func start() {
        guard loader.pending == nil else {
            return
        }
        navigate(to: directory)
    }

    public func navigate(to url: URL, selecting wanted: URL? = nil) {
        let target = url.standardizedFileURL
        guard target != directory else {
            refresh(selecting: wanted)
            return
        }
        directory = target
        breadcrumb = Breadcrumb.make(for: target, home: home)
        selectionIndex = 0
        pendingSelectionIndex = nil
        pendingSelectionPath = wanted?.standardizedFileURL.path
        loadedEntries = []
        arranged = ArrangedDirectory(entries: [], hiddenCount: 0, showsTimeColumn: false)
        state = .loading(read: 0, total: nil)
        showsSkeleton = false
        beginLoad(target)
    }

    public func reload() {
        refresh(selecting: nil)
    }

    public func moveSelection(by offset: Int) {
        keyboardEngaged = true
        guard !entries.isEmpty else {
            return
        }
        selectionIndex = min(max(selectionIndex + offset, 0), entries.count - 1)
    }

    public func selectRow(_ index: Int) {
        guard entries.indices.contains(index) else {
            return
        }
        selectionIndex = index
    }

    public func enterSelection() {
        keyboardEngaged = true
        guard let entry = selectedEntry, entry.isDirectory else {
            return
        }
        navigate(to: entry.url)
    }

    public func goUp() {
        keyboardEngaged = true
        guard let parent = Breadcrumb.parentDirectory(of: directory) else {
            return
        }
        navigate(to: parent)
    }

    public func toggleHidden() {
        keyboardEngaged = true
        showsHidden.toggle()
        rearrange()
    }

    public func engageKeyboard() {
        keyboardEngaged = true
    }

    private func refresh(selecting wanted: URL?) {
        if let wanted {
            pendingSelectionPath = wanted.standardizedFileURL.path
            pendingSelectionIndex = nil
        } else {
            pendingSelectionIndex = selectionIndex
        }
        beginLoad(directory)
    }

    private func beginLoad(_ url: URL) {
        skeletonTask?.cancel()
        skeletonTask = Task { [weak self] in
            try? await Task.sleep(for: Self.skeletonDelay)
            guard !Task.isCancelled else {
                return
            }
            self?.markSkeletonVisible(for: url)
        }
        let progress: @Sendable (Int, Int) -> Void = { [weak self] read, total in
            Task { @MainActor in
                self?.reportProgress(read: read, total: total, for: url)
            }
        }
        loader.load([url], onProgress: progress) { [weak self] _, outcome in
            self?.finishLoad(outcome)
        }
    }

    private func finishLoad(_ outcome: DirectoryLoader.Outcome) {
        skeletonTask?.cancel()
        skeletonTask = nil
        switch outcome {
        case let .success(entries):
            loadedEntries = entries
            rearrange()
        case let .failure(error):
            loadedEntries = []
            arranged = ArrangedDirectory(entries: [], hiddenCount: 0, showsTimeColumn: false)
            state = DirectoryListing.state(for: error)
            showsSkeleton = false
        }
    }

    private func rearrange() {
        arranged = DirectoryListing.arrange(loadedEntries, showingHidden: showsHidden)
        state = DirectoryListing.state(for: arranged)
        showsSkeleton = false
        if let pendingSelectionPath {
            self.pendingSelectionPath = nil
            if let found = arranged.entries.firstIndex(where: {
                $0.url.standardizedFileURL.path == pendingSelectionPath
            }) {
                selectionIndex = found
            }
        }
        if let pendingSelectionIndex {
            selectionIndex = pendingSelectionIndex
            self.pendingSelectionIndex = nil
        }
        selectionIndex = min(selectionIndex, max(arranged.entries.count - 1, 0))
    }

    private func markSkeletonVisible(for url: URL) {
        guard directory == url, case .loading = state else {
            return
        }
        showsSkeleton = true
    }

    private func reportProgress(read: Int, total: Int, for url: URL) {
        guard directory == url, case .loading = state else {
            return
        }
        state = .loading(read: read, total: total)
    }
}
